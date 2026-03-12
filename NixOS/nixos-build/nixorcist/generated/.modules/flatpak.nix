{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    flatpak
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: flatpak
