# Tak_OS · home-manager-layer.nix — Conditional Home Manager import hub
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ lib, features, ... }:
{
  imports =
    lib.optionals features.home-manager [
      <home-manager/nixos>
      ./hm-users.nix
    ];
}
