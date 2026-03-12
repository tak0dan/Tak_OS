# README_UTILS.md

## Overview
The utils module provides core validation and package inspection utilities used across the entire nixorcist system. It bridges bash with Nix evaluation to check package existence, resolve attributes, and manage the package index.

## Location
`lib/utils.sh`

## Functions

### `get_index_file()`
Returns the path to the cached nixpkgs index file.

**Returns:** Index file path

---

### `ensure_index()`
Checks if the index exists; builds it if missing.

**Usage:**
```bash
ensure_index  # Safe to call multiple times
```

---

### `get_pkg_description(pkg)`
Fetches the description for a package attribute.

**Parameters:**
- `$1` - Package name/attribute path

**Returns:** Description string or error message

**Usage:**
```bash
desc=$(get_pkg_description "firefox")
echo "$desc"
```

---

### `list_available_packages()`
Lists all packages available in the current nixpkgs.

**Returns:** Newline-separated list of package names

**Usage:**
```bash
mapfile -t all_pkgs < <(list_available_packages)
```

---

### `list_available_packages_lower()`
Variant of above with lowercase conversion.

**Returns:** Lowercase package names

---

### `purge_all_modules()`
Removes all generated nixorcist modules and clears the lock file.

**Usage:**
```bash
purge_all_modules
```

---

### `is_derivation(pkg)`
Checks if a package name resolves to a Nix derivation.

**Parameters:**
- `$1` - Package attribute path

**Returns:** 0 (success) if derivation, 1 otherwise

**Usage:**
```bash
if is_derivation "firefox"; then
  echo "Valid package"
fi
```

---

### `is_attrset(pkg)`
Checks if a package name is an attribute set (namespace) rather than a derivation.

**Parameters:**
- `$1` - Package attribute path

**Returns:** 0 if attrset, 1 otherwise

**Example:** `eclipses.eclipse-java` is an attrset

---

### `list_attrset_children(pkg)`
Lists all derivative children of an attribute set.

**Parameters:**
- `$1` - Attribute set path

**Returns:** Newline-separated list of child attributes

**Usage:**
```bash
mapfile -t variants < <(list_attrset_children "eclipses")
```

---

### `is_valid_token(token)`
Validates that a token is a safe package identifier.

**Parameters:**
- `$1` - Token to validate

**Returns:** 0 if valid, 1 otherwise

**Allowed:** alphanumeric, dots, hyphens, underscores, plus

---

### `sanitize_token(token)`
Cleans and normalizes a token (lowercase, trim whitespace).

**Parameters:**
- `$1` - Raw token

**Returns:** Sanitized token

---

### `resolve_entry_to_packages(entry, out_array)`
Expands a single entry (package or attrset) into a list of actual derivations.

**Parameters:**
- `$1` - Package or attrset name
- `$2` - Name of array variable to populate

**Returns:** 0 on success, 1 if no packages found

**Usage:**
```bash
local -a packages
if resolve_entry_to_packages "eclipses" packages; then
  printf '%s\n' "${packages[@]}"
fi
```

---

## Performance Notes

- Nix evaluation is cached via the index file
- Index rebuilds only on first run or manual refresh
- Package existence checks use fast Nix eval, not filesystem lookups
- Attribute expansion is done in pure bash after resolution

## Error Handling

All functions that use Nix eval suppress stderr and return appropriate exit codes. Caller is responsible for checking return values.

## Code of Conduct

- All functions must be idempotent where applicable
- Validation should happen early; fail fast
- Use array name references (`local -n`) for complex returns
- Quote all variable expansions
- Document Nix eval expressions inline

## Dependencies
- `nix` eval command
- GNU tools: `awk`, `grep`, `sed`
