# README_hub.sh - Hub Generation

## Purpose
Generates the main hub file (`all-packages.nix`) that imports all generated modules. This is the single file that NixOS configuration imports to apply all nixorcist-managed packages.

## Structure

```
lib/hub.sh
└── regenerate_hub()    # Main: create all-packages.nix with imports
```

## Hub Function

The hub is the final integration point between nixorcist modules and NixOS configuration:

```
NixOS configuration.nix
        ↓
   imports all-packages.nix
        ↓
   .modules/firefox.nix
   .modules/nginx.nix
   .modules/vim.nix
   ... (all packages)
```

## Generated Hub File

Output: `/etc/nixos/nixorcist/generated/all-packages.nix`

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./.modules/firefox.nix
    ./.modules/nginx.nix
    ./.modules/vim.nix
    ./.modules/python3.nix
  ];
}
```

## Function Reference

### regenerate_hub()
Scan all modules and generate updated hub with imports.

```bash
regenerate_hub
```

Process:
1. Create/clear `$ROOT/generated/` directory
2. Scan `$MODULES_DIR/.modules/` for `.nix` files
3. Generate standard hub wrapper
4. Add import line for each module found
5. Write to `all-packages.nix`

Output example:
```
✓ Hub regenerated (15 modules imported)
```

## Code of Conduct

1. **Automatic discovery**: Scans for existing .nix files (no manual list)
2. **Dynamic**: ReRunning updates imports if modules changed
3. **Standard format**: Always produces valid NixOS module syntax
4. **Module count**: Reports how many modules were imported
5. **Error handling**: Reports write failures clearly

## Integration

- **Input**: Scanned from `$MODULES_DIR/.modules/`
- **Output**: Written to `$ROOT/generated/all-packages.nix`
- **Used by**: NixOS configuration.nix imports this file
- **Depends on**: gen.sh (must run first to create modules)

## NixOS Configuration

In your `/etc/nixos/configuration.nix`:

```nix
{
  imports = [
    ./hardware-configuration.nix
    ./nixorcist/generated/all-packages.nix  # nixorcist hub
    ./modules/users.nix
    ./modules/audio.nix
    # ... other modules
  ];

  # Rest of config
}
```

## Example Workflow

```bash
# 1. Generate modules from lock
generate_modules
#   ✓ Generated: firefox.nix
#   ✓ Generated: nginx.nix

# 2. Regenerate hub
regenerate_hub
#   ✓ Hub regenerated (2 modules imported)

# 3. Content of all-packages.nix:
#   { config, pkgs, ... }:
#   {
#     imports = [
#       ./.modules/firefox.nix
#       ./.modules/nginx.nix
#     ];
#   }

# 4. NixOS now imports both modules
# 5. Both firefox and nginx are installed on rebuild
```

## Common Patterns

### Adding a new package
```bash
# 1. Stage in transaction
nixorcist transaction  # Add "firefox"

# 2. Generate creates firefox.nix
nixorcist gen

# 3. Hub automatically includes it
nixorcist hub

# 4. Rebuild applies to system
nixorcist rebuild
```

### Removing a package
```bash
# 1. Stage removal
nixorcist transaction  # Remove "firefox"

# 2. Unlock from lock file
# (No module created)

# 3. Hub excludes it (no .nix file)
nixorcist hub

# 4. Rebuild removes from system
nixorcist rebuild
```
