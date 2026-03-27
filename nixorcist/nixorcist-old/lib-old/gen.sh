#!/usr/bin/env bash

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
    if ! is_derivation "$pkg"; then
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
