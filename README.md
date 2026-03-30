# Tak\_OS — Modular NixOS Configuration

```
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗      ╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝ ╚══════╝
         Declarative. Modular. Yours.
```

> **Repository:** [https://github.com/tak0dan/Tak_OS](https://github.com/tak0dan/Tak_OS)  
> **License:** GNU GPLv3

---

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tak0dan/Tak_OS/main/scripts/bootstrap.sh)
```

The bootstrap script will:
- Skip cloning if `~/Tak_OS` already exists
- Ask whether to include wallpapers (~200 MB) and clone with or without `assets/Wallpapers`
- Run `scripts/install.sh` to apply the configuration

---

## Table of Contents

- [What is Tak\_OS](#what-is-tak_os)
- [Install](#install)
- [Directory Structure](#directory-structure)
- [Configuration Architecture](#configuration-architecture)
  - [The Three Layers](#the-three-layers)
  - [Feature Flags](#feature-flags)
  - [How Modules Interact](#how-modules-interact)
  - [Package Filtering](#package-filtering)
- [Quick Start](#quick-start)
- [Everyday Usage](#everyday-usage)
- [Code of Conduct](#code-of-conduct)
- [Upgrade Guide](#upgrade-guide)

---

## What is Tak\_OS

**Tak_OS** is a modular, feature-driven NixOS configuration. Instead of a
single monolithic `configuration.nix` that grows without bound, every system
concern lives in its own focused module. `configuration.nix` itself is a lean
**feature-flag manifest** — closer to a structured config file than a program.

Goals:

- **Readable at a glance** — open `configuration.nix`, flip a flag, rebuild.
- **Safely composable** — modules never implicitly depend on each other.
- **Beginner-friendly** — the standard `environment.systemPackages` section is
  right there in `configuration.nix`, same as a stock NixOS system.
- **Gradually declarative** — the Nixorcist CLI layer lets you install packages
  imperatively and promote them to config whenever you are ready.

---

## Directory Structure

```
/etc/nixos/
├── configuration.nix             ← 🧠 system entry point (feature flags + wiring)
├── hardware-configuration.nix    ← ⚙️  machine-specific hardware (auto-generated)
├── bluetooth.nix                 ← 📶 bluetooth service
│
├── modules/                      ← 🔩 NixOS system modules (one concern per file)
│   └── uwu/                      ←    optional cosmetic sub-module (NixOwOS)
│
├── packages/                     ← 📦 package groups by category
│   └── disabled/                 ←    packages kept for reference, not installed
│
├── nixorcist/                    ← 🧙 CLI-driven package orchestration layer
│   └── generated/                ←    auto-generated (never edit by hand)
│
├── scripts/                      ← 🛠️  build & deployment helpers (plain Bash)
└── assets/                       ← 🖼️  wallpapers and media
```

Sub-directory documentation:

| Path | README |
|------|--------|
| [`modules/`](modules/README.md) | Module groups, interaction model, anatomy |
| [`packages/`](packages/README.md) | Package groups, disabled list, filtering |
| [`nixorcist/`](nixorcist/README.md) | CLI tool, generated layer, observability |
| [`scripts/`](scripts/README.md) | Rebuild helpers, comment/uncomment, deploy |
| [`assets/`](assets/README.md) | Wallpapers and media |

---

## Configuration Architecture

### The Three Layers

Tak_OS separates concerns into three distinct ownership layers:

```
┌──────────────────────────────────────────────────────────┐
│  1. CANONICAL LAYER  (your hands)                        │
│     configuration.nix  +  modules/  +  packages/         │
│     • Fully declarative                                  │
│     • Manually controlled                                │
│     • Persistent across all operations                   │
├──────────────────────────────────────────────────────────┤
│  2. GENERATED LAYER  (nixorcist)                         │
│     nixorcist/generated/                                 │
│     • Machine-generated                                  │
│     • Disposable — purge with: nixorcist purge           │
│     • Never touches layer 1                              │
├──────────────────────────────────────────────────────────┤
│  3. EVALUATION LAYER  (NixOS)                            │
│     Merges all modules into a single system graph        │
│     • Deterministic                                      │
│     • Ignores duplicate package declarations safely      │
└──────────────────────────────────────────────────────────┘
```

> **Rule:** Nixorcist reads from layer 1 (for `status`, `trace`, `diff`)
> but **never writes** to it. The canonical layer is yours alone.

---

### Feature Flags

`configuration.nix` opens with a `let features = { ... };` block. Every
major system component is controlled from there:

```nix
features = {
  hyprland       = true;              # Wayland compositor + full desktop stack
  kernelParams   = "thinkpad";        # Boot-time hardware tuning profile
  gpu            = "none";            # GPU driver: "amd" | "intel" | "nvidia" | "nvidia-prime" | "none"
  kde            = true;              # Qt/KDE runtime libraries
  steam          = true;              # Steam + GameMode
  uwu            = true;              # NixOwOS branding overlay
  virtualisation = true;              # Docker + VirtualBox host
  nixorcist      = true;              # CLI package management layer
  openssh        = true;              # SSH daemon
  home-manager   = true;              # Declarative /home/ management
  home-manager-users = [ "tak_1" ];   # Users managed by Home Manager
  copilot        = true;              # GitHub Copilot CLI
};
```

Changing a flag and running `sudo nixos-smart-rebuild` is all it takes.
No hunting through module files.

#### Always-loaded modules

These are imported unconditionally, regardless of any feature flag:

| Module | Purpose |
|--------|---------|
| `hardware-configuration.nix` | Machine hardware |
| `modules/bootloader.nix` | GRUB / systemd-boot |
| `modules/gpu.nix` | GPU profile dispatcher |
| `modules/sddm.nix` | Display manager |
| `modules/locale.nix` | Timezone, locale, keyboard |
| `modules/networking.nix` | NetworkManager, hostname |
| `modules/users.nix` | System user accounts |
| `modules/audio.nix` | PipeWire |
| `modules/hardware-graphics.nix` | Mesa / VA-API |
| `modules/keyring.nix` | GNOME Keyring |
| `modules/environment.nix` | Session env vars |
| `modules/zsh.nix` | Zsh shell |
| `modules/nix-settings.nix` | Nix daemon + nixpkgs config |
| `modules/fonts-base.nix` | Minimal font set |
| `modules/system-packages.nix` | Package assembly hub |
| `modules/hm-local-bootstrap.nix` | `~/.hm-local` scaffold |
| `modules/copilot-cli.nix` | Copilot CLI (guarded internally) |

#### Conditionally loaded modules

| Condition | Modules loaded |
|-----------|---------------|
| `features.hyprland = true` | `window-managers`, `portals`, `quickshell`, `fonts`, `theme`, `overlays`, `nh`, `vm-guest-services`, `local-hardware-clock` |
| `features.home-manager = true` | `<home-manager/nixos>`, `hm-users` |
| `features.uwu = true` | `uwu/nixowos.nix` |
| `features.virtualisation = true` | `virtualbox.nix` (+ Docker) |
| `features.kde = true` | activates Qt/KDE inside `kde.nix` |
| `features.steam = true` | activates Steam inside `gaming.nix` |
| `features.openssh = true` | activates SSH inside `openssh.nix` |

---

### How Modules Interact

Tak_OS modules are **share-nothing by default**. A module file declares NixOS
options and sets `config.*` values; it never calls functions from a sibling
module. Cross-module communication happens exclusively through the NixOS
option system.

There is one explicit shared channel: **`_module.args`**.

```nix
# configuration.nix
_module.args = { inherit features filterPkgs; };
```

This injects two values into every imported module's function arguments:

| Name | Type | Purpose |
|------|------|---------|
| `features` | attrset | The full feature-flag set from the `let` block |
| `filterPkgs` | `[pkg] → [pkg]` | Removes disabled packages from any list |

A module that needs them declares them in its argument list:

```nix
# modules/gaming.nix
{ pkgs, features, filterPkgs, ... }:
{
  programs.steam.enable = features.steam;
  environment.systemPackages = filterPkgs (with pkgs; [ gamemode mangohud ]);
}
```

Modules that do not need these values simply omit them — they receive
`{ config, pkgs, lib, ... }` as usual. No boilerplate required.

NixOS evaluates all modules in a single pass and merges their `config`
outputs. There is no explicit load order. The import list in
`configuration.nix` is ordered for **human readability**, not for evaluation
semantics — reordering it has no effect on the final system.

---

### Package Filtering

Two mechanisms let you disable packages without editing every file that
mentions them:

**1. `packages/disabled/disabled-packages.nix`** — managed by CLI tools:

```bash
nixos-comment   <pkg>    # adds pkg to the disabled list
nixos-uncomment <pkg>    # removes pkg from the disabled list
```

**2. `kool.disabledPackages` in `configuration.nix`** — quick inline overrides:

```nix
kool.disabledPackages = [
  "discord"
  "telegram-desktop"
];
```

Both lists feed into `filterPkgs`, which every module applies when assembling
its package list via `modules/system-packages.nix`. A package appearing in
either list is excluded from all groups everywhere in the system.

See [`packages/README.md`](packages/README.md) for the full picture.

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/tak0dan/Tak_OS.git /etc/nixos

# 2. Review and adjust feature flags
sudoedit /etc/nixos/configuration.nix

# 3. Set your locale, hostname, and username
sudoedit /etc/nixos/modules/locale.nix
sudoedit /etc/nixos/modules/networking.nix
sudoedit /etc/nixos/modules/users.nix

# 4. Bootstrap nixorcist
sudo nixorcist gen
sudo nixorcist hub

# 5. Rebuild
sudo nixos-rebuild switch
```

