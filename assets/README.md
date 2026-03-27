# assets/ — Wallpapers and Media

> Part of [Tak\_OS](https://github.com/tak0dan/Tak_OS) · parent: [`/etc/nixos/`](../README.md)  
> **License:** GNU GPLv3

---

## Directory Map

```
assets/
├── login.png                          ← SDDM login screen background
├── zaney-wallpaper.jpg                ← Hyprland default wallpaper
├── AnimeGirlNightSky.jpg              ← Alternate wallpaper (SDDM / Hyprland)
├── Rainnight.jpg                      ← Alternate wallpaper
├── beautifulmountainscape.jpg         ← Alternate wallpaper
├── mountainscapedark.jpg              ← Alternate wallpaper
├── nixos-declarative.jpg              ← NixOS themed wallpaper
├── nix-azurlane-33-22.png             ← NixOS themed wallpaper
├── nix-cirno-nixos.png                ← NixOS themed wallpaper
├── nix-dracula.png                    ← NixOS themed wallpaper (Dracula)
├── nix-glow-black.png                 ← NixOS themed wallpaper
├── nix-glow-gruvbox.png               ← NixOS themed wallpaper (Gruvbox)
├── nix-gruvbox-dark-blue.png          ← NixOS themed wallpaper (Gruvbox)
├── nix-gruvbox-dark-rainbow.png       ← NixOS themed wallpaper (Gruvbox)
├── nix-gruvbox-light-rainbow.png      ← NixOS themed wallpaper (Gruvbox)
├── nix-linux-nixos-gruvbox-*.jpg      ← NixOS themed wallpaper
├── nix-owo.png                        ← NixOS owo wallpaper
├── nix-wallpaper-stripes-logo.png     ← NixOS stripes logo wallpaper
├── nix-bazel.mp4                      ← Animated wallpaper
└── nix.mp4                            ← Animated wallpaper
```

---

## Description

Static media files referenced by display-related NixOS modules. Paths are
declared inside the relevant module using the absolute `/etc/nixos/assets/<file>`
path so they survive rebuilds.

### Where each asset is used

| File | Used by |
|------|---------|
| `login.png` | `modules/sddm.nix` — SDDM login background |
| `zaney-wallpaper.jpg` | Hyprland default wallpaper (via dotfiles) |
| `nix-*.png / *.jpg` | Theme / decoration variants — swap in SDDM or Hyprland config |
| `nix-bazel.mp4`, `nix.mp4` | Animated wallpaper options (e.g. swww) |
| `AnimeGirlNightSky.jpg`, `Rainnight.jpg` | Alternates for SDDM / Hyprland |

---

## Adding a Wallpaper

```bash
# 1. Copy your image into the assets directory
sudo cp ~/Pictures/mywallpaper.jpg /etc/nixos/assets/

# 2. Reference it in the relevant module, for example modules/sddm.nix:
#      background = "/etc/nixos/assets/mywallpaper.jpg";

# 3. Rebuild to apply
sudo nixos-rebuild switch
```

---

## Code of Conduct

- **Keep files small.** Large media bloats the config repo and slows `git clone`.
  Prefer `.jpg` for photos, `.png` for graphics with transparency.
- **Animated wallpapers (`.mp4`) should be used sparingly** — they consume
  GPU resources continuously.
- **Do not store secrets, credentials, or personal data here.**
- When replacing the SDDM background, update the path in `modules/sddm.nix`
  rather than overwriting `login.png` in-place, so the change is tracked.

---

*Tak_OS — declarative, modular, yours.*  
*© 2026 tak0dan · GNU GPLv3 · https://github.com/tak0dan/Tak_OS*
