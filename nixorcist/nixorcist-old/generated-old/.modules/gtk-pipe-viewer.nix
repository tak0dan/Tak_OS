{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gtk-pipe-viewer
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: gtk-pipe-viewer
