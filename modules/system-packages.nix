# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# SYSTEM-PACKAGES.NIX — environment.systemPackages assembly + package filtering
# ==============================================================================
# Assembles the full system package list from feature-gated package files.
#
# Filtering is two-layered:
#   filterPkgs              — filters against packages/disabled/disabled-packages.nix
#                             (managed by nixos-comment / nixos-uncomment CLI tools)
#   config.kool.disabledPackages — NixOS option; set directly in configuration.nix
#                             for quick one-off overrides without touching the file
#
# Package files:
#   packages/all-packages.nix   — always installed
#   packages/kde.nix            — features.kde
#   packages/hyprland.nix       — features.hyprland
#   packages/games.nix          — features.steam
#
# Inline CLI tools defined here:
#   nixorcist           — wrapper for /etc/nixos/nixorcist/nixorcist.sh
#   nixos-comment       — disable a package system-wide (adds to disabled-packages.nix)
#   nixos-uncomment     — re-enable a package (removes from disabled-packages.nix)
#   nixos-smart-rebuild — wrapper for scripts/nix-rebuild-smart.sh

{ config, pkgs, lib, features, filterPkgs, ... }:
{
  options.kool.disabledPackages = lib.mkOption {
    type        = lib.types.listOf lib.types.str;
    default     = [];
    description = ''
      Extra package names to exclude from all package groups globally.
      Set directly in configuration.nix for quick one-off overrides.
      For permanent changes, use nixos-comment / nixos-uncomment instead.
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

        # ── GameOn packages ─────────────────────────────────────────────────
        ++ lib.optionals features.gameon.enable
          (import ../packages/gameon.nix { inherit pkgs features; })

        # Always-installed system utilities
        ++ [
          pkgs.kdePackages.polkit-kde-agent-1
          pkgs.kdePackages.kio-admin
          pkgs.hyprland-qt-support

          # nixorcist CLI wrapper
          (pkgs.writeShellScriptBin "nixorcist" ''
            exec /etc/nixos/nixorcist/nixorcist.sh "$@"
          '')

          # Package toggle tooling
          # Usage: nixos-comment discord   → disables discord system-wide
          #        nixos-uncomment discord → re-enables it
          (pkgs.writeShellScriptBin "nixos-comment" ''
            set -euo pipefail
            FILE="/etc/nixos/packages/disabled/disabled-packages.nix"
            PKG="$1"
            if [[ -z "$PKG" ]]; then echo "Usage: nixos-comment <package>"; exit 1; fi
            grep -q "\"$PKG\"" "$FILE" && { echo "[!] $PKG already disabled"; exit 0; }
            sed -i "/\[/a\  \"$PKG\"" "$FILE"
            echo "[✓] Disabled $PKG"
            echo "[*] Run: nixos-smart-rebuild"
          '')

          (pkgs.writeShellScriptBin "nixos-uncomment" ''
            set -euo pipefail
            FILE="/etc/nixos/packages/disabled/disabled-packages.nix"
            PKG="$1"
            if [[ -z "$PKG" ]]; then echo "Usage: nixos-uncomment <package>"; exit 1; fi
            sed -i "/\"$PKG\"/d" "$FILE"
            echo "[✓] Enabled $PKG"
            echo "[*] Run: nixos-smart-rebuild"
          '')

          (pkgs.writeShellScriptBin "nixos-smart-rebuild" ''
            exec /etc/nixos/scripts/nix-rebuild-smart.sh "$@"
          '')
        ];
    };
}
