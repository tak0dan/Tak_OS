{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    adw-bluetooth
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: adw-bluetooth
