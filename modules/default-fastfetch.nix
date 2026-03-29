# Tak_OS · default-fastfetch.nix — Plain NixOS fastfetch logo wrapper
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#                        Default fastfetch (uwu = false)
# =============================================================================
#
# Provides a fastfetch wrapper that uses the built-in "NixOS" logo when the
# uwu feature is disabled.  Loaded exclusively via:
#
#   lib.optionals (!features.uwu) [ ./modules/default-fastfetch.nix ]
#
# in configuration.nix.  When features.uwu = true, modules/uwu/nixowos.nix
# is loaded instead, providing its own fastfetch wrapper with the NixOwOS logo.
# Having exactly one wrapper active at a time avoids binary collisions.
#
# =============================================================================
{ pkgs, ... }:
let
  fastfetchWrapper = pkgs.writeShellScriptBin "fastfetch" ''
    exec ${pkgs.fastfetch}/bin/fastfetch --logo "NixOS" "$@"
  '';
in
{
  environment.systemPackages = [ fastfetchWrapper ];
}