### Add your own packages

**Inline** (works exactly like a stock NixOS system):

```nix
# in configuration.nix — already present, just fill it in
environment.systemPackages = with pkgs; [
  vim
  wget
  htop
];
```

**Via nixorcist** (CLI-driven, reversible):

```bash
sudo nixorcist install firefox
sudo nixorcist all
```

---

## Everyday Usage

```bash
# Smart rebuild with automatic error resolution
sudo nixos-smart-rebuild

# Full nixorcist pipeline (gen → hub → rebuild)
sudo nixorcist all

# Check what is installed and where
sudo nixorcist status

# Find where a specific package comes from
sudo nixorcist trace firefox

# See what nixorcist manages vs what is in config
sudo nixorcist diff

# Update channels + index + rebuild
sudo nix-channel --update && sudo nixorcist refresh-index && sudo nixos-rebuild switch
```

---

## Code of Conduct

These rules protect the integrity and readability of the configuration.

### Architecture

1. **The canonical layer is the single source of truth.**
   `configuration.nix`, `modules/`, and `packages/` are your responsibility.
   Nixorcist may never write to these paths.

2. **One concern per module.**
   `audio.nix` handles audio. `networking.nix` handles networking.
   Do not combine unrelated concerns in one file.

3. **Modules are share-nothing.**
   A module must never `import` a sibling module or call its functions directly.
   All cross-module communication goes through the NixOS option system
   or `_module.args`.

