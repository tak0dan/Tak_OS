# Tak_OS · bluetooth.nix — Bluetooth stack (blueman + hardware enable)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs, ... }:

{
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    overskride
  ];
}
