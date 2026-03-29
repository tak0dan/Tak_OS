# Tak_OS · nixowos.nix — NixOwOS branding overlay — os-release + fastfetch logo
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#                           NixOwOS Integration (uwu)
# =============================================================================
#
# Applies NixOwOS branding without importing the full NixOwOS flake.
#
# All credits to yunfachi — original dots and assets:
#   https://github.com/yunfachi/NixOwOS   (MIT licence)
#
#   os-release  Sets distroId / distroName / vendorId / vendorName so the
#               running system identifies as NixOwOS in /etc/os-release.
#               Mirrors src/os-release.nix from the NixOwOS repo.
#               ID_LIKE = "nixos" is set explicitly so tools that check
#               distro family still detect a NixOS-compatible system.
#
#   fastfetch   Patches fastfetch at build time (create_nixowos_logo.patch)
#               to register "NixOwOS" as a built-in logo with plain ANSI
#               colour codes (34=blue, 94=bright-blue, etc.).  No RGB values
#               are injected at runtime — kitty remaps the ANSI palette
#               through its active theme automatically, so the logo changes
#               colour in sync with the terminal (and the starship prompt)
#               whenever the kitty theme changes.
#
# Colour slot mapping (matches the $N markers in the built-in logo):
#   $1  main body (left)      ANSI 34  — blue       → kitty color4
#   $2  main body (right)     ANSI 94  — bright-blue → kitty color12
#   $3  paw /// marks         ANSI 31  — red         → kitty color1
#   $4  centre gem            ANSI 33  — yellow      → kitty color3
#   $5  small accent triangle ANSI 35  — magenta     → kitty color5
#
# Disabling features.uwu in configuration.nix removes this module from the
# import list entirely, reverting every change made here automatically.
#
# =============================================================================
{ lib, pkgs, ... }:
let
  # Patch fastfetch to register "NixOwOS" as a built-in logo (canonical
  # NixOwOS approach: overlays/fastfetch/default.nix from yunfachi/NixOwOS).
  # The patch uses plain ANSI codes so kitty's active theme palette is applied
  # automatically — no runtime colour injection needed.
  patchedFastfetch = pkgs.fastfetch.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ../../assets/UwU/create_nixowos_logo.patch ];
  });

  fastfetchWrapper = pkgs.writeShellScriptBin "fastfetch" ''
    exec ${patchedFastfetch}/bin/fastfetch --logo "NixOwOS" "$@"
  '';
in
{
  # OS identity — mirrors src/os-release.nix from the NixOwOS repo (yunfachi)
  system.nixos = {
    distroId   = lib.mkDefault "nixowos";
    distroName = lib.mkDefault "NixOwOS";
    vendorId   = lib.mkDefault "nixowos";
    vendorName = lib.mkDefault "NixOwOS";
    extraOSReleaseArgs.ID_LIKE = lib.mkDefault "nixos";
  };

  # Install only the wrapper.  The patched fastfetch binary is called by its
  # Nix store path inside the script, so it never needs to be on PATH itself.
  #
  # Revert guarantee: this module is loaded exclusively via
  #   lib.optionals features.uwu [ ./modules/uwu/nixowos.nix ]
  # in configuration.nix.  Setting features.uwu = false removes the import
  # entirely, which undoes every setting below in one rebuild:
  #   • system.nixos.distroId / distroName / vendorId / vendorName → NixOS defaults
  #   • the fastfetch wrapper is removed from PATH
  environment.systemPackages = [ fastfetchWrapper ];
}
