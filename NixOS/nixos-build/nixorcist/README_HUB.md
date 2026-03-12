# README_HUB.md

## Overview
The hub module generates the central import file that aggregates all nixorcist-managed modules into the NixOS configuration.

## Location
`lib/hub.sh`

## Functions

### `regenerate_hub()`
Generates/updates `generated/all-packages.nix` from current modules.

**Workflow:**
1. Create `generated/` directory if missing
2. Scan `MODULES_DIR` for `.nix` files
3. Generate import list
4. Write hub file atomically
5. Display feedback with module count

**Output:**
```
  ▶ Regenerating Hub
  ─────────────────────────────────────────────────────────────
  ✓ Hub regenerated (42 modules imported)
```

---

## Hub File Format

**Location:** `generated/all-packages.nix`

**Content:**
```nix
{ config, pkgs, ... }:
{
  imports = [
    ./.modules/firefox.nix
    ./.modules/vim.nix
    ./.modules/git.nix
    # ... one per generated module
  ];
}
```

---

## Module Structure

The hub file is a standard NixOS module that:
- Accepts `config` and `pkgs` as parameters
- Imports all nixorcist-generated modules
- Integrates into your NixOS `configuration.nix`

**Usage in configuration.nix:**
```nix
imports = [
  ./hardware-configuration.nix
  ./nixorcist/generated/all-packages.nix
  # ... other modules
];
```

---

## Integration Points

### Sourcing Hub
The hub should be sourced in your main NixOS configuration:

```nix
# In /etc/nixos/configuration.nix or similar
{
  imports = [
    /etc/nixos/nixorcist/generated/all-packages.nix
  ];
  
  # ... rest of config
}
```

### Rebuild Process
1. Generate modules (`nixorcist gen`)
2. Regenerate hub (`nixorcist hub`)
3. Run rebuild (`nixorcist rebuild`)

---

## Module Count

The hub tracks the number of modules being imported and displays it:
```
✓ Hub regenerated (0 modules imported)    # Empty lock
✓ Hub regenerated (15 modules imported)   # Normal
✓ Hub regenerated (127 modules imported)  # Large system
```

---

## Error Handling

**File Write Failure:**
```
✗ Error: Failed to write hub file
```

Possible causes:
- Permission denied on `generated/` directory
- Disk full
- Read-only filesystem

Solutions:
- Check directory permissions
- Ensure `/etc/nixos/nixorcist` is writable
- Verify free disk space

---

## Performance

- Hub generation is O(n) where n = module count
- File I/O is atomic (write-then-rename pattern)
- Safe for large numbers of modules (100+)
- Minimal system impact

---

## Code of Conduct

- Always use `MODULES_DIR` variable (not hardcoded paths)
- Check directory exists before scanning
- Use atomic writes to prevent corruption
- Count modules for feedback
- Report errors via `show_error()`
- Log success with `show_success()`

## Dependencies
- `cli.sh` - Visual feedback
- `lock.sh` - MODULES_DIR definition
- Bash string operations
- File I/O commands: `mkdir`, `echo`

## Troubleshooting

**Hub not syncing with modules:**
```bash
nixorcist hub  # Regenerate from scratch
```

**Duplicate imports in hub:**
- Module filenames not unique
- Check for naming conflicts in lock file
- Purge and regenerate: `nixorcist purge && nixorcist all`

**Hub too large:**
- Normal for systems with 100+ packages
- No performance impact (imports are lazy-loaded)
- Can split into multiple hubs if needed (advanced)
