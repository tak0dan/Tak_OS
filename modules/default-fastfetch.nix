# Tak_OS · default-fastfetch.nix — Plain NixOS fastfetch logo wrapper
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#                        Default fastfetch (uwu = false)
# =============================================================================
#
# Provides a fastfetch wrapper that uses the built-in "NixOS" logo when the
# uwu feature is disabled.  The selection is owned by modules/branding-layer.nix,
# which keeps this wrapper mutually exclusive with modules/uwu/nixowos.nix so
# only one `fastfetch` binary is present at a time.
#
# =============================================================================
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.fastfetch ];
}
