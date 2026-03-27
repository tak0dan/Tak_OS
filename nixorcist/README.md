# Nixorcist — The Declarative NixOS Package Sorcerer

```
         j        '-,
         '-.        ',
           |          \
           '-,         \
              j         .
              |          .
    _....._   |       _. :
  .`       ''-L     .-   |
.`             '.  /  .` |
:                 'Y ,`  /.\   ███╗   ██╗██╗██╗  ██╗ ██████╗ ██████╗  ██████╗██╗███████╗████████╗
|                  / |  :  .\  ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔══██╗██╔════╝██║██╔════╝╚══██╔══╝
|                /`  : "    ./ ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██████╔╝██║     ██║███████╗   ██║
|      ..,___..-'     '.    /  ██║╚██╗██║██║ ██╔██╗ ██║   ██║██╔══██╗██║     ██║╚════██║   ██║
'     _....   ___      .`  /   ██║ ╚████║██║██╔╝ ██╗╚██████╔╝██║  ██║╚██████╗██║███████║   ██║
      | | | \_/ |\    /    '-. ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝╚══════╝   ╚═╝
\     |'| ''    | '--`       |          The Declarative NixOS Package Sorcerer
 \    | .\      |            |
..:...`pd-Y     |..__.....-.-|
          |     \_.T.L.L_|_|_|
          |      \''-T.L_|_|_/
           \                |
            '-._             \
                '.._         :
                    ''--...__/
```

Nixorcist is a modular Bash framework for managing NixOS packages declaratively
through an interactive TUI (text user interface) — think `nmtui`, but for packages.
It wraps the NixOS rebuild cycle in a transaction engine that lets you stage
installs, removals, and bulk imports, preview changes, then apply with a single
keystroke — and automatically resolves deprecated packages at rebuild time.

---

## Features

- **Arrow-key TUI** — nmtui-style navigation with submenus, back/forward, cached state
- **Transaction engine** — stage adds/removes/chants, preview, then commit atomically
- **Smart rebuild** — retry loop that catches missing/deprecated attributes and prompts
  for interactive replacement using ranked index search (no `nix search` slowness)
- **Import system** — `+pkg` / `-pkg` syntax in files or args; `chant -python +python3`
  removes the old module *before* adding the new one to prevent build failures
- **Validation cache** — packages proven valid are cached; first run is slow, all
  subsequent runs are instant; cache is auto-invalidated on nixpkgs channel change
- **Ranked package search** — leaf-name proximity scoring (exact > prefix > suffix >
  word-boundary) against a local index; cap 12, descriptions inline
- **Attribute set expansion** — `eclipses` expands to every eclipse variant automatically
- **Orphan cleanup** — stale `.nix` modules are purged before each rebuild
- **Modular architecture** — each concern in its own sourced lib

---

## Quick Start

```bash
# Open the interactive TUI (default when no args given)
sudo nixorcist

# Install packages from the TUI or directly:
sudo nixorcist install firefox git helix

# Remove a package:
sudo nixorcist delete vim

# Mixed install+remove in one transaction:
sudo nixorcist chant -python +python3 +nodejs

# Import from a file (one package per line, +/- prefixes supported):
sudo nixorcist import packages.txt

