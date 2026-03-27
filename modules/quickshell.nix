# Tak_OS · quickshell.nix — Quickshell Wayland shell widget layer
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.quickshell
  ];
}
