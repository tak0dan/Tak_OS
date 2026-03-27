# Tak_OS · bootloader.nix — GRUB / systemd-boot configuration
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, ... }:

{
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      # useOSProber = true;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
}
