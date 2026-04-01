# Tak_OS · portals.nix — XDG portals (Hyprland / KDE) for Flatpak / screen share
# github.com/tak0dan/Tak_OS · GNU GPLv3
{pkgs, ...}: {
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    configPackages = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
