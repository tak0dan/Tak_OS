# scripts/ — Build & Deployment Helpers

> Part of [Tak\_OS](https://github.com/tak0dan/Tak_OS) · parent: [`/etc/nixos/`](../README.md)  
> **License:** GNU GPLv3

---

## Directory Map

```
scripts/
├── install.sh                       ← fresh-install bootstrap (run this first)
├── nix-rebuild-smart.sh             ← interactive rebuild with error resolver
├── nixos-rebuild                    ← thin wrapper around nixos-rebuild
├── nixos-rebuild-error-listener.sh  ← background listener for rebuild errors
├── nixos-comment.sh                 ← comment out a package name in .nix files
├── nixos-uncomment.sh               ← uncomment a package name in .nix files
└── deploy-to-etc-nixos.sh           ← deploy repo contents into /etc/nixos
```

---

## Description

These scripts extend and simplify the standard NixOS rebuild workflow.
They are plain Bash tools run by the user — they are not part of Nix
evaluation and have no effect on the system configuration itself.

---

### `install.sh`

**Run this once on a fresh NixOS machine** after cloning the repo.
No manual file editing required — everything is detected automatically.

**Auto-detected values (no prompts):**

| Value | Source |
|-------|--------|
| Username | `$SUDO_USER` → `logname` → parsed from `/etc/nixos/configuration.nix` |
| Hostname | `hostname -s` |
| Target NixOS version | `system.stateVersion` in the repo's `configuration.nix` |

**Two-phase install:**

*Phase 1 — Channel upgrade*
1. Adds `nixos-<version>` and `home-manager` channels — fixes the missing
   channel error and ensures packages like `thunar` and `ghostty` are available.
2. Rebuilds your **existing** NixOS config on the new channel (safe baseline
   before Tak_OS is applied).

*Phase 2 — Tak_OS deployment*
3. Patches `modules/users.nix`, `modules/networking.nix`, and
   `configuration.nix` with your real username and hostname.
4. Defaults `kernelParams` to `"generic"` (safe for any hardware; change it
   later once you know your GPU/CPU profile).
5. Deploys the full config to `/etc/nixos/` via `rsync`, preserving
   `hardware-configuration.nix` and the nixorcist cache.
6. Runs `nixos-rebuild switch` into Tak_OS.

```bash
sudo bash /path/to/Tak_OS/scripts/install.sh
```

> **Note:** After the rebuild your home-manager scaffold is written to
> `/home/<user>/.hm-local/home.nix` automatically. Edit it freely — it will
> never be overwritten unless it is empty or has a syntax error.

---

### `nix-rebuild-smart.sh`

The primary rebuild helper. Wraps `nixos-rebuild switch` with a retry loop that:

1. Captures the build log on failure.
2. Detects `attribute 'X' missing` / `undefined variable 'X'` errors.
3. Checks a well-known rename table (e.g. `python` → `python3`).
4. Falls back to ranked search against the nixorcist package index.
5. Offers an interactive replacement prompt.
6. Retries up to 5 times.

```bash
sudo nixos-smart-rebuild
# or directly:
sudo bash /etc/nixos/scripts/nix-rebuild-smart.sh
```

Requires the nixorcist index to be populated:

```bash
sudo nixorcist refresh-index
```

---

### `nixos-rebuild`

Thin wrapper that calls the system `nixos-rebuild` with sane defaults.
Forwards all arguments as-is.

```bash
sudo /etc/nixos/scripts/nixos-rebuild switch
sudo /etc/nixos/scripts/nixos-rebuild dry-activate
```

---

### `nixos-rebuild-error-listener.sh`

Background daemon that watches the systemd journal for rebuild error events
and triggers a desktop notification or hook defined in
`modules/rebuild-error-hook.nix`.

Started automatically when that module is imported. Not meant to be run
manually.

---

### `nixos-comment.sh` / `nixos-uncomment.sh`

Utility pair for toggling package names in `packages/disabled/disabled-packages.nix`.
This is the preferred way to disable a package globally without deleting it.

```bash
# Disable a package globally
sudo nixos-comment   discord

# Re-enable it
sudo nixos-uncomment discord
```

Under the hood, these scripts modify the disabled list file and trigger
a rebuild. They are also the backing implementation of:

```bash
# nixorcist wraps these internally
nixorcist status    # shows which packages are disabled
```

---

### `deploy-to-etc-nixos.sh`

Copies the repository working tree into `/etc/nixos`, with automatic backup:

1. Renames any existing `~/nixos-backup` to `~/nixos-backup-before-<timestamp>`.
2. Creates a fresh `~/nixos-backup` from the current `/etc/nixos`.
3. Copies the repo into `/etc/nixos`.

Must be run as root:

```bash
sudo bash /etc/nixos/scripts/deploy-to-etc-nixos.sh
```

---

## Code of Conduct

- Scripts must be safe Bash (`set -euo pipefail`).
- Scripts that write to `/etc/nixos` must create a backup first.
- Do not hard-code usernames or paths — use `$SUDO_USER`, `$HOME`, `$CONFIG_DIR`.
- Keep scripts idempotent where possible.
- Scripts may read from `/etc/nixos` freely but must not modify
  `configuration.nix`, `modules/`, or `packages/` outside of explicit
  user-initiated operations (comment/uncomment tools).

---

*Tak_OS — declarative, modular, yours.*  
*© 2026 tak0dan · GNU GPLv3 · https://github.com/tak0dan/Tak_OS*
