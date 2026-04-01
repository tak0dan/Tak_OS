# Tak_OS · gaming.nix — Gaming stack — Steam, gamemode, mangohud
# github.com/tak0dan/Tak_OS · GNU GPLv3
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
