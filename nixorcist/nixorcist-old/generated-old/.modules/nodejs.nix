{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nodejs
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: nodejs
