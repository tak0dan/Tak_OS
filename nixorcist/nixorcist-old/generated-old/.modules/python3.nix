{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python3
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: python3
