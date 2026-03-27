# modules/ — NixOS System Modules

> Part of [Tak\_OS](https://github.com/tak0dan/Tak_OS) · parent: [`/etc/nixos/`](../README.md)  
> **License:** GNU GPLv3

---

## Table of Contents

- [Directory Map](#directory-map)
- [Module Groups](#module-groups)
  - [Hardware & Boot](#hardware--boot)
  - [Display & Login](#display--login)
  - [Core System](#core-system)
  - [Shell & Environment](#shell--environment)
  - [Feature Modules](#feature-modules)
  - [Home Manager](#home-manager)
  - [Nixorcist Integration](#nixorcist-integration)
  - [Optional / Cosmetic](#optional--cosmetic)
- [How Modules Interact](#how-modules-interact)
  - [\_module.args — Shared Channel](#_moduleargs--shared-channel)
  - [The features Attrset](#the-features-attrset)
  - [The filterPkgs Function](#the-filterpkgs-function)
  - [The options / config Split](#the-options--config-split)
- [GPU Subsystem](#gpu-subsystem)
- [Home Manager Subsystem](#home-manager-subsystem)
- [Writing a New Module](#writing-a-new-module)
- [Code of Conduct](#code-of-conduct)

---

## Directory Map

```
modules/
│
│── Hardware & Boot ──────────────────────────────────────────
├── gpu.nix                    ← GPU profile dispatcher (reads features.kernelParams + features.gpu)
├── amd-drivers.nix            ← AMD GPU userspace driver
├── nvidia-drivers.nix         ← Nvidia standalone driver
├── nvidia-prime-drivers.nix   ← Nvidia PRIME hybrid driver
├── intel-drivers.nix          ← Intel GPU driver
├── hardware-graphics.nix      ← Mesa / VA-API / 32-bit OpenGL libs (always loaded)
├── kernel-params.nix          ← Active kernel params (managed by gpu.nix)
├── kernel-params-amd.nix      ← Kernel params for AMD systems
├── kernel-params-nvidia.nix   ← Kernel params for Nvidia systems
├── kernel-params-generic.nix  ← Generic / Intel kernel params
├── kernel-params-thinkpad.nix ← ThinkPad T-series specific params
├── bootloader.nix             ← GRUB / systemd-boot configuration
├── grub-theme.nix             ← GRUB visual theme
│
│── Display & Login ──────────────────────────────────────────
├── sddm.nix                   ← SDDM display manager + login background
│
│── Core System ──────────────────────────────────────────────
├── networking.nix             ← NetworkManager, hostname, WiFi
├── locale.nix                 ← Timezone, locale, keyboard layout
├── local-hardware-clock.nix   ← Hardware clock mode (UTC vs localtime)
├── users.nix                  ← System user accounts
├── audio.nix                  ← PipeWire (ALSA + PulseAudio compat + rtkit)
├── keyring.nix                ← GNOME Keyring / libsecret (always loaded)
├── nix-settings.nix           ← Nix daemon settings, flakes, substituters
├── nix-ld.nix                 ← nix-ld (run unpackaged binaries)
│
│── Shell & Environment ──────────────────────────────────────
├── environment.nix            ← Session environment variables
├── zsh.nix                    ← Zsh shell + completions
├── rebuild-error-hook.nix     ← Post-rebuild error notification hook
│
│── Feature Modules ──────────────────────────────────────────
├── kde.nix                    ← Qt/KDE runtime (guarded by features.kde)
├── gaming.nix                 ← Steam + GameMode (guarded by features.steam)
├── openssh.nix                ← SSH daemon (guarded by features.openssh)
├── virtualbox.nix             ← VirtualBox host + Docker (guarded by features.virtualisation)
├── window-managers.nix        ← Hyprland, bspwm, i3, xkb (loaded when features.hyprland)
├── portals.nix                ← XDG portals: screen share, file picker
├── quickshell.nix             ← Wayland shell widget layer
├── fonts.nix                  ← Full Nerd Font / CJK / icon font set
├── fonts-base.nix             ← Minimal base font set (always loaded)
├── theme.nix                  ← GTK Adwaita-dark, cursors, dconf defaults
├── overlays.nix               ← nixpkgs patches (waybar-weather, cmake fixes)
├── nh.nix                     ← nh Nix helper + nix-output-monitor + nvd
├── vm-guest-services.nix      ← QEMU guest agent + SPICE (inactive by default)
│
│── Packages ─────────────────────────────────────────────────
├── system-packages.nix        ← Package assembly hub + kool.disabledPackages option
├── all-packages.nix           ← Master import hub for all packages/ files
│
│── Home Manager ─────────────────────────────────────────────
├── hm-users.nix               ← Home Manager user profile declarations
├── hm-local-bootstrap.nix     ← ~/.hm-local scaffold + empty/corrupt file detection
├── hm-home-scaffold.nix       ← Default home.nix template (read by hm-local-bootstrap)
│
│── Nixorcist Integration ────────────────────────────────────
├── copilot-cli.nix            ← GitHub Copilot CLI activation script
│
│── Optional / Cosmetic ──────────────────────────────────────
├── nixvim.nix                 ← NixVim (Neovim configured via Nix)
└── uwu/
    ├── nixowos.nix            ← NixOwOS branding (os-release + fastfetch logo)
    └── create_nixowos_logo.patch
```

---

## Module Groups

### Hardware & Boot

**Always loaded.** This group owns everything below the OS: kernel parameters,
GPU driver selection, hardware acceleration, and the bootloader.

`gpu.nix` is the central dispatcher for the GPU subsystem. It defines two
custom NixOS options (`gpu.kernelParams` and `gpu.driver`) and uses them to
conditionally import the correct kernel-params and driver sub-module. You
never import the individual driver files directly — `gpu.nix` handles that.

See [GPU Subsystem](#gpu-subsystem) for details.

### Display & Login

`sddm.nix` configures the SDDM display manager and the login screen background
(`/etc/nixos/assets/login.png`). It is always loaded; SDDM can be disabled by
setting `services.displayManager.sddm.enable = false` if you prefer a different
login manager.

### Core System

**Always loaded.** These modules configure the essentials that every NixOS
system needs: networking, locale, user accounts, audio, and the Nix daemon
itself. They are deliberately kept small and generic so they never need to
know about optional features.

### Shell & Environment

**Always loaded.** Zsh configuration, session environment variables, and the
rebuild error notification hook live here.

### Feature Modules

These modules are imported based on feature flags or conditionally activate
their configuration using the `features` attrset from `_module.args`.

Two import strategies are used:

**Strategy A — Conditional import** (the module is only imported when its
flag is `true`):

```nix
# configuration.nix
++ lib.optionals features.hyprland [
  ./modules/window-managers.nix
  ./modules/portals.nix
  # ...
]
```

The module file is never evaluated when the flag is `false`.

**Strategy B — Always imported, internally guarded** (the module is always
imported but reads `features.*` to decide what to enable):

```nix
# modules/gaming.nix
{ pkgs, features, filterPkgs, ... }:
{
  programs.steam.enable = features.steam;
  programs.gamemode.enable = features.steam;
  environment.systemPackages = lib.optionals features.steam (filterPkgs [...]);
}
```

This avoids removing the module from the import list when the feature is
disabled — it simply becomes a no-op. `kde.nix`, `gaming.nix`, and
`openssh.nix` use this strategy.

### Home Manager

Three files cooperate for Home Manager support:

| File | Role |
|------|------|
| `hm-home-scaffold.nix` | Default `home.nix` template written to `~/.hm-local/home.nix` |
| `hm-local-bootstrap.nix` | Activation script: creates `~/.hm-local/`, detects and fixes empty or corrupt `home.nix` |
| `hm-users.nix` | Declares which system users get Home Manager profiles (reads `features.home-manager-users`) |

The bootstrap logic recreates `~/.hm-local/home.nix` if the file is:
- missing
- empty (`! -s`)
- unparseable by `nix-instantiate --parse`

This prevents a broken scaffold from blocking a rebuild.

### Nixorcist Integration

`copilot-cli.nix` handles the GitHub Copilot CLI installation via an
activation script. It is guarded by a sentinel file
(`/var/lib/copilot-cli/.installed`) so the network installer only runs once.

### Optional / Cosmetic

`uwu/nixowos.nix` applies the NixOwOS branding overlay (custom `os-release` +
fastfetch ASCII logo). It is imported only when `features.uwu = true`. Removing
it has no effect on any other module.

---

## How Modules Interact

### \_module.args — Shared Channel

`configuration.nix` injects two values into every module's argument list:

```nix
_module.args = { inherit features filterPkgs; };
```

This is the **only** shared data channel between modules. A module receives
these values by declaring them in its function signature:

```nix
{ pkgs, lib, features, filterPkgs, ... }:
```

Modules that do not need them simply omit them — they receive
`{ config, pkgs, lib, ... }` as usual.

> `_module.args` is evaluated lazily. A module that does not declare
> `features` in its argument list will never evaluate the `features` attrset,
> which means unused feature flags have zero performance cost.

### The features Attrset

`features` is a plain Nix attribute set defined in the `let` block of
`configuration.nix`. Its values are booleans or strings. Modules read it
to branch their configuration:

```nix
programs.steam.enable = features.steam;
services.openssh.enable = features.openssh;
```

Modules must never **write** to `features`. It is a read-only input.

### The filterPkgs Function

`filterPkgs` is a function of type `[pkg] → [pkg]`. It filters out any
package whose `lib.getName` is present in either the file-managed disabled
list (`packages/disabled/disabled-packages.nix`) or the option-managed list
(`kool.disabledPackages` in `configuration.nix`).

Usage in a module:

```nix
environment.systemPackages = filterPkgs (with pkgs; [
  git
  curl
  ripgrep
]);
```

`filterPkgs` is **composable** — you can layer it with your own filter
without side effects:

```nix
myFilter = list: filterPkgs (lib.filter (p: p != pkgs.discord) list);
```

### The options / config Split

Modules that define custom NixOS **options** (not just set built-in options)
use the `options` / `config` split form:

```nix
{ config, lib, pkgs, ... }:
{
  options = {
    kool.disabledPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Package names to exclude from all package groups.";
    };
  };

  config = {
    environment.systemPackages = [ ... ];
  };
}
```

`system-packages.nix` uses this form to expose the `kool.disabledPackages`
option that `configuration.nix` sets. All other modules use the flat form
(just a set of `config.*` attributes) since they only set built-in options.

---

## GPU Subsystem

`gpu.nix` defines two custom options:

| Option | Values | What it controls |
|--------|--------|-----------------|
| `gpu.kernelParams` | `"generic"` `"thinkpad"` `"nvidia"` `"amd"` | Boot-time kernel tuning sub-module |
| `gpu.driver` | `"none"` `"amd"` `"intel"` `"nvidia"` `"nvidia-prime"` | Userspace driver sub-module |

These are set in `configuration.nix` by wiring the feature flags:

```nix
gpu.kernelParams = features.kernelParams;
gpu.driver       = features.gpu;
```

`gpu.nix` then imports the matching sub-module internally. You never import
`amd-drivers.nix` or `nvidia-drivers.nix` directly.

> ⚠️ The kernel param profiles (`-amd`, `-nvidia`, `-thinkpad`) are tuned for
> specific hardware. The ThinkPad profile targets the T480. **Create your own
> profile** rather than using a preset blindly — wrong params can cause kernel
> panics or poor performance.

---

## Home Manager Subsystem

```
hm-local-bootstrap.nix
  └─ reads → hm-home-scaffold.nix   (embedded at Nix eval time via builtins.readFile)
  └─ writes → ~/.hm-local/home.nix  (only when missing / empty / corrupt)

hm-users.nix
  └─ reads → features.home-manager-users  (to declare per-user HM config)
  └─ points each user at → ~/.hm-local/home.nix (or default.nix)
```

The scaffold content lives in `hm-home-scaffold.nix` and is embedded into the
activation script at Nix evaluation time using `builtins.readFile`. The shell
activation script never reads a file at runtime — the content is baked in.

---

## Writing a New Module

```nix
# modules/my-feature.nix
# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

{ pkgs, lib, features, filterPkgs, ... }:
{
  # Guard the whole module if you want strategy B (always imported, internally guarded)
  config = lib.mkIf features.myFeature {
    services.my-service.enable = true;

    environment.systemPackages = filterPkgs (with pkgs; [
      my-package
    ]);
  };
}
```

Then add it to `configuration.nix`:

```nix
imports = [
  # ...
  ./modules/my-feature.nix   # My service → features.myFeature
];
```

And declare the flag in the `features` block:

```nix
myFeature = true;
```

Test before switching:

```bash
sudo nixos-rebuild dry-activate
sudo nixos-rebuild switch
```

---

## Code of Conduct

1. **One concern per file.** `audio.nix` handles audio. `networking.nix`
   handles networking. Do not combine unrelated concerns.

2. **No implicit sibling dependencies.** A module must never `import` another
   module in this directory or call its functions directly. Use `_module.args`
   or the NixOS option system for any shared data.

3. **Package lists belong in `packages/`.** Modules configure services and
   options. Avoid large inline package lists inside `modules/`; use
   `filterPkgs` when assembling small ancillary tool lists.

4. **Hardware-specific files stay named.** GPU drivers, kernel params, and
   machine-specific tuning live in their own named files. Never merge them
   into generic modules.

5. **Every module carries the attribution header** (see example above).

6. **Generated files do not go here.** nixorcist output lives exclusively
   in `nixorcist/generated/`.

---

*Tak_OS — declarative, modular, yours.*  
*© 2026 tak0dan · GNU GPLv3 · [https://github.com/tak0dan/Tak_OS](https://github.com/tak0dan/Tak_OS)*
