# assets/ — Wallpapers and Media

> Part of [Tak_OS](https://github.com/tak0dan/Tak_OS) · parent: [`/etc/nixos/`](../README.md)

---

```
assets/
├── *.jpg / *.png          ← wallpapers used by SDDM, Hyprland, or KDE
├── *.mp4                  ← animated wallpapers (e.g. for live backgrounds)
└── login.png              ← SDDM login screen background
```

---

## Description

Static media files referenced by display-related NixOS modules. Paths are
declared inside the relevant module (e.g. `modules/sddm.nix`) using the
absolute `/etc/nixos/assets/<file>` path so they survive rebuilds.

### Current assets

| File | Used by |
|------|---------|
| `login.png` | `modules/sddm.nix` — SDDM login background |
| `zaney-wallpaper.jpg` | Hyprland default wallpaper |
| `nix-*.png / *.jpg` | Theme/decoration variants |
| `nix-bazel.mp4`, `nix.mp4` | Animated wallpaper options |
| `Rainnight.jpg`, `AnimeGirlNightSky.jpg` | Alternates for SDDM/Hyprland |

---

## Adding a Wallpaper

```bash
# Copy your image into the assets directory
sudo cp ~/Pictures/mywallpaper.jpg /etc/nixos/assets/

# Reference it in the relevant module, e.g. modules/sddm.nix:
#   background = "/etc/nixos/assets/mywallpaper.jpg";

# Rebuild to apply
sudo nixos-rebuild switch
```

---

## Code of Conduct

- Keep files small — large media bloats the config repo and rebuild times.
- Prefer `.jpg` for photos, `.png` for graphics with transparency.
- Do not store secrets, credentials, or personal data here.
- Animated wallpapers (`.mp4`) should be used sparingly — they consume GPU resources.
