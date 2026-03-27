# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# HM-USERS.NIX — Home Manager user profile declarations
# ======================================================
# Loaded when features.home-manager = true (set in configuration.nix).
# Requires <home-manager/nixos> to be imported first (handled in configuration.nix).
#
# Generates one home-manager profile per entry in features.home-manager-users.
# To add a user: append their name to that list — everything else is derived.
#
# Each profile:
#   • Sets home.username / home.homeDirectory from the name alone.
#   • Sets home.stateVersion to match system.stateVersion — safe to override in home.nix.
#   • Imports /home/<user>/.hm-local/home.nix    (preferred)
#          or /home/<user>/.hm-local/default.nix  (fallback)
#   • Falls back to a baseline (just git) when neither file exists.
#   • home-manager only manages what home.nix explicitly declares;
#     existing files are never touched unless listed there.
#
# The scaffold for ~/.hm-local/home.nix lives in modules/hm-home-scaffold.nix
# and is written automatically by modules/hm-local-bootstrap.nix.

{ config, pkgs, lib, features, ... }:
{
  home-manager.users = lib.genAttrs features.home-manager-users (user:
    let
      local  = "/home/${user}/.hm-local";
      hmFile =
        if builtins.pathExists (local + "/home.nix")    then local + "/home.nix"
        else if builtins.pathExists (local + "/default.nix") then local + "/default.nix"
        else null;
    in
    {
      home.username                  = user;
      home.homeDirectory             = "/home/${user}";
      home.stateVersion              = lib.mkDefault config.system.stateVersion;
      home.enableNixpkgsReleaseCheck = false;
      imports                        = lib.optionals (hmFile != null) [ hmFile ];
      home.packages                  = [ pkgs.git ]; # baseline — always present
    });
}
