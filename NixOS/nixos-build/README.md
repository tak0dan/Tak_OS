
# [⚠️⚠️⚠️] DO NOT COPY AND PASTE IT BLINDLY, CREATE BACKUP FIRST[⚠️⚠️⚠️] 

# Got a backup already? Good :) 
 Allow me to introduce:




# WtfOS — Modular NixOS Configuration

This repository contains a **modular NixOS configuration** designed to be readable, maintainable, and easy to expand without turning `configuration.nix` into a giant unreadable mess.

The system follows a **layered architecture**:

1. **Core system modules** — hardware, services, users, networking  
2. **Window manager / desktop modules** — Hyprland, KDE, etc.  
3. **Package groups** — logically separated sets of software  
4. **Automated package management (Nixorcist)**  
5. **Safe rebuild utilities**

The result is a configuration that can scale without becoming chaotic.

---

# Documentation Index

Main and module documentation entry points:

- [NixOS/nixos-build/modules/README.md](NixOS/nixos-build/modules/README.md) - Core system modules overview
- [NixOS/nixos-build/nixorcist/README.md](NixOS/nixos-build/nixorcist/README.md) - Nixorcist main documentation

Nixorcist technical documentation:

- [NixOS/nixos-build/nixorcist/README_cli.md](NixOS/nixos-build/nixorcist/README_cli.md) - CLI interface
- [NixOS/nixos-build/nixorcist/README_lock.md](NixOS/nixos-build/nixorcist/README_lock.md) - Lock and transaction engine
- [NixOS/nixos-build/nixorcist/README_utils.md](NixOS/nixos-build/nixorcist/README_utils.md) - Utility and validation layer
- [NixOS/nixos-build/nixorcist/README_gen.md](NixOS/nixos-build/nixorcist/README_gen.md) - Module generation pipeline
- [NixOS/nixos-build/nixorcist/README_hub.md](NixOS/nixos-build/nixorcist/README_hub.md) - Hub regeneration flow
- [NixOS/nixos-build/nixorcist/README_rebuild.md](NixOS/nixos-build/nixorcist/README_rebuild.md) - Rebuild and staging flow

Reference-format variants:

- [NixOS/nixos-build/nixorcist/README_CLI.md](NixOS/nixos-build/nixorcist/README_CLI.md)
- [NixOS/nixos-build/nixorcist/README_LOCK.md](NixOS/nixos-build/nixorcist/README_LOCK.md)
- [NixOS/nixos-build/nixorcist/README_UTILS.md](NixOS/nixos-build/nixorcist/README_UTILS.md)
- [NixOS/nixos-build/nixorcist/README_GEN.md](NixOS/nixos-build/nixorcist/README_GEN.md)
- [NixOS/nixos-build/nixorcist/README_HUB.md](NixOS/nixos-build/nixorcist/README_HUB.md)
- [NixOS/nixos-build/nixorcist/README_REBUILD.md](NixOS/nixos-build/nixorcist/README_REBUILD.md)

---

# Design Philosophy

The configuration follows several principles.

## 1. Modularity

Each system component lives in its own module:

- networking
- audio
- bootloader
- users
- window managers
- shell configuration

This prevents a monolithic `configuration.nix`.

---

## 2. Separation of System vs Packages

The repository separates system configuration from software installation.

modules/   → system configuration packages/  → software groups

System configuration defines **how the OS works**.

Package modules define **what software gets installed**.

---

## 3. Package Groups Instead of One Giant List

Instead of writing something like:

environment.systemPackages = with pkgs; [ git firefox neovim ripgrep ];

Packages are split into modules such as:

packages/core.nix packages/development.nix packages/games.nix packages/communication.nix packages/kde.nix packages/hyprland.nix

This keeps each category logically grouped.

---

# Package Modules

Each file inside `/packages` is intended to be **independent**.

Because of this design, **some packages may appear in multiple modules**.

This is intentional.

Reasons:

- modules can be enabled independently  
- modules remain portable  
- dependencies stay local to the module

This avoids hidden dependencies between modules.

Example scenario:

hyprland module needs:

wl-clipboard grim slurp

