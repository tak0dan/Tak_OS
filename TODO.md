# Tak_OS — Upgrade TODO

Living plan for the next upgrade cycle. Items are grouped by area and roughly
ordered by priority within each group. Check items off as they land.

## 0. Known blockers (found by evaluating `main` for a VM build)

- [ ] `modules/overlays.nix`, `modules/wlogout.nix`, `home/hypr-desktop.nix`:
      absolute `/etc/nixos/...` paths break evaluation outside an installed
      machine. Use paths relative to the file (`../assets`, `../packages`).
- [ ] `packages/kde.nix`: `/home/tak_1/native-kio-context-menu/package.nix` is
      a personal, machine-local package. Move it behind an option or into a
      private overlay; it is currently commented out.
- [ ] `assets/Wallpapers` is a symlink to `/home/tak_1/...`. Replace it with a
      real directory or a documented setup step.
- [ ] `modules/nixvim.nix` imports `/etc/nixos/external/nixvim`, which is not in
      the repo. It is not imported by `configuration.nix`, so either fix or delete.
- [ ] `packages/xampp*.nix`, `modules/services/xampp.nix` do not parse and are
      not imported. Fix or move them to a `disabled/` folder.
- [ ] `packages/eclipse.nix` does not parse (already broken before the upgrade).
- [ ] Evaluation warning: `swww` was renamed to `awww`. Update the package name.
- [ ] Two architectures coexist: upstream's `graph.platform` / `graph.services`
      layer and the older `features.*` flags. Pick one and retire the other.

## 1. Profile-based installer (`scripts/takos-installer.py`)

Goal: an nmtui-style terminal UI that installs a configuration *profile* chosen
by purpose, instead of hand-editing `configuration.nix`.

- [ ] Python 3 standard library only (`curses`), so it runs on a fresh NixOS
      install without extra packages. Keep `install.sh` as the thin shell
      entry point it calls for the deploy/build/switch phases.
- [ ] Screens, nmtui-like: profile list → module checklist (preview) →
      hardware review (from `detect-hardware.sh`) → user mapping → review →
      apply. Every screen has a default, so pressing Enter straight through
      gives a working install (keeps today's "works by default" behaviour).
- [ ] Non-interactive mode: `--profile hyprland --yes` for scripts and CI.
- [ ] Output is a generated `profile.nix` plus the existing staging/deploy path,
      not a rewrite of the repo.

### Profiles (first set)

| Profile        | Purpose                                              |
|----------------|------------------------------------------------------|
| `minimal`      | Base system, networking, shell, no desktop           |
| `hyprland`     | Wayland desktop (Hyprland, Waybar, wlogout, hyprlock)|
| `kde`          | Plasma desktop                                       |
| `development`  | Compilers, editors, language toolchains, containers  |
| `gaming`       | Steam, GameMode, Wine/Proton, controller support     |
| `devops`       | Docker, kubectl/helm, terraform, monitoring tools    |
| `experimenting`| Nix tooling, nixvim, sandboxing, scratch environment |
| `testing`      | Test runners, linters, VM and build-test helpers     |
| `vm`           | Guest tooling only (qemu-guest-agent, SPICE, VBox)   |

Profiles are composed, not copied: `hyprland` = `minimal` + `kde-runtime` +
`hyprland-desktop`, and `development` can be added to any of them.

## 2. Module and package-group model

- [ ] Every reusable unit is a **module** with a small manifest: `id`, `title`,
      `provides` (packages, services, options), `requires`, `conflicts`.
- [ ] A profile is a list of module ids. The same module can appear in several
      profiles and can be included **more than once** as a base:
      `kde.nix` is the base of the KDE profile and of the Hyprland profile
      (for the Qt/KDE apps Hyprland uses).
- [ ] The generator dedupes module ids before it writes `imports`, so a shared
      base is loaded once. Check that duplicate `imports` paths do not double
      option definitions (verify in a VM before relying on it).
- [ ] Package groups (`packages/*.nix`) are modules too. Profiles pick groups
      instead of editing lists by hand.
- [ ] Options that differ per use (e.g. KDE as base vs. standalone) are set by
      the profile, not by copying the file.
- [ ] Dependency and conflict checks run before the build (e.g. two display
      managers, two GPU profiles that do not pair).

## 3. Hardware and VMs

- [ ] Run `detect-hardware.sh` from the installer and show the recommendation
      (GPU profile, VM guest, virtualisation) with a way to override it.
- [ ] Detect VM guests and offer the `vm` profile automatically.
- [ ] Tests for `detect-hardware.sh` against recorded sysfs fixtures for
      Intel, AMD, NVIDIA, Optimus, VirtualBox, QEMU, VMware and Hyper-V.

## 4. Testing

- [ ] Evaluation matrix: `nix-instantiate --eval` the toplevel for every profile
      in CI so a broken profile fails before it reaches a user.
- [ ] `nixos-rebuild build-vm` smoke test for `minimal`, `hyprland` and `vm`.
- [ ] Parse check for all `.nix` files (catches the xampp/eclipse-class breakage).
- [ ] Python unit tests for the installer's profile resolver and dedupe logic.

## 5. Safety and secrets

- [ ] No credentials in the repo. The WiFi-EDU profile was removed; keep
      credentials in an untracked environment file or a secrets manager.
- [ ] Installer never writes outside the staged copy until the user confirms
      the deploy step.

## 6. Documentation

- [ ] `scripts/README.md`: document the profile installer and the module manifest.
- [ ] Module manifest reference, with one worked example (`kde` shared by KDE
      and Hyprland).
- [ ] Single architecture diagram once section 0 is resolved.
