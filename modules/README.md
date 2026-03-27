# modules/ — System-Level NixOS Modules

> Part of [Tak_OS](https://github.com/tak0dan/Tak_OS) · parent: [`/etc/nixos/`](../README.md)

---

```
modules/
├── gpu.nix                    ← GPU profile selector (driver + kernel-params)
├── amd-drivers.nix            ← AMD GPU userspace driver
├── nvidia-drivers.nix         ← Nvidia standalone driver
├── nvidia-prime-drivers.nix   ← Nvidia PRIME hybrid driver
├── intel-drivers.nix          ← Intel GPU driver
├── hardware-graphics.nix      ← OpenGL / hardware acceleration
├── kernel-params.nix          ← Active kernel params (symlink/import target)
├── kernel-params-amd.nix      ← Kernel params for AMD systems
├── kernel-params-nvidia.nix   ← Kernel params for Nvidia systems
├── kernel-params-generic.nix  ← Generic/Intel kernel params
├── kernel-params-thinkpad.nix ← ThinkPad T-series specific params
├── bootloader.nix             ← GRUB / systemd-boot configuration
├── grub-theme.nix             ← GRUB visual theme
├── networking.nix             ← NetworkManager, hostname, WiFi
├── openssh.nix                ← OpenSSH server
├── bluetooth.nix              ← Bluetooth stack (blueman)
├── audio.nix                  ← PipeWire / PulseAudio
├── locale.nix                 ← Timezone, locale, keyboard
├── local-hardware-clock.nix   ← Hardware clock (UTC vs localtime)
├── users.nix                  ← System user accounts
├── hm-users.nix               ← Home Manager user wiring
├── hm-home-scaffold.nix       ← Home Manager base scaffold
├── hm-local-bootstrap.nix     ← Local Home Manager bootstrap
├── window-managers.nix        ← WM/DE enable flags
├── kde.nix                    ← KDE Plasma session
├── sddm.nix                   ← SDDM display manager
├── portals.nix                ← XDG desktop portals (Wayland)
├── keyring.nix                ← GNOME Keyring / libsecret
├── theme.nix                  ← GTK / Qt global theme
├── fonts.nix                  ← Full font set
├── fonts-base.nix             ← Minimal base fonts
├── environment.nix            ← Session env vars
├── nix-settings.nix           ← Nix daemon settings, flakes, substituters
├── nix-ld.nix                 ← nix-ld (run unpackaged binaries)
├── overlays.nix               ← nixpkgs overlays
├── system-packages.nix        ← Base system-wide packages
├── all-packages.nix           ← Master import hub for all package modules
├── gaming.nix                 ← Steam, Lutris, MangoHud, gamemode
├── virtualbox.nix             ← VirtualBox host
├── vm-guest-services.nix      ← QEMU/VMware guest services
├── nixvim.nix                 ← NixVim (Neovim via Nix)
├── quickshell.nix             ← Quickshell bar/widget
├── nh.nix                     ← nh (NixOS helper CLI)
├── copilot-cli.nix            ← GitHub Copilot CLI integration
├── rebuild-error-hook.nix     ← Post-rebuild error notification hook
└── uwu/                       ← Optional cosmetic sub-module
    ├── nixowos.nix            ← NixOwOS branding overlay
    └── create_nixowos_logo.patch
```

---

## Description

Each file in `modules/` is a self-contained NixOS module — a Nix expression
returning a set of `config` attributes. They are imported from `configuration.nix`
and never depend on each other implicitly (all cross-module communication goes
through `config` options).

### GPU Profile System

The GPU subsystem uses two orthogonal option sets defined in `gpu.nix`:

| Option | What it controls |
|--------|-----------------|
| `gpu.kernelParams` | Boot-level hardware tuning (`boot.*`, `cpu.*`) |
| `gpu.driver` | Userspace driver (`hardware.nvidia.*`, `videoDrivers`) |

Set both in `configuration.nix`:

```nix
gpu.kernelParams = "nvidia";   # "amd" | "nvidia" | "generic" | "thinkpad"
gpu.driver       = "nvidia";   # "amd" | "nvidia" | "nvidia-prime" | "intel" | "none"
```

### Kernel Parameters

Choose the file that matches your hardware and import it (or use the `gpu.nix`
selector to do it automatically):

| File | Hardware |
|------|----------|
| `kernel-params-amd.nix` | AMD CPU/GPU |
| `kernel-params-nvidia.nix` | Nvidia GPU |
| `kernel-params-generic.nix` | Intel / generic |
| `kernel-params-thinkpad.nix` | ThinkPad T-series |

> **Note:** Prefer crafting kernel params specific to your hardware rather than
> using a generic preset blindly. Profile files are starting points.

### Home Manager

Three files cooperate for Home Manager support:

- `hm-home-scaffold.nix` — base HM configuration skeleton
- `hm-users.nix` — declares which system users get HM configs
- `hm-local-bootstrap.nix` — bootstraps HM from the local repo path

### uwu/ Sub-module

`uwu/nixowos.nix` applies optional cosmetic branding (custom `os-release` and
fastfetch ASCII logo). Enabled/disabled via a feature flag in `configuration.nix`:

```nix
features.uwu = true;   # or false to remove entirely
```

---

## Code of Conduct

- Each module must be independently importable — no hidden dependencies between siblings.
- Hardware-specific modules (drivers, kernel params) stay separate from service modules.
- Do not write package lists into `modules/` — those belong in `packages/`.
- Generated files (nixorcist output) must not be placed here.
- All module headers must carry the Tak_OS attribution block:

```nix
# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
```

---

## Upgrade Guide

When adding a new module:

```bash
# 1. Create the file with the attribution header
# 2. Add it to the imports list in configuration.nix
# 3. Dry-activate first
sudo nixos-rebuild dry-activate

# 4. Apply
sudo nixos-rebuild switch
```

When a NixOS option is renamed across channels:

```bash
# Use the smart rebuild script — it detects renamed options automatically
sudo bash /etc/nixos/scripts/nix-rebuild-smart.sh
```
