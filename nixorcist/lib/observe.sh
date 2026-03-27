#!/usr/bin/env bash
# lib/observe.sh — Observability layer for nixorcist
# ====================================================
# Provides state visibility across the two ownership layers:
#
#   CLI layer    — packages declared in nixorcist's lock file (generated state)
#   Config layer — packages declared in /etc/nixos .nix files (declarative state)
#                  excluding nixorcist/generated/ (that is the CLI layer itself)
#
# Commands exposed:
#   nixorcist status         — side-by-side snapshot of both layers + overlaps
#   nixorcist trace <pkg>    — all locations where a package is declared
#   nixorcist diff           — what is only CLI, only config, or in both

# ---------------------------------------------------------------------------
# Config layer scanner
# ---------------------------------------------------------------------------
# Scans all /etc/nixos/**/*.nix files (excluding nixorcist/generated/ and
# nixorcist/nixorcist-old/) for environment.systemPackages declarations.
# Returns lines of the form:  <pkg>|<absolute-file-path>
#
# The parser is intentionally simple (awk-based) and handles the common
# patterns:
#   environment.systemPackages = with pkgs; [ pkg1 pkg2 ];
#   environment.systemPackages = with pkgs; [
#     pkg1
#     pkg2
#   ];
#   environment.systemPackages = [ pkgs.pkg1 pkgs.pkg2 ];
#
# It does NOT handle complex Nix expressions (lib.optionals, ++, let-in, etc.)
# but catches the vast majority of real-world declarations without false positives.

