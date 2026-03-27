# rebuild.sh — Smart Rebuild Pipeline

Handles NixOS system rebuilds with an interactive error resolver that catches
deprecated or missing attributes and prompts the user to pick a replacement —
no build hanging, no panic.

---

## Entry Point

```bash
run_rebuild [--no-snapshot]
```

Called by `nixorcist rebuild` and the `r` option in the TUI review screen.

---

## Retry Loop

`run_rebuild` attempts `nixos-rebuild switch` up to **5 times**.  After each
failure it calls `_rebuild_resolve_errors` before retrying.

```
run_rebuild()
  └─ cleanup_orphan_modules()          # remove stale .nix files
  └─ generate_modules()                # regenerate from lock
  └─ regenerate_hub()                  # rebuild all-packages.nix
  └─ create staging snapshot
  └─ [loop up to 5×]
        nix-build → success → done
                  → fail   → _rebuild_resolve_errors() → retry
```

---

## _rebuild_resolve_errors

Parses the build log for:

- `attribute 'X' missing`
- `undefined variable 'X'`
- Hard-coded patterns: `Python 2 interpreter has been removed`, `Python2 is end-of-life`

For each found attribute calls `_resolve_missing_attr`.

---

## _resolve_missing_attr

Builds a candidate list in two stages:

1. **Well-known rename table** (instant, no I/O):

   | Broken | Replacement |
   |--------|-------------|
   | `python` | `python3` |
   | `python2` | `python27` |
   | `nodejs` | `nodejs_22` |
   | `ruby` | `ruby_3_3` |
   | `java` / `openjdk` | `jdk21` |
   | `gcc` | `gcc14` |
   | `clang` | `clang_18` |
   | `mariadb` | `mariadb_1011` |
   | `postgresql` | `postgresql_16` |

2. **Index-based leaf-name search** — reads `cache/nixpkgs-index.txt`, ranks
   by proximity of the **leaf** (last dot-component of the attr path):

   | Score | Condition |
   |-------|-----------|
   | 0 | leaf == query exactly |
   | 1 | leaf starts with query |
   | 2 | leaf ends with query |
   | 3 | query is a whole word in leaf |

   Results are capped at 12, sorted by score then alphabetically.
   Descriptions are shown inline from the index.

If the index is missing, only the well-known table is used and a note is shown
to run `nixorcist refresh-index`.

The user picks a number, or `0` to remove the package from the lock entirely.
On selection: lock is updated → modules regenerated → hub rebuilt → retry.

---

## Lock helpers

```bash
_lock_remove_pkg  PKG        # Remove one entry from the lock
_lock_replace_pkg OLD NEW    # Replace one entry (deduplicates if NEW already present)
```

Both call `read_lock_entries` / `write_lock_entries` from lock.sh.

---

## Orphan cleanup

`cleanup_orphan_modules()` (from gen.sh) is called at the top of every rebuild.
It deletes any `.nix` file in `generated/.modules/` that has no corresponding
entry in the lock — prevents stale modules from causing build failures after
manual lock edits or failed transactions.
