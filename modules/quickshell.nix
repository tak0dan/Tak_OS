{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.quickshell
  ];
}
