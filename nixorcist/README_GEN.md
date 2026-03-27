# gen.sh — Module Generation

Generates, deletes, and manages the individual `.nix` files that make up the
Nixorcist package set.

---

## Directory

All modules live in `generated/.modules/`.  The filename is derived from the
attribute path: dots become dots, so `python3Packages.pip` → `python3Packages.pip.nix`.

---

## Functions

### generate_modules

Iterates the lock file and generates a `.nix` for every package that does not
already have one.  Uses `is_derivation_cached` (from utils.sh) to validate each
package before generating.

Progress is shown with `○ Exists` / `✓ Generated` / `✗ Skipped` per package.

### generate_module_for_pkg PKG

Generates a single `.nix` for one package without touching the lock.

```nix
# generated/.modules/firefox.nix
{ pkgs, ... }: { environment.systemPackages = [ pkgs.firefox ]; }
```

For namespaced packages (e.g. `python3Packages.pip`):

```nix
{ pkgs, ... }: { environment.systemPackages = [ pkgs.python3Packages.pip ]; }
```

### module_filename_for_pkg PKG

Returns the `.nix` filename for a given attribute path.

```bash
module_filename_for_pkg "python3Packages.pip"
# → python3Packages.pip.nix
```

### remove_staged_modules ARRAY_NAMEREF

Deletes `.nix` files for all packages in the given array.
Called by `nixorcist_pipeline` as Phase 1 (before generating new modules).

### cleanup_orphan_modules

Deletes any `.nix` in `generated/.modules/` that has no corresponding entry in
the current lock.  Called at the start of every rebuild as a safety net.

### purge_all_modules

Deletes all generated modules and clears the lock.  Used by `nixorcist purge`.
