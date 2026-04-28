# Tak_OS · gameon-layer.nix — Conditional GameOn import hub
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ lib, features, ... }:
{
  imports = lib.optionals features.gameon.enable [ ./gameon.nix ];
}
