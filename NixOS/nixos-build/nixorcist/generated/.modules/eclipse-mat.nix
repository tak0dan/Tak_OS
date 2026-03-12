{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    eclipse-mat
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: eclipse-mat
