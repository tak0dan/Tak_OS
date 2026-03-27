#!/usr/bin/env bash

# Translate a package attribute path to the safe filename used for its .nix module.
module_filename_for_pkg() {
  local pkg="$1"
  printf '%s' "$pkg" | tr '/' '-' | tr ' ' '_' | tr ':' '_'
}

# Delete .nix module files for all packages currently in TX_REMOVE.
# Returns 0 if at least one file was removed, 1 if nothing was deleted.
remove_staged_modules() {
  local removed_count=0 pkg file_name
  for pkg in "${!TX_REMOVE[@]}"; do
    file_name="$(module_filename_for_pkg "$pkg")"
    if [[ -f "$MODULES_DIR/$file_name.nix" ]] \
       && grep -qF "$NIXORCIST_MARKER" "$MODULES_DIR/$file_name.nix" 2>/dev/null; then
      rm -f "$MODULES_DIR/$file_name.nix"
      show_item "-" "Removed module: $file_name.nix"
      (( removed_count++ )) || true
    fi
  done
  [[ $removed_count -gt 0 ]] && return 0
  return 1
}


# Returns 0 on success (file created or already exists), 1 if pkg is not a derivation.
generate_module_for_pkg() {
  local pkg="$1"

  if ! is_derivation_cached "$pkg"; then
    show_item "✗" "Skipped (not a derivation): $pkg"
    return 1
  fi

  local safe_name target
  safe_name="$(module_filename_for_pkg "$pkg")"
  target="$MODULES_DIR/$safe_name.nix"

  if [[ -f "$target" ]]; then
    show_item "○" "Exists: $safe_name.nix"
    return 0
  fi

  cat > "$target" <<EOF
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    $pkg
  ];
}

$NIXORCIST_MARKER
# NIXORCIST-ATTRPATH: $pkg
EOF

  show_item "✓" "Generated: $safe_name.nix"
  return 0
}

# Remove .nix module files for packages that are no longer in the lock.
# This is the safety net: if a package was deprecated/renamed, its stale
# module is deleted so nix-build never sees it.
cleanup_orphan_modules() {
  local -A lock_set=()
  local pkg file attr_in_file fname

  # Build a set of packages currently in the lock
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    lock_set["$(module_filename_for_pkg "$pkg")"]=1
  done < <(read_lock_entries)

  local removed=0
  shopt -s nullglob
  for file in "$MODULES_DIR"/*.nix; do
    [[ -e "$file" ]] || continue
    grep -qF "$NIXORCIST_MARKER" "$file" 2>/dev/null || continue  # only touch managed files

    fname="$(basename "$file" .nix)"
    if [[ ! -v lock_set[$fname] ]]; then
      rm -f "$file"
      show_item "↺" "Cleaned orphan: $(basename "$file")"
      (( removed++ )) || true
    fi
  done
  shopt -u nullglob

  [[ $removed -gt 0 ]] && show_info "Cleaned $removed orphan module(s)."
  return 0
}

purge_all_modules() {
  if [[ ! -d "$MODULES_DIR" ]] || [[ ! -f "$LOCK_FILE" ]]; then
    show_info "Nothing to purge."
    return 0
  fi

  local file count=0
  for file in "$MODULES_DIR"/*.nix; do
    [[ -e "$file" ]] || continue
    if grep -qF "$NIXORCIST_MARKER" "$file" 2>/dev/null; then
      rm -f "$file"
      show_item "✓" "Removed: $(basename "$file")"
      ((count++))
    fi
  done

  > "$LOCK_FILE"
  show_divider
  printf '  Purged %d modules and cleared lock file.
' "$count"
}

generate_modules() {
  local -a packages total_generated=0 total_skipped=0
  mapfile -t packages < <(read_lock_entries)

  [[ ${#packages[@]} -eq 0 ]] && { show_info "Lock file is empty."; return 0; }

  show_info "Processing ${#packages[@]} lock entries"

  for pkg in "${packages[@]}"; do
    if ! is_derivation_cached "$pkg"; then
      show_item "✗" "Skipped non-package: $pkg"
      ((total_skipped++))
      continue
    fi

    local safe_name target
    safe_name=$(echo "$pkg" | tr '/' '-' | tr ' ' '_' | tr ':' '_')
    target="$MODULES_DIR/$safe_name.nix"

    if [[ -f "$target" ]]; then
      show_item "○" "Exists: $safe_name.nix"
      continue
    fi

    cat > "$target" <<EOF
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    $pkg
  ];
}

$NIXORCIST_MARKER
# NIXORCIST-ATTRPATH: $pkg
EOF

    show_item "✓" "Generated: $safe_name.nix"
    ((total_generated++))
  done

  show_divider
  printf '  Summary: %d generated | %d skipped\n' "$total_generated" "$total_skipped"
}
