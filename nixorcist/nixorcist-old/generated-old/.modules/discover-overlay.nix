{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    discover-overlay
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: discover-overlay
