# Tak_OS · system-packages.nix — Global system packages — conditionally loaded per feature
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# SYSTEM-PACKAGES.NIX — environment.systemPackages assembly + package filtering
# ==============================================================================
# Assembles the full system package list from feature-gated package files.
#
# Filtering is two-layered:
#   filterPkgs              — filters against packages/disabled/disabled-packages.nix
#   config.kool.disabledPackages — NixOS option; set directly in configuration.nix
#                             for quick one-off overrides without touching the file
#
# Package files:
#   packages/all-packages.nix   — always installed
#   packages/kde.nix            — features.kde
#   packages/hyprland.nix       — features.hyprland
#   packages/games.nix          — features.steam
#
# Nixorcist is packaged independently under packages/nixorcist.

{ config, pkgs, lib, features, filterPkgs, ... }:
{
  options.kool.disabledPackages = lib.mkOption {
    type        = lib.types.listOf lib.types.str;
    default     = [];
    description = ''
      Extra package names to exclude from all package groups globally.
      Set directly in configuration.nix for quick one-off overrides.
      Keep permanent exclusions in packages/disabled/disabled-packages.nix.
    '';
  };

  config =
    let
      extraFilter = list: builtins.filter
        (pkg: !(builtins.elem (lib.getName pkg) config.kool.disabledPackages))
        list;
      filter = list: extraFilter (filterPkgs list);
    in
    {
      environment.systemPackages =

        # Global packages (always installed regardless of features)
        filter (import ../packages/all-packages.nix { inherit pkgs; })

        # Feature-gated package groups
        ++ lib.optionals features.kde
          (filter (import ../packages/kde.nix { inherit pkgs; }))

        ++ lib.optionals features.hyprland
          (filter (import ../packages/hyprland.nix { inherit pkgs; }))

        # nixos-hyprland integration packages
        ++ lib.optionals features.hyprland
          (filter (import ../packages/nixos-hyprland.nix { inherit pkgs; }))

        ++ lib.optionals features.steam
          (filter (import ../packages/games.nix { inherit pkgs; }))

        ++ lib.optionals features.uwuPackages
          (filter (import ../packages/uwu.nix { inherit pkgs; }))

        # ── Hyprland sub-feature packages ────────────────────────────────────
        # Extracted from hyprland.nix / nixos-hyprland.nix so that each
        # can be toggled independently via features.<name> in configuration.nix.
        ++ lib.optionals (features.hyprland && features.hypr.lock.enable)
          (filter [ pkgs.hyprlock ])

        ++ lib.optionals (features.hyprland && features.hypr.idle)
          (filter [ pkgs.hypridle ])

        ++ lib.optionals (features.hyprland && features.hypr.bar)
          (filter [ pkgs.waybar ])

        ++ lib.optionals (features.hyprland && features.hypr.notif)
          (filter [ pkgs.swaynotificationcenter ])

        ++ lib.optionals (features.hyprland && features.hypr.logout)
          (filter [ pkgs.wlogout ])

        ++ lib.optionals (features.hyprland && features.hypr.launcher)
          (filter [ pkgs.rofi ])

        # Always-installed system utilities
        ++ [
          pkgs.kdePackages.polkit-kde-agent-1
          pkgs.kdePackages.kio-admin
          pkgs.hyprland-qt-support

        ]

        ++ lib.optionals features.nixorcist [
          (pkgs.callPackage ../packages/nixorcist { })
        ];
    };
}
