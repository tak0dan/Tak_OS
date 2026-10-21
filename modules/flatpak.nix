# Tak_OS · flatpak.nix — Flatpak support (guarded by features.flatpak)
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# FLATPAK.NIX — optional Flatpak runtime
# ======================================
# Activated when features.flatpak = true.
# Keeps Flatpak runtime support declarative and leaves remotes/apps to dedicated
# pure tooling such as nix-flatpak or Home Manager modules.

{ lib, features, ... }:
{
  services.flatpak.enable = lib.mkIf features.flatpak true;
}
