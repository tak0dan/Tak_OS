{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    docker
  ];
}

#$nixorcist$#
# NIXORCIST-ATTRPATH: docker
