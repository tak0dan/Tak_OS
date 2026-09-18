# Tak_OS · window-managers.nix — Hyprland, bspwm, i3, and xkb layout (loaded with features.hyprland)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, lib, features, ... }:

{
  # Hyprland settings — start polkit agent on session start
  services.hyprland.settings = lib.mkIf features.hyprland {
    exec-once = [
      "systemctl --user start polkit-kde-agent"
      "systemctl --user start hyprpolkitagent"
    ];
  };

  # Hyprland compositor toggle — activated via features.hyprland in configuration.nix
  programs.hyprland.enable = features.hyprland;

  # NixOS Hyprland service — required for hyprland-session.target and polkit-kde-agent
  services.hyprland.enable = features.hyprland;

  # Hyprland polkit agent — required for authentication prompts under Hyprland
  systemd.user.services.hyprpolkitagent = lib.mkIf features.hyprland {
    description = "Hyprland Polkit Agent";
    after    = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart  = "on-failure";
    };
  };

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