_observe_scan_file() {
  local file="$1"
  awk -v file="$file" '
    # Track whether we are inside a systemPackages list
    /environment\.systemPackages[[:space:]]*=/ { in_block = 1 }

    in_block && /\[/ { depth++ }
    in_block && /\]/ {
      depth--
      if (depth <= 0) { in_block = 0; depth = 0 }
    }

    in_block && depth > 0 {
      line = $0
      # Strip inline comments
      sub(/[[:space:]]*#.*$/, "", line)
      # Remove "pkgs." prefix
      gsub(/pkgs\./, "", line)
      # Strip "with pkgs;", brackets, semicolons, parens
      gsub(/with[[:space:]]+pkgs[[:space:]]*;/, "", line)
      gsub(/[\[\];(){},]/, " ", line)
      # Each whitespace-delimited token that looks like a valid package name
      n = split(line, tokens, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        t = tokens[i]
        # Skip empty, pure operators, or tokens that look like Nix expressions
        if (t == "" || t ~ /^(lib|config|pkgs|import|let|in|if|then|else|rec|with|inherit)$/) continue
        if (t ~ /[^a-zA-Z0-9._+\-]/) continue
        if (length(t) < 2) continue
        printf "%s|%s\n", t, file
      }
    }
  ' "$file"
}

# Scan all config-layer .nix files and emit <pkg>|<file> lines.
scan_config_packages() {
  local nixos_root="/etc/nixos"
  local exclude_generated
  exclude_generated="$(realpath "$ROOT/generated" 2>/dev/null || echo "$ROOT/generated")"
  local exclude_old
  exclude_old="$(realpath "$ROOT/nixorcist-old" 2>/dev/null || echo "$ROOT/nixorcist-old")"

  while IFS= read -r f; do
    # Skip anything inside nixorcist's own generated or archive directories
    local real_f
    real_f="$(realpath "$f" 2>/dev/null || echo "$f")"
    [[ "$real_f" == "$exclude_generated"/* ]] && continue
    [[ "$real_f" == "$exclude_old"/*        ]] && continue

    _observe_scan_file "$f"
  done < <(find "$nixos_root" -name '*.nix' -type f 2>/dev/null | sort)
}

# Return a deduplicated sorted list of package names from the config layer.
config_layer_packages() {
  scan_config_packages | cut -d'|' -f1 | sort -u
}

# Return a sorted list of package names from the CLI (lock) layer.
cli_layer_packages() {
  read_lock_entries
}

# ---------------------------------------------------------------------------
# nixorcist status
# ---------------------------------------------------------------------------
show_status() {
  local -a cli_pkgs config_pkgs overlap_pkgs cli_only config_only
  mapfile -t cli_pkgs    < <(cli_layer_packages)
  mapfile -t config_pkgs < <(config_layer_packages)

  # Build lookup sets
  declare -A cli_set config_set
  for p in "${cli_pkgs[@]}";    do cli_set["$p"]=1;    done
  for p in "${config_pkgs[@]}"; do config_set["$p"]=1; done

  for p in "${cli_pkgs[@]}";    do [[ -v config_set[$p] ]] && overlap_pkgs+=("$p") || cli_only+=("$p"); done
  for p in "${config_pkgs[@]}"; do [[ -v cli_set[$p]    ]] || config_only+=("$p"); done

  show_section_header "System Package Status"

  # ── CLI layer ──────────────────────────────────────────────────────────
  printf '  ┌─ CLI Layer (nixorcist / generated) ─ %d package(s)\n' "${#cli_pkgs[@]}"
  if [[ ${#cli_pkgs[@]} -eq 0 ]]; then
    printf '  │  (empty)\n'
  else
    for p in "${cli_pkgs[@]}"; do
      if [[ -v config_set[$p] ]]; then
        printf '  │  %-40s  %b\n' "$p" "$(_ui_colorize yellow '⚑ also in config')"
      else
        printf '  │  %s\n' "$p"
      fi
    done
  fi
  printf '  └──────────────────────────────────────\n\n'

  # ── Config layer ───────────────────────────────────────────────────────
  printf '  ┌─ Config Layer (/etc/nixos) ─ %d unique package(s)\n' "${#config_only[@]}"
  if [[ ${#config_only[@]} -eq 0 ]]; then
    printf '  │  (none that are not also in CLI layer)\n'
  else
    for p in "${config_only[@]}"; do
      printf '  │  %s\n' "$p"
    done
  fi
  printf '  └──────────────────────────────────────\n\n'

  # ── Overlaps ───────────────────────────────────────────────────────────
  if [[ ${#overlap_pkgs[@]} -gt 0 ]]; then
    printf '  ┌─ %b ─ %d package(s) declared in BOTH layers\n' \
      "$(_ui_colorize yellow '⚑ Overlaps')" "${#overlap_pkgs[@]}"
    for p in "${overlap_pkgs[@]}"; do
      printf '  │  %s\n' "$p"
    done
    printf '  │\n'
    printf '  │  Nix merges duplicates safely. To clean up:\n'
    printf '  │    nixorcist delete <pkg>  — remove from CLI layer\n'
    printf '  │    or remove from your config manually\n'
    printf '  └──────────────────────────────────────\n\n'
  else
    printf '  %b No overlaps — layers are clean.\n\n' "$(_ui_colorize green '✓')"
  fi

  printf '  Total unique packages: %d\n' \
    "$(( ${#cli_only[@]} + ${#config_only[@]} + ${#overlap_pkgs[@]} ))"
  echo
}

# ---------------------------------------------------------------------------
# nixorcist trace <pkg>
# ---------------------------------------------------------------------------
trace_package() {
  local pkg="$1"
  local found=0

  show_section_header "Trace: $pkg"

  # ── CLI layer ──────────────────────────────────────────────────────────
  printf '  CLI Layer (lock + generated modules):\n'
  if read_lock_entries | grep -qxF "$pkg" 2>/dev/null; then
    printf '    %b  Found in lock file: %s\n' "$(_ui_colorize green '✓')" "$LOCK_FILE"
    found=1
  else
    printf '    %b  Not in lock file\n' "$(_ui_colorize dim '○')"
  fi

  # Check individual module file
  local mod_file="$MODULES_DIR/$(printf '%s' "$pkg" | tr '/' '-' | tr ' ' '_' | tr ':' '_').nix"
  if [[ -f "$mod_file" ]]; then
    printf '    %b  Generated module: %s\n' "$(_ui_colorize green '✓')" "$mod_file"
    found=1
  fi
  echo

  # ── Config layer ───────────────────────────────────────────────────────
  printf '  Config Layer (/etc/nixos):\n'
  local config_hits
  config_hits="$(scan_config_packages | awk -F'|' -v p="$pkg" '$1 == p { print $2 }' | sort -u)"

  if [[ -n "$config_hits" ]]; then
    while IFS= read -r f; do
      printf '    %b  %s\n' "$(_ui_colorize green '✓')" "$f"
      found=1
    done <<< "$config_hits"
  else
    printf '    %b  Not found in any config file\n' "$(_ui_colorize dim '○')"
  fi
  echo

  if [[ $found -eq 0 ]]; then
    printf '  %b  %q is not declared anywhere in this system.\n\n' \
      "$(_ui_colorize yellow '⚠')" "$pkg"
  fi
}

# ---------------------------------------------------------------------------
# nixorcist diff
# ---------------------------------------------------------------------------
diff_layers() {
  local -a cli_pkgs config_pkgs
  mapfile -t cli_pkgs    < <(cli_layer_packages)
  mapfile -t config_pkgs < <(config_layer_packages)

  declare -A cli_set config_set
  for p in "${cli_pkgs[@]}";    do cli_set["$p"]=1;    done
  for p in "${config_pkgs[@]}"; do config_set["$p"]=1; done

  local -a cli_only=() config_only=() both=()
  for p in "${cli_pkgs[@]}";    do [[ -v config_set[$p] ]] && both+=("$p")        || cli_only+=("$p"); done
  for p in "${config_pkgs[@]}"; do [[ -v cli_set[$p]    ]] || config_only+=("$p"); done

  show_section_header "Layer Diff"

  # ── CLI-only ───────────────────────────────────────────────────────────
  printf '  %b  CLI-only — in generated layer, not yet committed to config (%d)\n' \
    "$(_ui_colorize cyan '+')" "${#cli_only[@]}"
  if [[ ${#cli_only[@]} -eq 0 ]]; then
    printf '      (none)\n'
  else
    for p in "${cli_only[@]}"; do
      printf '      %b %s\n' "$(_ui_colorize cyan '+')" "$p"
    done
  fi
  echo

  # ── Config-only ────────────────────────────────────────────────────────
  printf '  %b  Config-only — in declarative config, not in generated layer (%d)\n' \
    "$(_ui_colorize green '=')" "${#config_only[@]}"
  if [[ ${#config_only[@]} -eq 0 ]]; then
    printf '      (none)\n'
  else
    for p in "${config_only[@]}"; do
      printf '      %b %s\n' "$(_ui_colorize green '=')" "$p"
    done
  fi
  echo

  # ── Duplicates ─────────────────────────────────────────────────────────
  printf '  %b  Duplicates — declared in both layers (%d)\n' \
    "$(_ui_colorize yellow '⚑')" "${#both[@]}"
  if [[ ${#both[@]} -eq 0 ]]; then
    printf '      (none)\n'
  else
    for p in "${both[@]}"; do
      printf '      %b %s\n' "$(_ui_colorize yellow '⚑')" "$p"
    done
    echo
    printf '      Nix merges these safely but they can be cleaned up:\n'
    printf '        nixorcist delete <pkg>  — drop from CLI layer\n'
  fi
  echo

  # ── Summary ────────────────────────────────────────────────────────────
  show_divider
  printf '  CLI-only: %-4d  Config-only: %-4d  Both: %-4d\n' \
    "${#cli_only[@]}" "${#config_only[@]}" "${#both[@]}"
  echo
}
