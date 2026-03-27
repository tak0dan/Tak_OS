# README_lock.sh - Package Lock & Transaction Module

## Purpose
Manages the lock file (package declarations), implements the transaction engine for staged add/remove operations, and handles interactive package selection with attribute set expansion.

## Structure

```
lib/lock.sh
├── Lock File Management
│   ├── read_lock_entries()         # Read current packages (excluding BUILT_MARKER)
│   ├── write_lock_entries(array)   # Write array to lock file with marker
│   └── scan_managed_modules()      # Extract ATTRPATH from generated modules
│
├── Transaction State
│   ├── transaction_init()          # Initialize TX_* associative arrays
│   ├── transaction_cleanup()       # Remove temp transaction file
│   └── transaction_write_temp()    # Write staged changes to file
│
├── Transaction Operations
│   ├── transaction_expand_and_stage(mode, entry)  # Add/remove entry
│   ├── transaction_apply()         # Apply staged changes to lock
│   └── transaction_preview()       # Show preview of changes
│
├── Interactive Selection
│   ├── transaction_pick_from_index()      # fzf selector from all packages
│   ├── transaction_pick_for_remove()      # fzf selector from current/staged
│   ├── transaction_unstage_menu(mode)     # Remove item from transaction
│   └── transaction_menu_loop()            # Main transaction UI
│
├── Import & Resolution
│   ├── import_from_file(file, route)      # Import packages from file
│   ├── install_from_args(args...)         # Temp-file wrapper for arg install
│   ├── delete_from_args(args...)          # Temp-file wrapper for arg delete
│   ├── chant_from_args(args...)           # Temp-file wrapper for mixed +/- args
│   ├── handle_missing_package(missing)    # Interactive fuzzy resolution
│   └── run_transaction_cli()              # Entry point
│
└── Legacy Aliases (for backwards compatibility)
    ├── select_packages()           # Alias to run_transaction_cli()
    ├── add_packages()              # Alias to run_transaction_cli()
    └── remove_packages()           # Alias to run_transaction_cli()
```

## Key Concepts

### Lock File Format
```
package-name-1
package-name-2
eclipses.eclipse-java
#$built$#
```

The `#$built$#` marker indicates the rebuild has been applied.

### Associative Arrays (Transaction State)
```bash
TX_ADD[$pkg]=1          # Packages to install
TX_REMOVE[$pkg]=1       # Packages to remove
TX_LOCK[$pkg]=1         # Current lock state
```

### Attribute Set Expansion
When user selects `eclipses` (an attribute set), nixorcist automatically expands it to all derivations:
- `eclipses.eclipse-java`
- `eclipses.eclipse-cpp`
- `eclipses.eclipse-sdk`
- etc.

## Function Reference

### read_lock_entries()
Returns current packages from lock file (sorted, unique, excluding build marker).
```bash
mapfile -t packages < <(read_lock_entries)
```

### transaction_init()
Initialize transaction state from current lock.
```bash
transaction_init
# Sets: TX_LOCK, TX_ADD, TX_REMOVE, TX_FILE
```

### transaction_expand_and_stage(mode, entry)
Add or remove a package/attribute set, expanding attributes as needed.
```bash
transaction_expand_and_stage add "firefox"
transaction_expand_and_stage remove "eclipses"  # Removes all eclipse variants
```

### transaction_preview()
Display staged additions and removals.
```bash
transaction_preview
```

### transaction_apply()
Write staged changes to lock file.
```bash
transaction_apply
```

### run_transaction_cli()
Main interactive transaction menu.
```bash
run_transaction_cli
# Returns 0 on success, 1 on cancel
```

### import_from_file(file, route)
Import packages from a text file with optional review, or auto-apply when called by wrappers.
```bash
import_from_file "packages.txt" "chant"
# File can be comma-separated, newline-separated, or space-separated
```

Mode switching is supported directly in import tokens:
- default token mode is install (`add`)
- `+` switches parser mode to install
- `-` switches parser mode to delete
- switches can be inline and repeated (`+f+g -vim +helix`)

Example:
```bash
echo "a b,c,d -e f,+a +f+g h + l - l" > chant.txt
import_from_file "chant.txt" "chant"
```

Result:
- staged add: `a b c d a f g h l`
- staged remove: `e f l`
- apply order keeps natural delete priority (remove after add)

### install_from_args(args...)
Creates a temporary file from CLI args and routes to `import_from_file` in auto mode.

### delete_from_args(args...)
Creates a temporary file prefixed with `-` and routes to `import_from_file` in auto mode.
Also removes matching generated module files and regenerates hub.

### chant_from_args(args...)
Creates a temporary file from raw CLI args and routes to `import_from_file` in auto mode.
Supports mixed `+/-` transitions in one command.

## Code of Conduct

1. **Transaction atomicity**: Changes don't apply until `transaction_apply()` is called
2. **Validation**: All tokens are validated with `is_valid_token()` before processing
3. **Attribute expansion**: Attribute sets are automatically expanded to derivations
4. **Feedback**: Every operation provides visual feedback via `show_*()` functions
5. **Error handling**: Invalid entries are logged but don't block the transaction
6. **Temporary files**: Transaction files are cleaned up after use

## Integration Points

- **gen.sh**: Processes lock entries from `read_lock_entries()`
- **utils.sh**: Uses `is_valid_token()`, `sanitize_token()`, `resolve_entry_to_packages()`
- **cli.sh**: Uses `show_error()`, `show_info()`, `show_item()` for feedback

## Example Workflow

```bash
# User starts transaction
run_transaction_cli

# User selects packages via fzf (marked with TAB)
# nixorcist stages them in TX_ADD

# User previews changes
# nixorcist shows staging summary

# User applies
# transaction_apply() writes to lock file

# User continues to gen, hub, rebuild
```
