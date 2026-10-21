# Tak_OS · hyprlock.nix — Screen lock integration (hyprlock + hypridle config)
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#                         Hyprlock / Hypridle Module
# =============================================================================
#
# Loaded exclusively when features.hyprland = true (see configuration.nix).
#
# Responsibilities:
#   • validates the declarative hypridle/hyprlock feature surface
#   • leaves actual per-user file management to Home Manager
#
# =============================================================================
{ lib, features, ... }:

lib.mkIf features.hyprland {
  assertions = [
    {
      assertion = (!features.hypr.idle && !features.hypr.lock.enable) || features.home-manager;
      message = ''
        Hypridle/Hyprlock user configuration is managed declaratively via Home Manager.
        Enable features.home-manager or disable features.hypr.idle / features.hypr.lock.enable.
      '';
    }
    {
      assertion = features.hypr.lock.timeout >= 60;
      message = "features.hypr.lock.timeout must be at least 60 seconds.";
    }
  ];
}
