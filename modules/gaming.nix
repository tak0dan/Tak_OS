# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# GAMING.NIX — Steam + GameMode
# ==============================
# Activated when features.steam = true (set in configuration.nix).
#
#   programs.steam            — Steam with Gamescope session support
#   programs.gamemode         — performance CPU governor on game launch
#
# User packages (Lutris, Heroic, MangoHud, etc.) live in packages/games.nix
# and are assembled by modules/system-packages.nix.

{ lib, features, ... }:
{
  programs.steam = lib.mkIf features.steam {
    enable               = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode.enable = features.steam;
}
