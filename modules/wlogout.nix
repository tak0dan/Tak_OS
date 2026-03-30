# Tak_OS · wlogout.nix — Wlogout theme deployment
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#                          Wlogout Theme Module
# =============================================================================
#
# Loaded exclusively when features.hyprland = true (see configuration.nix).
#
# Deploys the wlogout theme selected by features.hypr.logoutTheme to
# ~/.config/wlogout/ for every user in features.home-manager-users.
# The deployment runs on every rebuild, keeping the config in sync with the
# chosen profile.
#
# Available profiles  (assets: /etc/nixos/assets/wlogout/<profile>/):
#   "default"     — Rounded icon buttons, wallust colour import (LinuxBeginnings)
#   "catppuccin"  — Catppuccin Mocha / Mauve with SVG icons
#   "minimal"     — Minimal dark style using NixOS system wlogout icons
#   "end4"        — Material Symbols Outlined font icons (end-4/dots-hyprland)
#
# Wlogout package installation is gated by features.hypr.logout in
# modules/system-packages.nix; this module handles only the config files.
#
# =============================================================================
{ lib, pkgs, features, ... }:

lib.mkIf (features.hyprland && features.hypr.logout)
(
  let
    profile = features.hypr.logoutTheme;

    # Import the theme directory into the Nix store at evaluation time.
    # builtins.path copies the directory to the store without a builder,
    # so the sandbox restriction doesn't apply — the path is evaluated on
    # the host where /etc/nixos is accessible.
    themeDir = builtins.path {
      name = "wlogout-theme-${profile}";
      path = /etc/nixos/assets/wlogout + "/${profile}";
    };
  in
  {
    assertions = [{
      assertion = builtins.elem profile [ "default" "catppuccin" "minimal" "end4" ];
      message   = ''
        features.hypr.logoutTheme must be one of:
          "default"  "catppuccin"  "minimal"  "end4"
        Got: "${profile}"
      '';
    }];

    system.activationScripts.wlogout-theme = {
      deps = [];
      text = lib.concatMapStrings (user:
        let
          dest = "/home/${user}/.config/wlogout";
        in ''
          echo "[wlogout] Deploying theme '${profile}' for ${user}..."
          rm -rf ${dest}
          cp -r ${themeDir} ${dest}
          chown -R ${user}:users ${dest} 2>/dev/null || true
          chmod -R u+w ${dest}
        ''
      ) features.home-manager-users;
    };
  }
)
