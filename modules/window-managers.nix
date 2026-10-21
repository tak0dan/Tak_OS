# Tak_OS · window-managers.nix — Hyprland, bspwm, i3, and xkb layout (loaded with features.hyprland)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ lib, config, pkgs, features, ... }:

{
  # Hyprland compositor toggle — activated via features.hyprland in configuration.nix
  programs.hyprland.enable = features.hyprland;

  services.xserver.enable = true;

  # KDE support in this repo is intended as runtime integration for Hyprland,
  # not as a second full desktop session. Enabling Plasma here makes the
  # display manager prefer a broken startplasma-wayland path.
  services.desktopManager.plasma6.enable = false;
  services.displayManager.defaultSession = lib.mkDefault "hyprland-uwsm";

  services.xserver.windowManager = {
    bspwm.enable = true;
    i3.enable = true;
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
