# Tak_OS · hm-users.nix — Home Manager user wiring — maps system users to HM configs
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# HM-USERS.NIX — Home Manager user profile declarations
# =====================================================
# Loaded when features.home-manager = true.
# Requires <home-manager/nixos> to be imported first (handled by
# modules/home-manager-layer.nix).
#
# Generates one Home Manager profile per entry in features.home-manager-users.
# Every imported file is repository-owned:
#   • home/common.nix          — shared baseline
#   • home/hypr-desktop.nix    — shared declarative Hyprland user config
#   • home/<user>.nix          — per-user customisation
# This keeps evaluation pure and portable across machines.

{ config, pkgs, lib, features, ... }:
{
  home-manager.extraSpecialArgs = { inherit features; };

  home-manager.users = lib.genAttrs features.home-manager-users (user:
    let
      userFile = ../home + "/${user}.nix";
    in
    {
      home.username                  = user;
      home.homeDirectory             = "/home/${user}";
      home.stateVersion              = lib.mkDefault config.system.stateVersion;
      home.enableNixpkgsReleaseCheck = false;
      imports = [
        ../home/common.nix
        ../home/hypr-desktop.nix
        userFile
      ];
    });
}