These packages might also appear in:

core module development module

This duplication is **deliberate and harmless**.

---

# Hyprland Module

The Hyprland module is designed specifically to support the configuration from:

[https://github.com/LinuxBeginnings/Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots)

However, this configuration **does not rely on the flake** provided by that project.
Instead:

- the configuration was reworked
- converted into modular NixOS modules
- integrated into this repository structure

This avoids tight coupling to an external flake.

So for the better experience I suggest to install it next way:

It is not suggested to use the auto-installation script since it detects the distro and installs the dotfiles with flake.
Instead do: 
```
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git -b development
cd Hyprland-Dots
```
Copy them manually or use the copying script:
```
chmod +x copy.sh
./copy.sh
```
---

# Achieving the "Zen Hyprland" Setup

To replicate the intended Hyprland experience:

## 1. Clone the original dotfiles
```
git clone https://github.com/LinuxBeginnings/Hyprland-Dots
```

## Documentation Index

Core docs:

- [modules/README.md](modules/README.md) - system modules structure and purpose
- [nixorcist/README.md](nixorcist/README.md) - Nixorcist overview and usage

Nixorcist technical docs:

- [nixorcist/README_cli.md](nixorcist/README_cli.md)
- [nixorcist/README_lock.md](nixorcist/README_lock.md)
- [nixorcist/README_utils.md](nixorcist/README_utils.md)
- [nixorcist/README_gen.md](nixorcist/README_gen.md)
- [nixorcist/README_hub.md](nixorcist/README_hub.md)
- [nixorcist/README_rebuild.md](nixorcist/README_rebuild.md)

Reference variants:

- [nixorcist/README_CLI.md](nixorcist/README_CLI.md)
- [nixorcist/README_LOCK.md](nixorcist/README_LOCK.md)
- [nixorcist/README_UTILS.md](nixorcist/README_UTILS.md)
- [nixorcist/README_GEN.md](nixorcist/README_GEN.md)
- [nixorcist/README_HUB.md](nixorcist/README_HUB.md)
- [nixorcist/README_REBUILD.md](nixorcist/README_REBUILD.md)

## Nixorcist Package Management

Nixorcist is the package orchestration layer for this project.

It uses this flow:

lock file -> generated modules -> hub module -> system rebuild

This avoids manually editing large environment.systemPackages lists.

### Command Overview

Interactive flow:

```bash
nixorcist transaction
```

File import flow:

```bash
nixorcist import <file>
```

Argument wrappers routed through import:

```bash
nixorcist install <args...>      # alias: add
nixorcist delete <args...>       # aliases: remove, uninstall, selecte
nixorcist chant <args...>        # mixed add/remove in one command
```

Generation and apply:

```bash
nixorcist gen
nixorcist hub
nixorcist rebuild
```

All-in-one flow:

```bash
nixorcist all
```

### Import/Chant +/- Parser Semantics

The import parser supports mode switches:

- default mode is install
- `+` switches to install mode
- `-` switches to delete mode
- switches can appear multiple times and inline

Example:

```bash
nixorcist chant a b,c,d -e f,+a +f+g h + l - l
```

This resolves to:

- install: a, b, c, d, a, f, g, h, l
- remove: e, f, l

Removals are applied after additions, so delete has natural final priority.

### Typical Nixorcist Workflow

1. Stage package changes:

```bash
nixorcist transaction
```

2. Generate package modules:

```bash
nixorcist gen
```

3. Regenerate hub:

```bash
nixorcist hub
```

4. Apply rebuild:

```bash
nixorcist rebuild
```

Or run everything:

```bash
nixorcist all
```

## Smart Rebuild Script

The repository includes a rebuild helper at [scripts/nix-rebuild-smart.sh](scripts/nix-rebuild-smart.sh).

It improves standard rebuild handling by:

- detecting evaluation warnings
- locating renamed options
- offering guided replacement behavior
- supporting interactive confirmation mode

This helps keep the configuration maintainable across NixOS changes.

## Notes

- Prefer testing changes incrementally.
- Keep module boundaries clear.
- Keep generated files managed through Nixorcist flows.

## License

MIT
