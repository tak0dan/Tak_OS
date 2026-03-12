{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pnpm
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: pnpm
