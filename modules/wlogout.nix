# Tak_OS · wlogout.nix — Wlogout theme deployment
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#                          Wlogout Theme Module
# =============================================================================
#
# Loaded exclusively when features.hyprland = true (see configuration.nix).
#
# Validates the selected wlogout themes. Actual per-user file management is
# handled declaratively via Home Manager.
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
{ lib, features, ... }:

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
      path = ../assets/wlogout + "/${profile}";
    };
  in
  {
    assertions =
      [{
        assertion = !features.hypr.logout || features.home-manager;
        message = ''
          Wlogout theme deployment is managed declaratively via Home Manager.
          Enable features.home-manager or disable features.hypr.logout.
        '';
      }
      # Validate global default.
      {
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
  }
)
