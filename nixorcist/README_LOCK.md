# lock.sh — Transaction Engine & Pipeline

Manages the package lock file and all transaction operations.
All user-facing commands ultimately call functions in this module.

---

## Core Concept

The lock file (`generated/.lock`) is a plain-text list, one package attr per line.
Everything in `generated/` is derived from it.  The lock is the single source of truth.

---

## Transaction State

```bash
TX_ADD=()      # packages staged for installation
TX_REMOVE=()   # packages staged for removal
TX_LOCK=()     # current lock contents at session start
```

`transaction_init` must be called once per session.  The TUI calls it at startup.

---

## nixorcist_pipeline — The 4-Phase Core

All package changes go through this function in strict order:

```
Phase 1: remove_staged_modules TX_REMOVE   # delete .nix files for removed pkgs
Phase 2: generate modules for TX_ADD       # create .nix for new pkgs
Phase 3: regenerate_hub                    # rebuild all-packages.nix
Phase 4: transaction_apply                 # write final lock
```

Ordering is critical: if a deprecated package's `.nix` still exists in the hub
when nix-build runs, evaluation fails.  Phase 1 deletes it first.

---

## import_from_file FILE

Reads a file line by line.  Tokens beginning with `+` go to `TX_ADD`, `-` to
`TX_REMOVE`.  Default mode is install (no prefix = `+`).

Blank lines and `#` comment lines are skipped.

When a package is not found in the index, `handle_missing_package` is called:
- shows ranked candidates by leaf-name proximity (capped at 12)
- user picks by number, or `0` to skip, or `b` for fzf browse
- uses file descriptor 3 for token stream so `read` inside the handler
  gets real stdin (not the next token)

After staging, prompts:
```
Apply transaction? [Y/n/r]   y=apply  n=cancel  r=apply+rebuild
```

---

## chant_from_args TOKEN…

Writes tokens to a temp file and calls `import_from_file`.
`+` / `-` prefix semantics are identical to file import.

```bash
nixorcist chant -python +python3 firefox
# Removes python, adds python3 and firefox
```

---

## install_from_args PKG…

Prefixes every arg with `+` and calls `chant_from_args`.

## delete_from_args PKG…

Prefixes every arg with `-` and calls `chant_from_args`.

---

## handle_missing_package PKG

Called when a token is not found in the validation cache or index.

```
Package Not Found: pip
────────────────────────────────────
  Closest matches:

   1) python313Packages.pip     Python package installer
   2) python314Packages.pip     Python package installer
   3) pipx                      Install and run Python applications
   4) pipewire                  Multimedia processing server
  ...
   0) Skip

  Choose [0-N]:
```

---

## Lock I/O

```bash
read_lock_entries           # returns current lock as array (stdout)
write_lock_entries ARRNAME  # writes nameref array to lock file
transaction_apply           # merges TX_ADD/TX_REMOVE into lock
```
