# README_utils.sh - Utility Functions

## Purpose
Provides shared validation, token sanitization, package resolution, and index management utilities used across all nixorcist modules.

## Structure

```
lib/utils.sh
├── Index Management
│   ├── get_index_file()              # Path to cached index
│   ├── ensure_index()                # Create index if missing
│   └── build_nix_index()             # Generate initial index
│
├── Package Metadata
│   ├── get_pkg_description(pkg)      # Fetch package description
│   ├── list_available_packages()     # All packages in nixpkgs
│   └── list_available_packages_lower() # Lowercase version for matching
│
├── Package Validation
│   ├── is_derivation(pkg)            # Is it a valid package?
│   ├── is_attrset(pkg)               # Is it an attribute set?
│   ├── list_attrset_children(pkg)    # Get sub-attributes
│   └── resolve_entry_to_packages(entry, out_ref) # Expand to derivations
│
├── Token Processing
│   ├── is_valid_token(token)         # Matches [a-zA-Z0-9._+-]
│   └── sanitize_token(token)         # Lowercase + trim whitespace
│
└── System Integration
    └── purge_all_modules()           # Legacy: now in gen.sh
```

## Index System

The index file (`/etc/nixos/nixorcist/cache/nixpkgs-index.txt`) caches package metadata:

```
firefox|A powerful, free web browser
vim|Highly configurable text editor
nginx|HTTP/1.1 HTTP/1.0 reverse proxy
python3|Interpreted, interactive, OOP language
```

Format: `package-name|description`

Built once and reused by fzf selectors for fast searching.

## Function Reference

### get_index_file()
Returns the cached index file path.
```bash
INDEX="$(get_index_file)"
cat "$INDEX"
```

### build_nix_index()
Create the index from nixpkgs (runs `nix eval`).
```bash
build_nix_index
# Generates nixpkgs-index.txt with all packages and descriptions
```

### get_pkg_description(pkg)
Fetch description for a single package.
```bash
desc=$(get_pkg_description "firefox")
# Output: A powerful, free web browser
```

Returns:
- Actual description if derivation
- "Attribute set" if namespace (e.g., `kdePackages`)
- "Not a package" if missing/invalid

### is_derivation(pkg)
Check if package is a valid NixOS derivation.
```bash
if is_derivation "firefox"; then
  echo "Valid"
fi
```

### is_attrset(pkg)
Check if item is an attribute set (namespace) not a derivation.
```bash
if is_attrset "eclipses"; then
  echo "This is a namespace with sub-attributes"
fi
```

### list_attrset_children(pkg)
Get all sub-attributes of an attribute set.
```bash
mapfile -t children < <(list_attrset_children "eclipses")
# children = (eclipse-java eclipse-cpp eclipse-sdk ...)
```

### resolve_entry_to_packages(entry, ref)
Expand package or attribute set to derivations array.
```bash
resolved=()
if resolve_entry_to_packages "firefox" resolved; then
  # resolved = (firefox)
else
  # Failed - not a package or attrset
fi

# Or with attribute set:
resolve_entry_to_packages "eclipses" resolved
# resolved = (eclipses.eclipse-java eclipses.eclipse-cpp ...)
```

### is_valid_token(token)
Check if token matches valid package name pattern.
```bash
if is_valid_token "firefox"; then
  echo "Valid"
fi

# Matches: [a-zA-Z0-9._+-]
# Rejects: leading/trailing whitespace, special chars
```

### sanitize_token(token)
Normalize token: lowercase + trim whitespace.
```bash
clean=$(sanitize_token "  FIREFOX  ")
# Output: firefox
```

## Code of Conduct

1. **Lazy loading**: Index is built only when needed via `ensure_index()`
2. **Caching**: Index file is reused across calls (improves performance)
3. **Token validation**: All user input is validated before processing
4. **Safe expansion**: Attribute sets are expanded to actual derivations only
5. **Error handling**: Functions return meaningful status codes (0=success, 1=fail)
6. **Nix dependency**: Some functions require working `nix` command

## Integration

- **Called by**: lock.sh, gen.sh, hub.sh, nixorcist.sh
- **Provides**: Core validation & resolution logic used everywhere
- **Depends on**: nixpkgs, nix eval, bash builtins

## Example Workflow

```bash
# Validate and expand user input
entry="eclipses"

if is_valid_token "$entry"; then
  resolved=()
  if resolve_entry_to_packages "$entry" resolved; then
    echo "Resolved to: ${resolved[@]}"
    # Output: eclipses.eclipse-java eclipses.eclipse-cpp ...
  fi
fi
```
