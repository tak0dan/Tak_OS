#!/usr/bin/env bash

regenerate_hub() {
  local HUB module_count
  HUB="$ROOT/generated/all-packages.nix"

  mkdir -p "$ROOT/generated"

  {
    echo "{ config, pkgs, ... }:"
    echo "{"
    echo "  imports = ["

    module_count=0
    for f in "$MODULES_DIR"/*.nix; do
      [[ -e "$f" ]] || continue
      echo "    ./.modules/$(basename "$f")"
      ((module_count++))
    done

    echo "  ];"
    echo "}"
  } > "$HUB" || { show_error "Failed to write hub file"; return 1; }

  show_success "Hub regenerated ($module_count modules imported)"
}
