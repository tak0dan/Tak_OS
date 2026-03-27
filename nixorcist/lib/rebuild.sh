#!/usr/bin/env bash

run_rebuild() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(realpath "$SCRIPT_DIR/../..")"

  show_header "NixOS Rebuild with Confirmed Changes"

  show_info "Generating modules from lock file"
  cleanup_orphan_modules
  generate_modules || { show_error "Module generation failed"; return 1; }

  show_info "Regenerating hub configuration"
  regenerate_hub || { show_error "Hub regeneration failed"; return 1; }

  show_info "Creating staging snapshot"
  sudo rm -rf /etc/nixos/.staging
  mkdir -p /etc/nixos/.staging
  cp -r /etc/nixos/* /etc/nixos/.staging/

  # Validation loop — retries after interactive error resolution
  local attempt=0 max_attempts=5
  while true; do
    (( attempt++ )) || true
    if (( attempt > max_attempts )); then
      show_error "Giving up after $max_attempts resolution attempts."
      cleanup_staging
      return 1
    fi

    [[ $attempt -gt 1 ]] && show_info "Validating build (attempt $attempt of $max_attempts)"
    [[ $attempt -eq 1 ]] && show_info "Validating build"

    local _build_log
    _build_log="$(mktemp)"

    nix-build '<nixpkgs/nixos>' \
      --attr config.system.build.toplevel \
      --include nixos-config=/etc/nixos/.staging/configuration.nix \
      2>&1 | tee "$_build_log"
    local _build_exit="${PIPESTATUS[0]}"

    if [[ "$_build_exit" -eq 0 ]]; then
      rm -f "$_build_log"
      show_success "Build validation passed"
      break
    fi

    # Try interactive resolution
    if _rebuild_resolve_errors "$_build_log"; then
      rm -f "$_build_log"
      show_info "Re-generating modules after resolution..."
      generate_modules || { show_error "Module re-generation failed"; cleanup_staging; return 1; }
      regenerate_hub   || { show_error "Hub re-generation failed";    cleanup_staging; return 1; }
      # Refresh the generated subtree in staging
      rm -rf /etc/nixos/.staging/nixorcist/generated
      cp -r /etc/nixos/nixorcist/generated /etc/nixos/.staging/nixorcist/generated
      continue
    fi

    rm -f "$_build_log"
    show_error "Build validation failed and could not be resolved interactively."
    cleanup_staging
    return 1
  done

  show_info "Promoting staging to live config"
  "$ROOT_DIR/scripts/nix-rebuild-smart.sh" || {
    show_error "NixOS rebuild failed"
    cleanup_staging
    return 1
  }

  show_info "Cleaning up staging directory"
  cleanup_staging
  show_success "Rebuild complete"
}

# ─── Error resolver ───────────────────────────────────────────────────────────
# Parse nix-build error log and offer interactive resolution for each issue.
# Returns 0 if at least one issue was resolved (caller should retry),
#         1 if nothing could be resolved.

_rebuild_resolve_errors() {
  local log="$1"
  local any_resolved=0

  # Collect missing / undefined attributes from the log
  local -a missing=()
  mapfile -t missing < <(
    {
      grep -oP "attribute '\K[^']+(?=' missing)" "$log" 2>/dev/null || true
      grep -oP "undefined variable '\K[^']+(?=')"  "$log" 2>/dev/null || true
    } | sort -u
  )

  # Detect well-known removal messages that don't produce the standard pattern
  grep -q "Python 2 interpreter has been removed\|Python2 is end-of-life" \
    "$log" 2>/dev/null && missing+=("python")
  grep -q "nodejs.*has been removed\|nodejs.*end-of-life" \
    "$log" 2>/dev/null && missing+=("nodejs")

  # Deduplicate
  local -A _seen=()
  local -a attrs=()
  local m
  for m in "${missing[@]}"; do
    [[ -z "$m" || -v _seen[$m] ]] && continue
    _seen[$m]=1
    attrs+=("$m")
  done

  if [[ ${#attrs[@]} -eq 0 ]]; then
    return 1
  fi

  echo
  show_warning "Build failed — found ${#attrs[@]} unresolvable package(s). Starting interactive resolution."
  echo

  local attr
  for attr in "${attrs[@]}"; do
    # Always evict from validation cache so next gen re-evaluates
    validation_cache_evict "$attr" 2>/dev/null || true

    if _resolve_missing_attr "$attr"; then
      any_resolved=1
    fi
  done

  return $(( any_resolved == 0 ))
}

# Interactive prompt to resolve a single missing/invalid nixpkgs attribute.
_resolve_missing_attr() {
  local attr="$1"

  echo
  printf '  ┌─ Missing attribute ──────────────────────────────────┐\n'
  printf '  │  Package: %-43s│\n' "'$attr'"
  printf '  │  This package no longer exists in nixpkgs.           │\n'
  printf '  └──────────────────────────────────────────────────────┘\n'
  echo

  # Well-known renames table
  declare -A _WELL_KNOWN=(
    [python]=python3
    [python2]=python27
    [nodejs]=nodejs_22
    [ruby]=ruby_3_3
    [java]=jdk21
    [openjdk]=jdk21
    [gcc]=gcc14
    [clang]=clang_18
    [mariadb]=mariadb_1011
    [postgresql]=postgresql_16
  )

  # Build candidate list: well-known rename first, then index-based leaf search
  local INDEX_FILE; INDEX_FILE="$(get_index_file)"
  local -a candidates=()
  if [[ -v _WELL_KNOWN[$attr] ]]; then
    candidates+=("${_WELL_KNOWN[$attr]}")
  fi

  if [[ -f "$INDEX_FILE" ]]; then
    local found
    while IFS= read -r found; do
      local already=0 c
      for c in "${candidates[@]}"; do [[ "$c" == "$found" ]] && already=1; done
      (( already )) || candidates+=("$found")
    done < <(find_similar_packages "$attr")
  else
    show_warning "Nixpkgs index not found — run 'nixorcist fetch-index' for better suggestions."
  fi

  if [[ ${#candidates[@]} -eq 0 ]]; then
    show_warning "No close matches found for '$attr'."
    printf '  Enter a replacement name (or press Enter to remove):\n\n'
    read -rp "  > " manual
    if [[ -z "$manual" ]]; then
      _lock_remove_pkg "$attr"
      show_item "✓" "Removed '$attr' from lock."
      return 0
    fi
    candidates+=("$manual")
  fi

  # Display candidates with descriptions from index
  echo "  Alternatives for '$attr':"
  echo
  local i pkg desc
  for (( i=0; i<${#candidates[@]}; i++ )); do
    pkg="${candidates[$i]}"
    if [[ -f "$INDEX_FILE" ]]; then
      desc="$(awk -F'|' -v p="$pkg" '$1==p{sub(/^[^|]*\|/,""); print substr($0,1,55); exit}' "$INDEX_FILE")"
    fi
    [[ -z "${desc:-}" ]] && desc="(no description)"
    printf "    %2d) %-38s  %s\n" "$((i+1))" "$pkg" "$desc"
  done
  printf "    %2d) Remove '%s' from lock (don't install)\n" 0 "$attr"
  echo

  local choice new_attr
  while true; do
    read -rp "  Choose [0-${#candidates[@]}]: " choice

    if [[ "$choice" == "0" ]]; then
      _lock_remove_pkg "$attr"
      show_item "✓" "Removed '$attr' from lock."
      return 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#candidates[@]} )); then
      new_attr="${candidates[$((choice-1))]}"
      break
    fi

    show_error "Invalid choice — enter a number between 0 and ${#candidates[@]}."
  done

  # Check if the replacement is already in the lock
  local -a cur_entries=()
  mapfile -t cur_entries < <(read_lock_entries)
  local already=0 e
  for e in "${cur_entries[@]}"; do
    [[ "$e" == "$new_attr" ]] && { already=1; break; }
  done

  if [[ $already -eq 1 ]]; then
    show_item "ℹ" "'$new_attr' is already in the lock — removing duplicate '$attr'."
    _lock_remove_pkg "$attr"
  else
    _lock_replace_pkg "$attr" "$new_attr"
    show_item "✓" "Replaced '$attr' → '$new_attr' in lock."
  fi

  return 0
}

# Remove one package from the lock file.
_lock_remove_pkg() {
  local attr="$1"
  local -a entries filtered=()
  mapfile -t entries < <(read_lock_entries)
  local e
  for e in "${entries[@]}"; do
    [[ "$e" == "$attr" ]] && continue
    filtered+=("$e")
  done
  write_lock_entries filtered
}

# Replace one package with another in the lock file.
_lock_replace_pkg() {
  local old="$1" new="$2"
  local -a entries updated=()
  mapfile -t entries < <(read_lock_entries)
  local e
  for e in "${entries[@]}"; do
    if [[ "$e" == "$old" ]]; then
      updated+=("$new")
    else
      updated+=("$e")
    fi
  done
  write_lock_entries updated
}

# ─── Staging cleanup ──────────────────────────────────────────────────────────
cleanup_staging() {
  if [[ ! -d /etc/nixos/.staging ]]; then
    return
  fi
  find /etc/nixos/.staging -type f \
    ! -path "*/nixorcist/generated/*" \
    ! -name "configuration.nix" \
    -delete 2>/dev/null || true
  find /etc/nixos/.staging -type d -empty -delete 2>/dev/null || true
  show_item "✓" "Staging cleaned"
}
