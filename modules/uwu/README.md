# modules/uwu/ — Cosmetic Branding Sub-Module

> Part of [Tak_OS](https://github.com/tak0dan/Tak_OS) · parent: [`modules/`](../README.md)

---

```
modules/uwu/
├── nixowos.nix                 ← NixOwOS branding overlay (os-release + fastfetch)
└── create_nixowos_logo.patch   ← fastfetch ASCII logo patch
```

---

## Description

An optional cosmetic sub-module that applies NixOwOS-style branding to the
running system **without** importing the full NixOwOS flake. It operates on
two surfaces:

| Surface | Effect |
|---------|--------|
| `os-release` | Sets `distroId`, `distroName`, `vendorId`, `vendorName` in `/etc/os-release` so tools like `neofetch` and `fastfetch` identify the system as NixOwOS. NixOS automatically emits `ID_LIKE=nixos` when `distroId != "nixos"`. |
| `fastfetch` | Patches the NixOwOS ASCII logo into the fastfetch binary via `create_nixowos_logo.patch`. |

The module is entirely self-contained — disabling it reverts all changes automatically.

---

## Enabling / Disabling

Controlled by a single feature flag in `configuration.nix`:

```nix
features.uwu = true;   # enable NixOwOS cosmetics
features.uwu = false;  # disable — no os-release changes, no logo patch
```

When `false`, `uwu/nixowos.nix` is not imported at all. No manual cleanup needed.

---

## Code of Conduct

- This module is **cosmetic only** — it must never affect system behaviour, services, or packages.
- The patch file (`create_nixowos_logo.patch`) must stay in sync with the fastfetch version declared in the overlay.
- Do not add service configuration or package lists here.

---

## Upgrade Guide

If fastfetch is updated and the patch no longer applies:

```bash
# Regenerate the patch against the new fastfetch source
# Update create_nixowos_logo.patch accordingly
# Test with:
sudo nixos-rebuild dry-activate
```
