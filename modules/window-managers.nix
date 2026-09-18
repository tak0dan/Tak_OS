# Tak_OS · window-managers.nix — Hyprland, bspwm, i3, and xkb layout (loaded with features.hyprland)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, lib, features, ... }:

{
  # Hyprland compositor — activated via features.hyprland in configuration.nix
  programs.hyprland.enable = features.hyprland;

  # Use UWSM — automatically creates graphical-session.target for proper systemd integration
  programs.hyprland.withUWSM = lib.mkIf features.hyprland true;

  services.xserver.enable = true;

  services.xserver.windowManager = {
    bspwm.enable = true;
    i3.enable = true;
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
