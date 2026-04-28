# Tak_OS · hyprland-layer.nix — Conditional Hyprland desktop stack import hub
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ lib, features, ... }:
{
  imports =
    lib.optionals features.hyprland [
      ./window-managers.nix
      ./portals.nix
      ./quickshell.nix
      ./fonts.nix
      ./theme.nix
      ./overlays.nix
      ./nh.nix
      ./hyprlock.nix
      ./wlogout.nix
      ./vm-guest-services.nix
      ./local-hardware-clock.nix
    ];
}
