# Tak_OS — Upgrade TODO

Living plan for the next upgrade cycle. Items are grouped by area and roughly
ordered by priority within each group. Check items off as they land.

## 0. Known blockers (found by evaluating `main` for a VM build)

- [x] `modules/overlays.nix`, `modules/wlogout.nix`, `home/hypr-desktop.nix`:
      absolute `/etc/nixos/...` paths break evaluation outside an installed
      machine. Use paths relative to the file (`../assets`, `../packages`).
- [x] `packages/kde.nix`: `/home/tak_1/native-kio-context-menu/package.nix` is
      a personal, machine-local package. Move it behind an option or into a
      private overlay; it is currently commented out.
- [x] `assets/Wallpapers` is a symlink to `/home/tak_1/...`. Replace it with a
      real directory or a documented setup step.
- [x] `modules/nixvim.nix` imports `/etc/nixos/external/nixvim`, which is not in
      the repo. It is not imported by `configuration.nix`, so either fix or delete.
- [x] `packages/xampp*.nix`, `modules/services/xampp.nix` do not parse and are
      not imported. Fix or move them to a `disabled/` folder.
- [x] `packages/eclipse.nix` does not parse (already broken before the upgrade).
- [x] Evaluation warning: `swww` was renamed to `awww`. Update the package name.
- [ ] Two architectures coexist: upstream's `graph.platform` / `graph.services`
      layer and the older `features.*` flags. Pick one and retire the other.

## 1. Profile-based installer (`scripts/takos-installer.py`)

Goal: an nmtui-style terminal UI that installs a configuration *profile* chosen
by purpose, instead of hand-editing `configuration.nix`.

- [x] Python 3 standard library only (`curses`), so it runs on a fresh NixOS
      install without extra packages. Keep `install.sh` as the thin shell
      entry point it calls for the deploy/build/switch phases.
- [x] Screens, nmtui-like: profile list → module checklist (preview) →
      hardware review (from `detect-hardware.sh`) → user mapping → review →
      apply. Every screen has a default, so pressing Enter straight through
      gives a working install (keeps today's "works by default" behaviour).
- [x] Non-interactive mode: `--profile hyprland --yes` for scripts and CI.
- [x] Output is a generated `profile.nix` plus the existing staging/deploy path,
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

- [x] Every reusable unit is a **module** with a small manifest: `id`, `title`,
      `provides` (packages, services, options), `requires`, `conflicts`.
- [x] A profile is a list of module ids. The same module can appear in several
      profiles and can be included **more than once** as a base:
      `kde.nix` is the base of the KDE profile and of the Hyprland profile
      (for the Qt/KDE apps Hyprland uses).
- [x] The generator dedupes module ids before it writes `imports`, so a shared
      base is loaded once. Check that duplicate `imports` paths do not double
      option definitions (verify in a VM before relying on it).
- [ ] Package groups (`packages/*.nix`) are modules too. Profiles pick groups
      instead of editing lists by hand.
- [ ] Options that differ per use (e.g. KDE as base vs. standalone) are set by
      the profile, not by copying the file.
- [x] Dependency and conflict checks run before the build (e.g. two display
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
- [x] Parse check for all `.nix` files (catches the xampp/eclipse-class breakage).
- [x] Python unit tests for the installer's profile resolver and dedupe logic.

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

## 7. `takos-rebuild` — smart rebuild with version rebasing

Goal: one command that rebuilds the system and can move the whole configuration
to another NixOS release, renaming deprecated packages on the way.

- [x] `takos-rebuild` (shell entry point, installed to the system PATH) wraps
      `nixos-rebuild` and calls `scripts/nix-rebuild-smart.sh` for the build step.
- [x] **Rename pass from evaluation warnings.** NixOS already reports every
      renamed attribute ("`swww` has been renamed to `awww`"). Parse those
      warnings from `nix eval`/`nixos-rebuild build` output and rewrite the
      old name in the declaration files. Precise, and needs no rename table.
- [x] **Rebase pass from nixorcist search.** For a package that is missing in
      the target release, use `nixorcist search <name> --release <R> --json` to
      propose the closest replacement and show it to the user before writing.
      Rebase only touches names it can verify on the target release.
- [x] `takos-rebuild --version` opens an nmtui-like window (curses, shared with
      the profile installer) listing the stable releases **23.05 → 26.05**, plus
      a text field for a custom release string. Choosing one sets
      `system.stateVersion`-independent channel/input pin and runs the rebase.
- [x] Dry-run first: `takos-rebuild --version 25.11 --plan` prints every rename
      and replacement without writing files. Writing requires confirmation.
- [ ] Every change is staged in a git-tracked working tree, so the rebase can be
      reviewed with `git diff` and reverted with `git checkout`.
- [x] Failure path: if the target build fails, roll back the declaration
      changes and keep the previous generation (`nixos-rebuild` rollback).
- [x] Tests: fixtures with a deprecated name, a removed package, and a
      no-op config; check the plan output and the rewritten files.

## 8. Token-based configuration composition (direction, not started)

Idea: split the configuration into **tokens** — the smallest named pieces (a
module, a function, an option set, a package list) with declared inputs and
outputs — and compose a system from tokens for a given need.

- [ ] Give each token a manifest entry (`provides`, `needs`, `replaces`) so the
      composer can see what is missing before it builds.
- [ ] Compose a profile from tokens instead of whole modules, so a shared piece
      such as "Qt runtime" is one token used by KDE and Hyprland alike.
- [ ] **Reconstruct what is missing**: when a token that a profile needs is
      absent (renamed, removed, or never written), generate it from the nearest
      known-good token or from nixorcist's package index, then show the diff
      before writing it.
- [ ] Keep every reconstructed token traceable (comment with its origin) so it
      can be reviewed or removed later.
- [ ] Use the same token index for `takos-rebuild` renames, so a rename is a
      token-level change, not a text search.