4. **Package lists belong in `packages/`, not `modules/`.**
   Modules configure services and options. The `packages/` tree defines
   what software is installed.

5. **Never edit `nixorcist/generated/` by hand.**
   Those files are machine-owned. Manual edits will be overwritten.

### Safety

6. **Test before switching.**
   Run `sudo nixos-rebuild dry-activate` before `switch` when making
   structural changes (new modules, renamed options, changed imports).

7. **Back up before deploying.**
   `scripts/deploy-to-etc-nixos.sh` creates a backup automatically.
   Do not skip or suppress it.

8. **Do not store secrets in this repo.**
   No passwords, API keys, or private keys — not even in comments.
   Use `sops-nix`, `agenix`, or another secrets manager instead.

9. **Hardware-specific modules stay separate.**
   GPU drivers, kernel params, and machine-specific tuning must never be
   merged into generic modules. Hardware specificity belongs in named files.

### Style

10. **Preserve the guiding comments in `configuration.nix`.**
    The comment blocks (`# → modules/foo.nix`) are navigation aids.
    Do not remove or shorten them when editing the file.

11. **Every new module carries the attribution header:**

```nix
# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
```

12. **Keep commits atomic and described.**
    One logical change per commit. Push to `main`.

---

## Upgrade Guide

```bash
# 1. Update channels
sudo nix-channel --update

# 2. Refresh nixorcist package index
sudo nixorcist refresh-index

# 3. Rebuild (smart mode handles renamed options automatically)
sudo nixos-smart-rebuild
```

If an option was renamed across NixOS releases, `nixos-smart-rebuild` detects
it and offers an interactive replacement prompt. The rename table lives in
`scripts/nix-rebuild-smart.sh`.

---

*Tak_OS — declarative, modular, yours.*  
*© 2026 tak0dan · GNU GPLv3 · [https://github.com/tak0dan/Tak_OS](https://github.com/tak0dan/Tak_OS)*
