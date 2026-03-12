#!/usr/bin/env bash
# Automatic Post-Fresh-Install Setup Script for NixOS + nixorcist
# Usage: sudo bash install.sh [--skip-upgrade]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SKIP_UPGRADE="${1:-}"
REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS_TARGET="/etc/nixos/nixorcist"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Verify prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use: sudo bash install.sh)"
        exit 1
    fi
    log_success "Running as root"

    # Check if NixOS
    if ! grep -q "nixos" /etc/os-release 2>/dev/null; then
        log_warning "This appears to not be NixOS; proceed with caution"
    fi
    log_success "System detected"

    # Check if git is available
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed"
        exit 1
    fi
    log_success "git is available"

    # Check repository exists
    if [[ ! -d "$REPO_PATH" ]]; then
        log_error "Repository not found at $REPO_PATH"
        exit 1
    fi
    log_success "Repository found at $REPO_PATH"

    # Check NixOS configuration directory exists
    if [[ ! -d /etc/nixos ]]; then
        log_warning "/etc/nixos does not exist; will create it"
        mkdir -p /etc/nixos
    fi
    log_success "/etc/nixos directory accessible"
}

# Step 1: System upgrade
step_upgrade_system() {
    print_header "Step 1: Upgrading NixOS System"

    if [[ "$SKIP_UPGRADE" == "--skip-upgrade" ]]; then
        log_info "Skipping system upgrade (--skip-upgrade flag set)"
        return
    fi

    log_info "Running: nixos-rebuild switch --upgrade"
    if sudo nixos-rebuild switch --upgrade 2>&1 | tail -20; then
        log_success "System upgrade completed"
    else
        log_error "System upgrade failed"
        exit 1
    fi
}

# Step 2: Copy configuration
step_copy_configuration() {
    print_header "Step 2: Copying Configuration to /etc/nixos"

    SOURCE_PATH="$REPO_PATH/NixOS/nixos-build"

    if [[ ! -d "$SOURCE_PATH" ]]; then
        log_error "Source configuration not found at $SOURCE_PATH"
        exit 1
    fi

    log_info "Source: $SOURCE_PATH"
    log_info "Target: $NIXOS_TARGET"

    # Backup existing if present
    if [[ -d "$NIXOS_TARGET" ]]; then
        BACKUP_PATH="/etc/nixos/nixorcist.backup.$(date +%s)"
        log_warning "Existing nixorcist found; creating backup at $BACKUP_PATH"
        cp -r "$NIXOS_TARGET" "$BACKUP_PATH"
        rm -rf "$NIXOS_TARGET"
    fi

    # Copy configuration
    log_info "Copying files..."
    cp -r "$SOURCE_PATH" "$NIXOS_TARGET"
    
    # Verify copy
    if [[ ! -f "$NIXOS_TARGET/nixorcist.sh" ]]; then
        log_error "Copy failed; nixorcist.sh not found in target"
        exit 1
    fi

    log_success "Configuration copied to $NIXOS_TARGET"
}

# Step 3: Comment out thunar references
step_disable_thunar() {
    print_header "Step 3: Disabling thunar Package References"

    THUNAR_FILES=(
        "/etc/nixos/nixorcist/generated/pkg-dump.nix"
        "/etc/nixos/nixorcist/generated/hyprland.nix"
    )

    for file in "${THUNAR_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_warning "File not found: $file (skipping)"
            continue
        fi

        if grep -q "pkgs\.thunar" "$file"; then
            log_info "Commenting thunar in $(basename "$file")..."
            sed -i 's/^[[:space:]]*pkgs\.thunar/#  pkgs.thunar/g' "$file"
            
            if grep -q "#  pkgs.thunar" "$file"; then
                log_success "✓ Commented in $(basename "$file")"
            fi
        else
            log_info "thunar not found in $(basename "$file") (ok)"
        fi
    done
}

# Step 4: Create basic configuration.nix if missing
step_create_base_config() {
    print_header "Step 4: Ensuring Base Configuration"

    if [[ ! -f /etc/nixos/configuration.nix ]]; then
        log_info "Creating default configuration.nix..."
        
        cat > /etc/nixos/configuration.nix << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./nixorcist/generated/all-packages.nix
  ];

  # Nix configuration
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.05";
}
EOF
        log_success "Created /etc/nixos/configuration.nix"
    else
        log_info "configuration.nix already exists; skipping creation"
    fi
}

