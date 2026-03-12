{ config, pkgs, ... }:

{
  networking.hostName = "Tak0_NixOS";
  networking.networkmanager.enable = true;
}
