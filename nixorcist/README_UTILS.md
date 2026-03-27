# utils.sh — Validation Cache & Package Search

Provides fast package validation (with per-session cache) and ranked
proximity search against the nixpkgs index.

---

## Validation Cache

Location: `cache/pkg-validation.cache`

Format:
```
# rev:a3f2b1c4d5e6f7a8          ← nixpkgs store-path hash (16 chars)
firefox=derivation
python=skip
python3Packages.pip=derivation
```

The rev line is compared against the current nixpkgs store path on every
startup.  If the channel was updated, the whole cache is wiped and rebuilt.

### is_derivation_cached PKG

Returns `derivation` or `skip`, or falls through to `is_derivation` on a
cache miss (then writes the result to cache).

### is_derivation PKG

Calls `nix eval nixpkgs#PKG --apply builtins.typeOf` and checks for
`"derivation"`.  This is the slow path (~0.3–1s per package); only called
on cache misses.

### validation_cache_evict PKG

Removes one entry from the cache.  Called automatically when a package
causes a build failure, so the next rebuild re-validates it.

---

## Package Search

### find_similar_packages QUERY

Searches `cache/nixpkgs-index.txt` by **leaf-name proximity**.

The index format is `attr.path|Short description`, one per line.
The leaf is the last dot-component of the attribute path.

Ranking:

| Score | Condition |
|-------|-----------|
| 0 | leaf == query (exact) |
| 1 | leaf starts with query |
| 2 | leaf ends with query |
| 3 | query is a whole word in leaf (hyphen/underscore boundary) |

Anything that doesn't match any score is silently skipped — no
"substring anywhere in the full path" noise.

Results: up to 12, sorted by score then alphabetically, printed one per line.

### get_index_file

Returns the path to the nixpkgs index file (`cache/nixpkgs-index.txt`).

---

## Token Validation

### is_valid_token STR

Checks that a token contains only safe characters (alphanumeric, `.`, `-`, `_`).
Used by `import_from_file` before processing any user input.

### resolve_entry_to_packages ENTRY OUT_ARRAY

Expands attribute sets to their constituent packages.

```bash
resolve_entry_to_packages "eclipses" pkgs_out
# pkgs_out = (eclipses.eclipse-java eclipses.eclipse-cpp eclipses.eclipse-sdk ...)
```

If the entry is a plain derivation it is returned as-is.
If it is an attribute set, all children that are derivations are enumerated.
