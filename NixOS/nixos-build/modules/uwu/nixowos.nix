# =============================================================================
#                               NixOwOS Integration
# =============================================================================
#
# Loads the NixOwOS flake module while keeping configuration modular.
#
# Enabled through configuration.nix toggle:
#   systemUwUfied = true;
#
# =============================================================================
{ config, pkgs, lib, ... }:

let
  nixowos = builtins.getFlake "github:yunfachi/nixowos";
in
{
  imports = [
    nixowos.nixosModules.default
  ];

  nixowos = {
    enable = true;

    # Prevent nixpkgs overlay recursion
    overlays.enable = false;
  };
}
