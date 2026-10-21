# Tak_OS · branding-layer.nix — Mutually exclusive branding import hub
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ lib, features, ... }:
{
  imports =
    lib.optionals features.uwu [
      ./uwu/nixowos.nix
    ]
    ++ lib.optionals (!features.uwu) [
      ./default-fastfetch.nix
    ];
}