# Rebuild the system:
sudo nixorcist rebuild
```

For a full installation guide → **[INSTALL.md](INSTALL.md)**

---

## TUI Overview

`sudo nixorcist` (no arguments) opens the interactive TUI.

```
┌─ Nixorcist ──────────────────────────────────────────────────┐
│                                                              │
│   ❯ Install packages                                         │
│     Remove packages                                          │
│     Chant  (+add / -remove in one transaction)               │
│     Import from file                                         │
│     ──────────────────────────────────────────               │
│     Review & Cast  (preview all staged changes)              │
│     ──────────────────────────────────────────               │
│     Fetch index                                              │
│     Generate modules only                                    │
│     View status                                              │
│     ──────────────────────────────────────────               │
│     Exit                                                     │
│                                                              │
│  ↑↓ navigate · Enter select · Esc/q back                     │
└──────────────────────────────────────────────────────────────┘
```

All changes are staged in memory. Navigate freely between menus — nothing is
written until you reach **Review & Cast** and confirm with `r` (apply + rebuild)
or `y` (apply without rebuild).

---

## Command Reference

```
sudo nixorcist [command] [args]
```

| Command | Aliases | Description |
|---------|---------|-------------|
| *(no args)* | `tui` | Open interactive TUI |
| `install PKG…` | `add`, `download` | Install one or more packages |
| `delete PKG…` | `remove`, `uninstall` | Remove one or more packages |
| `chant TOKEN…` | `cast` | Mixed +/- install/remove in one transaction |
| `import FILE` | | Import packages from a file |
| `gen` | | Generate Nix modules from lock file |
| `hub` | | Regenerate the import hub (`all-packages.nix`) |
| `rebuild` | | Run NixOS rebuild with smart error resolver |
| `all` | | Full pipeline: transaction → gen → hub → rebuild |
| `refresh-index` | `refresh`, `index` | Re-fetch the nixpkgs package index |
| `transaction` | | Legacy interactive transaction menu |
| `purge` | | Remove all modules and clear the lock |
| `help` | `-h`, `--help` | Show usage |

### Chant / Import syntax

`+` switches to install mode, `-` switches to remove mode.  
Switches can appear inline or standalone.  Removes always execute before adds.

```bash
sudo nixorcist chant -python +python3          # remove python, add python3
sudo nixorcist chant firefox +git -vim +helix  # firefox & git added, vim removed, helix added
sudo nixorcist import packages.txt             # file: one token per line
```

File format for `import`:
```
# comment lines are ignored
+firefox
+git
-vim
python3
nodejs
```

---

## Architecture

```
nixorcist/
├── nixorcist.sh              # Entry point — command dispatcher
├── lib/
│   ├── cli.sh                # TUI engine + all visual output
│   ├── lock.sh               # Transaction state, pipeline, import/chant/install/delete
│   ├── utils.sh              # Validation cache, package search, derivation check
│   ├── gen.sh                # Module generation + orphan cleanup
│   ├── hub.sh                # Hub file (all-packages.nix) aggregation
│   ├── rebuild.sh            # Rebuild pipeline + smart error resolver
│   ├── index.sh              # nixpkgs index fetch and management
│   ├── transaction.sh        # Low-level transaction helpers
│   └── dirs.sh               # Directory + path exports
├── generated/                # Auto-generated (gitignored except .lock)
│   ├── .modules/             # One .nix per installed package
│   ├── all-packages.nix      # Hub: imports every module
│   └── .lock                 # Package lock (plain text, one per line)
├── cache/                    # Performance cache (gitignored)
│   ├── nixpkgs-index.txt     # ~7MB flat index  attr|description
│   └── pkg-validation.cache  # Derivation validation cache
└── assets/
    └── logo.txt              # ASCII banner
```

### Pipeline ordering (why it matters)

When replacing deprecated packages, Nixorcist **deletes the old `.nix` module
first**, then generates the new one, then rebuilds.  This prevents `python.nix`
from being present in the hub when nix-build runs, which would cause an
`attribute 'python' missing` error.

```
chant -python +python3
       │
       ▼
  Phase 1: delete generated/.modules/python.nix
  Phase 2: generate generated/.modules/python3.nix
  Phase 3: regenerate all-packages.nix hub
  Phase 4: update .lock
       │
       ▼
  rebuild → if error → interactive resolver → retry (up to 5×)
```

### Validation cache

Located at `cache/pkg-validation.cache`.  First line is a rev stamp of the
current nixpkgs store path; if the channel changes the entire cache is wiped.
Per-entry eviction happens automatically when a package causes a build failure.

---

## Smart Rebuild

`nixorcist rebuild` runs a retry loop (up to 5 attempts).  After each failure it:

1. Parses the nix-build log for `attribute 'X' missing` / `undefined variable 'X'`
2. Checks a well-known rename table (python→python3, nodejs→nodejs_22, etc.)
3. Searches the local nixpkgs index by **leaf-name proximity**:
   - Score 0 — leaf == query exactly
   - Score 1 — leaf starts with query
   - Score 2 — leaf ends with query
   - Score 3 — query is a whole word in leaf
4. Presents a numbered list with descriptions
5. On selection: replaces in lock + regenerates modules + retries

No `nix search` is ever called — all results come from the local index.

---

## NixOS Integration

In your `configuration.nix`:

```nix
imports = [
  ./hardware-configuration.nix
  ./nixorcist/generated/all-packages.nix   # ← add this line
];
```

Nixorcist manages everything inside `nixorcist/generated/`.  You never edit those
files by hand.  All other parts of your NixOS config are untouched.

---

## Documentation

| File | Contents |
|------|----------|
| [INSTALL.md](INSTALL.md) | Step-by-step installation into any NixOS config |
| [README_cli.md](README_cli.md) | TUI engine and visual output API |
| [README_lock.md](README_lock.md) | Transaction engine and pipeline |
| [README_gen.md](README_gen.md) | Module generation |
| [README_hub.md](README_hub.md) | Hub aggregation |
| [README_REBUILD.md](README_REBUILD.md) | Smart rebuild + error resolver |
| [README_utils.md](README_utils.md) | Validation cache + package search |

---

## Requirements

| Dependency | Notes |
|------------|-------|
| NixOS 24.05+ | Any recent channel |
| Bash 4.4+ | Associative arrays, `nameref` |
| `fzf` | Interactive package browser |
| `nix` with flakes | `nix-command flakes` experimental features |
| `awk`, `sed`, `grep` | Standard GNU/POSIX |

Enable flakes in your config if not already:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

---

## License

MIT — see [LICENSE](LICENSE)

---

*Nixorcist — declarative package management through the arcane arts of Nix*
