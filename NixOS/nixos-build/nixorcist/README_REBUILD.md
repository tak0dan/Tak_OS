# README_REBUILD.md

## Overview
The rebuild module handles NixOS system rebuild with staging, validation, and cleanup. It provides a safe rebuild pipeline that validates changes before applying them to the live system.

## Location
`lib/rebuild.sh`

## Functions

### `run_rebuild()`
Executes the complete NixOS rebuild workflow.

**Workflow:**
1. Create staging snapshot (`/etc/nixos/.staging`)
2. Copy current `/etc/nixos` files to staging
3. Validate build using `nix-build`
4. Execute rebuild script if validation passes
5. Clean up staging directory
6. Display progress and results

**Output:**
```
  ▶ NixOS Rebuild
  ─────────────────────────────────────────────────────────────
  ℹ Creating staging snapshot
  ℹ Validating build
  ✓ Build validation passed
  ℹ Promoting staging to live config
  ℹ Cleaning up staging directory
  ✓ Staging cleaned
  ✓ Rebuild complete
```

---

### `cleanup_staging()`
Removes unnecessary files from `.staging` directory.

**Kept Files:**
- `configuration.nix` - Main config file
- `nixorcist/generated/*` - All generated modules

**Removed:**
- Other configuration files
- Cache files
- Temporary files
- Empty directories

**Purpose:**
Minimize staging directory size while preserving enough for rollback/audit.

---

## Staging Directory

### Purpose
Provides a safe sandbox for validation before applying changes to the live system.

### Location
`/etc/nixos/.staging/`

### Lifecycle
1. **Creation**: `cp -r /etc/nixos/* /etc/nixos/.staging/`
2. **Validation**: `nix-build` test
3. **Cleanup**: Remove non-essential files
4. **Persistence**: Can inspect after rebuild

### Inspection
```bash
# View what was rebuilt
ls -la /etc/nixos/.staging/nixorcist/generated/.modules/
cat /etc/nixos/.staging/configuration.nix
```

---

## Build Validation

### Process
```bash
nix-build '<nixpkgs/nixos>' \
  --attr config.system.build.toplevel \
  --include nixos-config=/etc/nixos/.staging/configuration.nix
```

Validates:
- Nix syntax correctness
- All module references resolve
- All package attributes exist
- No circular dependencies

---

## Rebuild Script Integration

Calls external script: `/etc/nixos/scripts/nix-rebuild-smart.sh`

**Requirements:**
- Script must exist and be executable
- Returns 0 on success, non-zero on failure
- Handles actual `nixos-rebuild` invocation

**Typical implementation:**
```bash
#!/bin/bash
sudo nixos-rebuild switch --flakes
```

---

## Error Handling

### Build Validation Failure
If `nix-build` fails:
- No changes applied to live system
- Staging directory preserved for inspection
- Error message shows build failure details

### Rebuild Script Failure
If rebuild script fails:
- Live system unchanged
- Staging directory preserved
- User must troubleshoot via `nix-build` output

---

## Safety Features

1. **Two-stage process**
   - Validate in staging first
   - Only proceed if validation passes

2. **Atomic operations**
   - Copy all files before validation
   - Rebuild only if safe

3. **Preserves state**
   - Staging dir kept for inspection
   - Cleanup only removes temp files

4. **Clear feedback**
   - Progress shown at each stage
   - Success/error messages explicit

---

## Performance

- Staging copy: O(size of /etc/nixos)
- Nix-build validation: Depends on system complexity
- Cleanup: O(files in staging)
- Total time: typically 30s - 5m depending on system

---

## Code of Conduct

- Always validate before applying (even for small changes)
- Preserve evidence (staging dir) for troubleshooting
- Clean up only after successful rebuild
- Use external rebuild script for actual nixos-rebuild
- Report all errors with context
- Maintain idempotency (safe to re-run)

## Dependencies
- Standard Unix tools: `cp`, `find`, `rm`, `mkdir`
- `nix-build` command (requires nix installed)
- External rebuild script at `/etc/nixos/scripts/nix-rebuild-smart.sh`
- `cli.sh` - Visual feedback
- Sufficient disk space for staging copy (~100MB typical)

## Troubleshooting

### "Rebuild script not found"
```bash
ls -la /etc/nixos/scripts/nix-rebuild-smart.sh
# If missing, create it
```

### "Staging cleanup failed"
Staging directory might have permission issues:
```bash
sudo rm -rf /etc/nixos/.staging
```

### "Build validation failed"
Staging has correct copy but Nix eval fails:
```bash
# Inspect error
cat /etc/nixos/.staging/configuration.nix
# Check for undefined references
```

### Disk space issues
Staging copy needs ~100MB free:
```bash
df -h /etc/nixos
```

## Advanced

### Manual staging inspection
```bash
cd /etc/nixos/.staging
nixos-rebuild build-vm --flakes  # Test without applying
```

### Rollback
If rebuild succeeds but system breaks:
```bash
sudo nixos-rebuild switch --rollback
```
