#!/usr/bin/env bash

run_rebuild() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(realpath "$SCRIPT_DIR/../..")"

  show_header "NixOS Rebuild with Confirmed Changes"
  
  show_info "Generating modules from lock file"
  generate_modules || { show_error "Module generation failed"; return 1; }
  
  show_info "Regenerating hub configuration"
  regenerate_hub || { show_error "Hub regeneration failed"; return 1; }

  show_info "Creating staging snapshot"
  rm -rf /etc/nixos/.staging
  mkdir -p /etc/nixos/.staging
  cp -r /etc/nixos/* /etc/nixos/.staging/

  show_info "Validating build"
  nix-build '<nixpkgs/nixos>' \
    --attr config.system.build.toplevel \
    --include nixos-config=/etc/nixos/.staging/configuration.nix || {
    show_error "Build validation failed"
    cleanup_staging
    return 1
  }

  show_success "Build validation passed"
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

cleanup_staging() {
  if [[ ! -d /etc/nixos/.staging ]]; then
    return
  fi

  find /etc/nixos/.staging -type f ! -path "*/nixorcist/generated/*" ! -name "configuration.nix" -delete 2>/dev/null || true
  find /etc/nixos/.staging -type d -empty -delete 2>/dev/null || true
  show_item "✓" "Staging cleaned"
}
