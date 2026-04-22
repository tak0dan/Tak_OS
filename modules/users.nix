# Tak_OS · users.nix — Declarative user hub
# github.com/tak0dan/Tak_OS · GNU GPLv3
# Loads installer-generated per-user declarations from users-declared/.
{ lib, ... }:

{
  imports = lib.optionals (builtins.pathExists ../users-declared/default.nix) [
    ../users-declared/default.nix
  ];
}
