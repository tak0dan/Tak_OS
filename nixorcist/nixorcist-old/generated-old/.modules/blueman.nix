{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    blueman
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: blueman
