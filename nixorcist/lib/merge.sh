#!/usr/bin/env bash

NIXORCIST_MERGE_MARKER='#$nixorcist-merge$#'

merge_packages() {
  local merge_name="${1:-}"

  if [[ -z "$merge_name" ]]; then
    show_error "merge requires a name argument"
    echo "  Usage: nixorcist merge <name>"
    return 1
  fi

  # Validate name: allow alphanumeric, dash, underscore only
  if [[ ! "$merge_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    show_error "Invalid name: '$merge_name'. Use letters, digits, dashes, underscores only."
    return 1
  fi

  local -a packages
  mapfile -t packages < <(read_lock_entries)

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_info "Lock file is empty — nothing to merge."
    return 0
  fi

  local target="$MODULES_DIR/$merge_name.nix"

  if [[ -f "$target" ]]; then
    show_warning "File already exists: $merge_name.nix"
    local answer
    read -r -p "  Overwrite? [y/N]: " answer
    [[ "${answer,,}" == "y" ]] || { show_item "⊘" "Merge cancelled."; return 0; }
  fi

  show_info "Merging ${#packages[@]} lock entries into '$merge_name.nix'..."

  local -a valid_pkgs=()
  local pkg
  for pkg in "${packages[@]}"; do
    if ! is_derivation "$pkg"; then
      show_item "✗" "Skipped non-package: $pkg"
      continue
    fi
    valid_pkgs+=("$pkg")
  done

  if [[ ${#valid_pkgs[@]} -eq 0 ]]; then
    show_error "No valid packages found to merge."
    return 1
  fi

  {
    echo "{ config, pkgs, ... }:"
    echo ""
    echo "{"
    echo "  environment.systemPackages = with pkgs; ["
    for pkg in "${valid_pkgs[@]}"; do
      echo "    $pkg"
    done
    echo "  ];"
    echo "}"
    echo ""
    echo "$NIXORCIST_MARKER"
    echo "$NIXORCIST_MERGE_MARKER"
    echo "# NIXORCIST-MERGE-NAME: $merge_name"
    echo "# NIXORCIST-MERGE-DATE: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# NIXORCIST-MERGE-COUNT: ${#valid_pkgs[@]}"
  } > "$target"

  show_divider
  show_success "Merged ${#valid_pkgs[@]} packages → $merge_name.nix"
  show_item "→" "Run 'nixorcist hub' to include it in all-packages.nix"
  show_item "→" "Run 'nixorcist rebuild' to apply to your system"
}