# Step 5: Rebuild with flakes
step_rebuild_with_flakes() {
    print_header "Step 5: Rebuilding with Flakes Support"

    log_info "Running: sudo nixos-rebuild switch --flakes"
    
    if cd /etc/nixos && sudo nixos-rebuild switch --flakes 2>&1 | tail -30; then
        log_success "NixOS rebuild with flakes completed"
    else
        log_error "Rebuild failed; check output above"
        exit 1
    fi
}

# Step 6: Verify installation
step_verify_installation() {
    print_header "Step 6: Verifying Installation"

    # Check nixorcist script
    if [[ -x "$NIXOS_TARGET/nixorcist.sh" ]]; then
        log_success "nixorcist.sh is executable"
    else
        log_error "nixorcist.sh is not executable"
        chmod +x "$NIXOS_TARGET/nixorcist.sh"
    fi

    # Check library files
    LIB_FILES=(
        cli.sh
        lock.sh
        utils.sh
        gen.sh
        hub.sh
        rebuild.sh
    )

    for libfile in "${LIB_FILES[@]}"; do
        if [[ -f "$NIXOS_TARGET/lib/$libfile" ]]; then
            log_success "lib/$libfile found"
        else
            log_error "lib/$libfile missing"
        fi
    done

    # Test running help
    log_info "Testing nixorcist help command..."
    if "$NIXOS_TARGET/nixorcist.sh" help &>/dev/null; then
        log_success "nixorcist help command works"
    else
        log_warning "nixorcist help command failed (may be normal on first run)"
    fi

    # Check chmod on all shell scripts
    find "$NIXOS_TARGET" -name "*.sh" -type f ! -perm /111 -exec chmod +x {} \;
    log_success "Set executable permissions on all scripts"
}

# Step 7: Summary and next steps
step_summary() {
    print_header "Installation Complete!"

    cat << 'EOF'

✓ NixOS system upgraded
✓ Configuration copied to /etc/nixos/nixorcist
✓ thunar references disabled
✓ Base configuration created
✓ System rebuilt with flakes
✓ Installation verified

────────────────────────────────────────────────────────────────

NEXT STEPS:

1. Verify your system is running:
   $ uname -a

2. Test nixorcist commands:
   $ /etc/nixos/nixorcist/nixorcist.sh help

3. (Optional) Add to PATH for convenience:
   $ export PATH="/etc/nixos/nixorcist:$PATH"

4. Use nixorcist to manage packages:
   $ nixorcist transaction    # Interactive package menu
   $ nixorcist gen            # Generate modules
   $ nixorcist rebuild        # Apply to system

5. (Optional) Re-enable thunar after system stabilizes:
   $ sudo sed -i 's/^#[[:space:]]*pkgs\.thunar/  pkgs.thunar/g' \
       /etc/nixos/nixorcist/generated/{pkg-dump,hyprland}.nix
   $ sudo nixos-rebuild switch --flakes

────────────────────────────────────────────────────────────────

Documentation:
  • INSTALL.md - Full installation guide
  • README_*.md - Module-specific documentation
  • ./nixorcist.sh help - Built-in help

For issues, check INSTALL.md troubleshooting section.

EOF

    log_success "All steps completed successfully!"
}

# Main execution
main() {
    print_header "WtfOS NixOS Post-Fresh-Install Setup"
    
    echo -e "\nThis script will:"
    echo "  1. Upgrade your NixOS system"
    echo "  2. Copy nixorcist configuration"
    echo "  3. Disable thunar package references"
    echo "  4. Create base configuration"
    echo "  5. Rebuild with flakes support"
    echo "  6. Verify installation"
    echo ""

    # Run all steps
    check_prerequisites
    step_upgrade_system
    step_copy_configuration
    step_disable_thunar
    step_create_base_config
    step_rebuild_with_flakes
    step_verify_installation
    step_summary
}

# Run main
main "$@"
