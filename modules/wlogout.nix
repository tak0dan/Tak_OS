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
    validThemes = [ "default" "catppuccin" "minimal" "end4" ];
    defaultTheme = features.hypr.logoutTheme;
    overrides = features.hypr.userLogoutThemes or {};

    # Resolve the theme for a given user: per-user override → global default.
    userTheme = user: overrides.${user} or defaultTheme;

    # Build a store path for a theme directory (evaluated once per unique theme).
    themeDir = profile: builtins.path {
      name = "wlogout-theme-${profile}";
      path = /etc/nixos/assets/wlogout + "/${profile}";
    };
  in
  {
    assertions =
      # Validate global default.
      [{
        assertion = builtins.elem defaultTheme validThemes;
        message   = ''
          features.hypr.logoutTheme must be one of:
            "default"  "catppuccin"  "minimal"  "end4"
          Got: "${defaultTheme}"
        '';
      }]
      # Validate every per-user override.
      ++ lib.concatMap (user:
        let t = overrides.${user} or null; in
        lib.optional (t != null) {
          assertion = builtins.elem t validThemes;
          message   = ''
            features.hypr.userLogoutThemes.${user} must be one of:
              "default"  "catppuccin"  "minimal"  "end4"
            Got: "${t}"
          '';
        }
      ) features.home-manager-users;

    system.activationScripts.wlogout-theme = {
      deps = [];
      text = lib.concatMapStrings (user:
        let
          profile = userTheme user;
          dest    = "/home/${user}/.config/wlogout";
        in ''
          echo "[wlogout] Deploying theme '${profile}' for ${user}..."
          # Always ensure ~/.config exists and is user-owned before copying.
          # If a previous (failed) run created it as root, the conditional
          # guard would have been skipped — so we unconditionally fix it here.
          _hm_cfg="/home/${user}/.config"
          mkdir -p "$_hm_cfg"
          chown ${user}:users "$_hm_cfg"
          chmod 700 "$_hm_cfg"
          rm -rf ${dest}
          cp -r ${themeDir profile} ${dest}
          chown -R ${user}:users ${dest} 2>/dev/null || true
          chmod -R u+w ${dest}
        ''
      ) features.home-manager-users;
    };
  }
)
