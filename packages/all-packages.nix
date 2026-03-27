{ pkgs }:

# =============================================================================
# All Packages — complete package set
# =============================================================================
# Every package-list file in this directory is imported here.
# Feature-gated groups (hyprland, kde, games) are ALSO imported separately in
# configuration.nix under lib.optionals so they can be toggled independently.
#
# NOTE: zsh.nix is a NixOS module (not a package list) — imported via
#       configuration.nix imports, not here.
# =============================================================================

let
  core    = import ./core.nix            { inherit pkgs; };
  dev     = import ./development.nix     { inherit pkgs; };
  comms   = import ./communication.nix   { inherit pkgs; };
  browsers = import ./browsers.nix       { inherit pkgs; };
  media   = import ./media.nix           { inherit pkgs; };
  hypr    = import ./hyprland.nix        { inherit pkgs; };
  kde     = import ./kde.nix             { inherit pkgs; };
  games   = import ./games.nix           { inherit pkgs; };
  wm      = import ./window-managers.nix { inherit pkgs; };
  simplex = import ./simplex-chat.nix    { inherit pkgs; };
  mess = import ./pkg-dump.nix           { inherit pkgs; };

  weather = [ (pkgs.callPackage ./waybar-weather.nix {}) ];
  nixhl   = import ./nixos-hyprland.nix  { inherit pkgs; };

  # eclipse = import ./eclipse.nix { inherit pkgs; }; # Not finished yet

in

builtins.concatLists [
  core
  dev
  comms
  browsers
  media
  hypr
  kde
  games
  wm
  simplex
  weather
  mess
  nixhl
]
