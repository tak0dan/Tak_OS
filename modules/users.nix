# Tak_OS · users.nix — Declarative user hub
# github.com/tak0dan/Tak_OS · GNU GPLv3
# Loads declarative per-user declarations from users-declared/.
{ ... }:
{
  imports = [ ../users-declared/default.nix ];
}
