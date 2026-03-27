# Tak_OS · window-managers.nix — Hyprland, bspwm, i3, and xkb layout (loaded with features.hyprland)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, features, ... }:

{
  # Hyprland compositor toggle — activated via features.hyprland in configuration.nix
  programs.hyprland.enable = features.hyprland;

  services.xserver.enable = true;

  services.desktopManager.plasma6.enable = true;

  services.xserver.windowManager = {
    bspwm.enable = true;
    i3.enable = true;
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
