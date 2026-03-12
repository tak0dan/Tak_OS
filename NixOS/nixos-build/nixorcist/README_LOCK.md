# README_LOCK.md

## Overview
The lock module is the core transaction engine for nixorcist. It manages the package lock file, handles interactive selection via fzf, expands attribute sets into concrete packages, and applies transactions atomically.

## Location
`lib/lock.sh`

## Core Functions

### `read_lock_entries()`
Reads all valid entries from the lock file (excludes built marker).

**Returns:** Newline-separated list of package names

**Usage:**
```bash
mapfile -t packages < <(read_lock_entries)
```

---

### `write_lock_entries(array_name)`
Atomically writes array contents to lock file with marker.

**Parameters:**
- `$1` - Name of array variable (by reference)

**Usage:**
```bash
declare -a new_packages
new_packages+=("firefox" "vim")
write_lock_entries new_packages
```

---

## Transaction Functions

### `transaction_init()`
Initializes global transaction state (TX_ADD, TX_REMOVE, TX_LOCK).

**Called automatically by:** `run_transaction_cli()`

---

### `transaction_cleanup()`
Deletes temporary transaction file.

**Called at:** End of transaction workflow

---

### `transaction_expand_and_stage(mode, entry)`
Expands entry (package or attrset) and stages it for add/remove.

**Parameters:**
- `$1` - Mode: `add` or `remove`
- `$2` - Package name or attrset

**Returns:** 0 on success, 1 if validation fails

**Behavior:**
- Validates token format
- Resolves to actual derivations (expands attrsets)
- Adds to TX_ADD or TX_REMOVE dict
- Shows visual feedback

---

### `transaction_apply()`
Applies staged changes to the lock file atomically.

**Behavior:**
- Start with current lock (TX_LOCK)
- Add all TX_ADD entries
- Remove all TX_REMOVE entries
- Write result back to lock file
- Writes temp transaction file for reference

---

## Interactive Selection Functions

### `transaction_pick_from_index()`
Opens fzf to select packages from the nixpkgs index with preview.

**Returns:** Selected package names (newline-separated)

**Features:**
- Multi-select with TAB
- Live description preview
- Type-aware indicator (Package vs Attrset)

---

### `transaction_pick_for_remove()`
Opens fzf to select from currently locked + staged packages.

**Returns:** Selected package names for removal

---

### `transaction_unstage_menu(mode)`
Interactive removal of staged items.

**Parameters:**
- `$1` - Mode: `add` or `remove`

---

### `transaction_preview()`
Displays current transaction state before apply.

**Usage:**
```bash
transaction_preview  # Shows staged +/- with counts
```

---

## Main Workflow

### `run_transaction_cli()`
Complete interactive transaction menu loop.

**Usage:**
```bash
run_transaction_cli
```

**Menu:**
1. Stage installs (fzf multi-select)
2. Unstage installs (remove from staging)
3. Stage removals
4. Unstage removals
5. Preview transaction
6. Apply changes
7. Cancel

---

### `select_packages()`, `add_packages()`, `remove_packages()`
Legacy aliases that now call `run_transaction_cli()`.

---

## Package Import Functions

### `import_from_file(file, route)`
Reads packages from a file and applies them interactively or in auto mode.

**Parameters:**
- `$1` - File path

**Supported formats:**
- Newline-separated: `firefox\ngit\nvim`
- Comma-separated: `firefox,git,vim`
- Space-separated: `firefox git vim`

**Parser mode switches:**
- default mode = install
- `+` => install mode
- `-` => delete mode
- signs may appear inline and repeatedly (example: `+f+g -vim +helix`)

**Workflow:**
1. Parse and normalize input
2. Stage entries according to parser mode (add/remove)
3. Optionally review in transaction menu
4. Apply transaction (remove runs after add)
5. Remove matching managed module files for removals
6. Regenerate hub after removals
7. Optionally run full pipeline (`all`)

---

### `handle_missing_package(missing)`
Attempts to resolve unrecognized package names via fuzzy search.

**Parameters:**
- `$1` - Unrecognized package name

**Returns:** 0 if resolved, 1 if user skipped

---

### `install_from_args(args...)`
Creates a temporary file from CLI args and routes to `import_from_file` in auto mode.

### `delete_from_args(args...)`
Creates a temporary file prefixed with `-` and routes to `import_from_file` in auto mode.

### `chant_from_args(args...)`
Creates a temporary file from raw CLI args and routes to `import_from_file` in auto mode.
Supports mixed add/remove mode transitions with `+/-`.

---

## Data Structures

### Global Associative Arrays (during transaction)
```bash
TX_ADD[@]     # Packages to install
TX_REMOVE[@]  # Packages to remove
TX_LOCK[@]    # Current lock state
TX_FILE       # Temp transaction file path
```

## Code of Conduct

- All user input must be validated with `is_valid_token()`
- Sanitize tokens with `sanitize_token()`
- Always use `resolve_entry_to_packages()` for expansions
- Never directly modify lock file; use `write_lock_entries()`
- Transaction state is global; always call cleanup
- Provide visual feedback for every user action
- Support both single packages and attribute sets uniformly

## Error Handling

- Show error messages via `show_error()`
- Miss entries logged but don't abort import
- User can review and resolve in transaction menu
- Failed validation prevents staging

## Dependencies
- `cli.sh` - Visual output functions
- `utils.sh` - Validation and expansion
- `fzf` - Interactive selection
- GNU tools: `awk`, `grep`, `sed`
