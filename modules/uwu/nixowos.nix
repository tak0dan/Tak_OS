# =============================================================================
#                           NixOwOS Integration (uwu)
# =============================================================================
#
# Applies NixOwOS branding without importing the full NixOwOS flake.
#
#   os-release  Sets distroId / distroName / vendorId / vendorName so the
#               running system identifies as NixOwOS in /etc/os-release.
#               Mirrors src/os-release.nix from the NixOwOS repo.
#               ID_LIKE = "nixos" is emitted automatically by NixOS when
#               distroId != "nixos", so no extra arg is needed.
#
#   fastfetch   Patches the NixOwOS ASCII logo into fastfetch.
#               Patch sourced from overlays/fastfetch/ in the NixOwOS repo
#               and stored locally at modules/uwu/create_nixowos_logo.patch.
#
# Disabling features.uwu in configuration.nix removes this module from the
# import list entirely, reverting every change made here automatically.
#
# =============================================================================
{ lib, ... }:
{
  # OS identity
  system.nixos = {
    distroId   = lib.mkDefault "nixowos";
    distroName = lib.mkDefault "NixOwOS";
    vendorId   = lib.mkDefault "nixowos";
    vendorName = lib.mkDefault "NixOwOS";
  };

  # Patch fastfetch with the NixOwOS ASCII logo
  nixpkgs.overlays = [
    (final: prev: {
      fastfetch = prev.fastfetch.overrideAttrs (old: {
        patches = (old.patches or []) ++ [ ./create_nixowos_logo.patch ];
      });
    })
  ];
}
