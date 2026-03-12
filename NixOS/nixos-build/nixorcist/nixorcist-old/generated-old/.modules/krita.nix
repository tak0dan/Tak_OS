{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    krita
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: krita
