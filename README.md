# Tak_OS — Modular NixOS Configuration

> **Repository:** [https://github.com/tak0dan/Tak_OS](https://github.com/tak0dan/Tak_OS)

---

```
/etc/nixos/                       ← you are here (root)
├── configuration.nix             ← system entry point
├── hardware-configuration.nix    ← machine-specific hardware
├── bluetooth.nix                 ← bluetooth service
├── modules/                      ← system-level NixOS modules
│   └── uwu/                      ← optional cosmetic sub-module
├── packages/                     ← package groups by category
├── nixorcist/                    ← declarative package manager
│   └── generated/                ← auto-generated (do not edit)
├── scripts/                      ← build & deployment helpers
└── assets/                       ← wallpapers and media
```

---

## What is Tak_OS

Tak_OS is a **modular, user-friendly NixOS configuration** built around a clean
layered architecture. Instead of one monolithic `configuration.nix`, every
system concern lives in its own focused module. The result is a configuration
that stays readable and maintainable as it grows.

**Layers (top to bottom):**

1. `configuration.nix` — imports everything, sets high-level options
2. `modules/` — hardware, services, desktop, shell, user accounts
3. `packages/` — software groups installed per category
4. `nixorcist/` — declarative package transaction engine
5. `scripts/` — rebuild helpers and deployment utilities

---

## Quick Start

### First-time setup

```bash
# Clone the repo
git clone https://github.com/tak0dan/Tak_OS.git /etc/nixos

# Bootstrap nixorcist's generated hub
sudo nixorcist gen
sudo nixorcist hub

# Rebuild
sudo nixos-rebuild switch
```

### Everyday rebuild

```bash
# Smart rebuild with automatic error resolution
sudo bash /etc/nixos/scripts/nix-rebuild-smart.sh

# Or via the nixorcist all-in-one pipeline
sudo nixorcist all
```

---

## Directory Guide

| Path | Purpose |
|------|---------|
| [`modules/`](modules/README.md) | NixOS system modules (hardware, services, DE) |
| [`packages/`](packages/README.md) | Package groups, one file per category |
| [`nixorcist/`](nixorcist/README.md) | Package management TUI and transaction engine |
| [`scripts/`](scripts/README.md) | Rebuild, comment/uncomment, and deploy helpers |
| [`assets/`](assets/README.md) | Wallpapers and media used by the configuration |

---

## Code of Conduct

- **Never** edit files inside `nixorcist/generated/` by hand — they are managed by `nixorcist`.
- Keep module boundaries clear. One concern per file.
- Test changes with `nixos-rebuild dry-activate` before `switch`.
- Run `sudo nixorcist all` when adding or removing packages instead of editing package lists manually.
- Commit frequently; push to `main` on `https://github.com/tak0dan/Tak_OS`.

---

## Upgrade Guide

```bash
# Update the nixpkgs channel
sudo nix-channel --update

# Refresh the nixorcist package index
sudo nixorcist refresh-index

# Rebuild
sudo nixos-rebuild switch
```

---

## License

MIT — see [LICENSE](LICENSE) if present, otherwise governed by the repository default.

*Tak_OS — declarative, modular, yours.*
