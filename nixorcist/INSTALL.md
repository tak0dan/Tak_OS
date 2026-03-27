# Installing Nixorcist into Any NixOS Configuration

This guide walks you through adding Nixorcist to an existing NixOS setup.
It does **not** require flakes or any changes to your existing modules —
only a single `imports` line in `configuration.nix`.

---

## Requirements

| Tool | Purpose |
|------|---------|
| NixOS 24.05+ | Any channel (stable or unstable) |
| Bash 4.4+ | Ships with NixOS |
| `fzf` | Interactive package browser — add to your packages if missing |
| `nix-command` + `flakes` experimental features | For `nix eval` validation |

---

## Step 1 — Copy Nixorcist into your config

```bash
# Clone from GitHub
git clone https://github.com/tak0dan/Nixorcist.git /etc/nixos/nixorcist

# Or copy from an existing install
cp -r /path/to/nixorcist /etc/nixos/nixorcist
```

The folder should live at `/etc/nixos/nixorcist/` (next to `configuration.nix`).
You can use a different path — just adjust the imports line accordingly.

---

## Step 2 — Enable flakes (if not already)

Add to your `configuration.nix`:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Nixorcist uses `nix eval` for package validation and `nix-build` for staging.
Both require `nix-command`.

---

## Step 3 — Wire the hub into your config

Add **one line** to the `imports` list in `configuration.nix`:

```nix
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./nixorcist/generated/all-packages.nix   # ← add this
    # ... your other modules
  ];

  # rest of your config unchanged
}
```

The file `nixorcist/generated/all-packages.nix` is created automatically on
the first run (or you can bootstrap it — see Step 4).

---

## Step 4 — Bootstrap (first run)

```bash
# Make the entry point executable
chmod +x /etc/nixos/nixorcist/nixorcist.sh

# Create a system-wide alias (optional but recommended)
sudo ln -sf /etc/nixos/nixorcist/nixorcist.sh /usr/local/bin/nixorcist

# Bootstrap: generate the hub so NixOS can evaluate your config
sudo nixorcist gen
sudo nixorcist hub
```

If `generated/all-packages.nix` does not exist yet, NixOS will fail to
evaluate during `nixos-rebuild`.  The `gen` + `hub` commands create it with
an empty package list so the first rebuild succeeds.

---

## Step 5 — Fetch the package index

The index powers fast package search and the smart rebuild resolver.
Without it, search falls back to well-known renames only.

```bash
sudo nixorcist refresh-index
# Takes 1–3 minutes on first run; writes ~7MB to cache/nixpkgs-index.txt
# Subsequent fetches are incremental and much faster.
```

---

## Step 6 — Install fzf (if not yet installed)

Nixorcist uses `fzf` for the interactive package browser.  Add it to your
system packages in `configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  fzf
  # ... other packages
];
```

Then rebuild once:

```bash
sudo nixos-rebuild switch
```

---

## Step 7 — Use it

```bash
# Open the TUI
sudo nixorcist

# Or use CLI commands directly
sudo nixorcist install firefox git helix
sudo nixorcist delete vim
sudo nixorcist chant -python +python3
sudo nixorcist rebuild
```

---

## Directory layout after install

```
/etc/nixos/
├── configuration.nix          ← add the imports line here
├── hardware-configuration.nix
└── nixorcist/
    ├── nixorcist.sh           ← main entry point
    ├── lib/                   ← sourced libraries
    ├── generated/             ← auto-managed, do not edit by hand
    │   ├── all-packages.nix   ← hub imported by configuration.nix
    │   ├── .modules/          ← one .nix per installed package
    │   └── .lock              ← package list (plain text)
    └── cache/                 ← index + validation cache (gitignore these)
```

---

## Optional: sudoers entry for passwordless rebuilds

If you run Nixorcist frequently, you may want passwordless sudo for the
rebuild command only:

```
# /etc/sudoers.d/nixorcist
youruser ALL=(ALL) NOPASSWD: /usr/local/bin/nixorcist
```

---

## Gitignore recommendation

When version-controlling your NixOS config, add to `.gitignore`:

```gitignore
nixorcist/cache/
nixorcist/generated/.modules/
nixorcist/generated/all-packages.nix
nixorcist/nixorcist-old/
nixorcist/nixorcist-trace.txt
```

**Do commit** `nixorcist/generated/.lock` — it is the source of truth for
which packages are managed by Nixorcist.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `nixos-rebuild` fails with `all-packages.nix not found` | Run `sudo nixorcist gen && sudo nixorcist hub` first |
| `attribute 'python' missing` during rebuild | Run `sudo nixorcist rebuild` — the smart resolver will prompt you |
| `fzf: command not found` | Add `fzf` to `environment.systemPackages` and rebuild |
| `nix-command is not a known feature` | Add `nix.settings.experimental-features = [ "nix-command" "flakes" ]` |
| TUI appears garbled | Ensure your terminal supports UTF-8 and ANSI escape codes |
| Validation cache is stale | Delete `nixorcist/cache/pkg-validation.cache` and re-run |
| Package index missing | Run `sudo nixorcist refresh-index` |

---

## Uninstall

```bash
# Remove the imports line from configuration.nix, then:
sudo nixos-rebuild switch

# Remove the directory
sudo rm -rf /etc/nixos/nixorcist
sudo rm -f /usr/local/bin/nixorcist
```
