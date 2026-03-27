# README_gen.sh - Module Generation

## Purpose
Generates individual Nix modules from lock file entries and manages module purging.

## Structure

```
lib/gen.sh
├── is_derivation(pkg)      # Validate package is a valid NixOS derivation
├── generate_modules()      # Main: create .nix files for each lock entry
└── purge_all_modules()     # Remove all generated modules & clear lock
```

## Module Generation Process

### Generated Module Format
Each lock entry produces a file in `$MODULES_DIR/.modules/`:

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    firefox
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: firefox
```

The `#$nixorcist$#` marker and `NIXORCIST-ATTRPATH` comment are required for:
- Identifying generated (vs. hand-written) modules
- Tracking which packages each module provides
- Safe purging (only removes marked files)

### Safe Naming
Package names are sanitized for filesystem compatibility:
```
Input:  pkgs.google-chrome
Sha:    google-chrome
Name:   google-chrome.nix

Input:  kdePackages/breeze/gtk
Safe:   kdepackages-breeze-gtk.nix

Input:  nixpkgs.python3:dev
Safe:   nixpkgs-python3-dev.nix
```

Conversion rules:
- `/` → `-`
- ` ` (space) → `_`
- `:` → `_`
- All lowercase

## Function Reference

### is_derivation(pkg)
Check if a package is a valid NixOS derivation (not an attribute set, not missing).
```bash
if is_derivation "firefox"; then
  echo "Valid package"
else
  echo "Not a package (attribute set or missing)"
fi
```

Uses `nix eval` to check:
```
nix eval --impure --expr '...'
| grep -q true  # Returns 0 if derivation, 1 otherwise
```

### generate_modules()
Main function: creates .nix files for all lock entries.
```bash
generate_modules
```

Process:
1. Read all entries from lock file
2. For each entry:
   - Validate it's a derivation with `is_derivation()`
   - Skip non-packages and warn user
   - Generate safe filename
   - Check if module already exists (skip if yes)
   - Write standard module format to file

Output example:
```
  ℹ Processing 15 lock entries
  ○ Exists: firefox.nix
  ✓ Generated: nginx.nix
  ✗ Skipped non-package: invalid-pkg
  ─────────────────────────────────────
  Summary: 12 generated | 2 existed | 1 skipped
```

### purge_all_modules()
Remove all generated modules and clear lock file.
```bash
purge_all_modules
```

Safety checks:
- Only removes files with `$NIXORCIST_MARKER`
- Clears lock file
- Counts removed files in output

## Code of Conduct

1. **Validation before write**: Every package is checked before module creation
2. **Safe purging**: Only removes marked files (prevents accidental data loss)
3. **Idempotent**: Running `generate_modules()` twice is safe (skips existing)
4. **Feedback**: User sees status for each package (generated, exists, skipped)
5. **Error recovery**: Invalid packages are reported but don't crash the process

## Integration

- **Input**: Reads from `$LOCK_FILE` via `read_lock_entries()` from lock.sh
- **Validates**: Uses `is_derivation()` to check package validity
- **Output**: Writes to `$MODULES_DIR/.modules/` (set in dirs.sh)
- **Marker**: Uses `$NIXORCIST_MARKER` from lock.sh

## Example

```bash
# Lock file contains:
# firefox
# vim
# invalid-pkg
# nginx

# Run generate_modules
# Output:
#   ℹ Processing 4 lock entries
#   ✓ Generated: firefox.nix
#   ✓ Generated: vim.nix
#   ✗ Skipped non-package: invalid-pkg
#   ✓ Generated: nginx.nix
#   ─────────────────────────────────
#   Summary: 3 generated | 0 existed | 1 skipped

# Files created:
# /etc/nixos/nixorcist/generated/.modules/firefox.nix
# /etc/nixos/nixorcist/generated/.modules/vim.nix
# /etc/nixos/nixorcist/generated/.modules/nginx.nix
```
