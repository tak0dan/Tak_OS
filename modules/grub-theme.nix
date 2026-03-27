# Tak_OS · grub-theme.nix — GRUB visual theme
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, ... }:

{
  # example GRUB tweak
  boot.loader.grub.configurationLimit = 10;
}
