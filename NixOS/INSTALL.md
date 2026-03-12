# NixOS Installation & Setup Guide

## Quick Start

Follow these steps to set up nixorcist on a fresh NixOS installation:

### Prerequisites
- Fresh NixOS install with base system running
- Internet connectivity
- sudo/root access

### Step-by-Step Installation

#### 1. Initial Rebuild (with system upgrade)
```bash
sudo nixos-rebuild switch --upgrade
```

This ensures your system is up-to-date before adding new packages.

#### 2. Clone the WtfOS Repository
```bash
cd ~
git clone https://github.com/yourusername/WtfOS.git
cd WtfOS
```

#### 3. Copy Configuration to NixOS
```bash
sudo cp -r NixOS/nixos-build /etc/nixos/nixorcist
```

This places the nixorcist tool and Hyprland configuration in the standard location.

#### 4. Comment Out thunar Package References

The setup requires disabling `pkgs.thunar` initially as it may have unresolved dependencies in your environment.

**File 1:** `/etc/nixos/nixorcist/generated/pkg-dump.nix`
```bash
sudo sed -i 's/^  pkgs\.thunar/#  pkgs.thunar/g' /etc/nixos/nixorcist/generated/pkg-dump.nix
```

**File 2:** `/etc/nixos/nixorcist/generated/hyprland.nix`
```bash
sudo sed -i 's/^  pkgs\.thunar/#  pkgs.thunar/g' /etc/nixos/nixorcist/generated/hyprland.nix
```

Or manually edit and add `#` before lines containing `pkgs.thunar`.

#### 5. Rebuild with Flakes Enabled
```bash
sudo nixos-rebuild switch --flakes
```

The `--flakes` flag enables the new Nix flakes system, which is required for this configuration.

#### 6. Verify Installation
```bash
# Check if nixorcist is accessible
/etc/nixos/nixorcist/nixorcist.sh help

# Or add to PATH for convenience
export PATH="/etc/nixos/nixorcist:$PATH"
nixorcist help
```

---

## Automated Installation

To automate all these steps, use the provided `install.sh` script:

```bash
cd WtfOS/NixOS
sudo bash install.sh
```

The script will:
1. ✓ Run `nixos-rebuild switch --upgrade`
2. ✓ Copy configuration to `/etc/nixos/nixorcist`
3. ✓ Comment out thunar references
4. ✓ Run final rebuild with flakes
5. ✓ Verify installation

---

## Manual Step-by-Step (if not using script)

### 1. Upgrade System
```bash
sudo nixos-rebuild switch --upgrade
```

### 2. Prepare NixOS Directory
```bash
sudo mkdir -p /etc/nixos
cd ~/WtfOS
```

### 3. Copy Configuration
```bash
sudo cp -r NixOS/nixos-build /etc/nixos/nixorcist
```

### 4. Fix thunar References
```bash
# Disable thunar in pkg-dump.nix
if sudo grep -q "pkgs\.thunar" /etc/nixos/nixorcist/generated/pkg-dump.nix; then
  sudo sed -i 's/^[[:space:]]*pkgs\.thunar/#  pkgs.thunar/g' /etc/nixos/nixorcist/generated/pkg-dump.nix
  echo "✓ Commented thunar in pkg-dump.nix"
fi

# Disable thunar in hyprland.nix
if sudo grep -q "pkgs\.thunar" /etc/nixos/nixorcist/generated/hyprland.nix; then
  sudo sed -i 's/^[[:space:]]*pkgs\.thunar/#  pkgs.thunar/g' /etc/nixos/nixorcist/generated/hyprland.nix
  echo "✓ Commented thunar in hyprland.nix"
fi
```

### 5. Create Configuration Hook
If you don't have a `/etc/nixos/configuration.nix`, create one:

```bash
sudo mkdir -p /etc/nixos/generated
sudo cat > /etc/nixos/configuration.nix << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./nixorcist/generated/all-packages.nix
  ];

  system.stateVersion = "24.05";
}
EOF
```

### 6. Rebuild with Flakes
```bash
cd /etc/nixos
sudo nixos-rebuild switch --flakes
```

---

## Troubleshooting

### Issue: "flakes is not a known option"
**Solution:** Flakes are experimental; enable them in `/etc/nixos/configuration.nix`:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

### Issue: "thunar: command not found"
**Solution:** This is expected—we commented out thunar to avoid conflicts.

### Issue: "package attribute missing"
**Solution:** Run the automated install script to ensure all steps are followed correctly:
```bash
cd WtfOS/NixOS
sudo bash install.sh --skip-upgrade  # Skip upgrade if already done
```

### Issue: "/etc/nixos/nixorcist not found"
**Solution:** Ensure the copy step succeeded:
```bash
ls -la /etc/nixos/nixorcist/
# Should show: nixorcist.sh, lib/, generated/, etc.
```

---

## Post-Installation

### Using nixorcist

Once installed, manage packages declaratively:

```bash
# Enter transaction menu
nixorcist transaction

# Generate modules from lock file
nixorcist gen

# Rebuild configuration
nixorcist rebuild

# Or do all at once
nixorcist all
```

### Re-enabling thunar (Optional)

After system stabilizes, you can re-enable thunar:

```bash
# Uncomment thunar
sudo sed -i 's/^#[[:space:]]*pkgs\.thunar/  pkgs.thunar/g' /etc/nixos/nixorcist/generated/{pkg-dump,hyprland}.nix

# Rebuild to apply
sudo nixos-rebuild switch --flakes
```

### Adding the tool to PATH

For convenience, add to your shell profile:

```bash
# In ~/.bashrc or ~/.zshrc
export PATH="/etc/nixos/nixorcist:$PATH"
```

Then source the file:
```bash
source ~/.bashrc  # or ~/.zshrc
```

Now you can use `nixorcist` directly from anywhere.

---

## System Requirements

- **Memory:** 2GB minimum (4GB recommended for compilation)
- **Disk Space:** 5GB free for initial build, 1GB for package cache
- **CPU:** Any (slower CPUs need more time for compilation)
- **Network:** Internet connection for package downloads

---

## Documentation

For detailed information about nixorcist modules, see:

- [README_cli.md](../nixos-build/nixorcist/README_cli.md) - CLI interface
- [README_lock.md](../nixos-build/nixorcist/README_lock.md) - Package management
- [README_gen.md](../nixos-build/nixorcist/README_gen.md) - Module generation
- [README_hub.md](../nixos-build/nixorcist/README_hub.md) - Hub aggregation
- [README_rebuild.md](../nixos-build/nixorcist/README_rebuild.md) - System rebuild

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review module-specific documentation
3. Inspect log output from `nixos-rebuild`
4. Verify file permissions: `ls -la /etc/nixos/nixorcist/`
