# Tak_OS · nvidia-drivers.nix — Nvidia GPU driver stack (proprietary)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.drivers.nvidia;
in {
  options.drivers.nvidia = {
    enable = mkEnableOption "Enable Nvidia Drivers";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = ["nvidia"];

    hardware.graphics = {
      # enable + enable32Bit set in hardware-graphics.nix (unconditional)
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau
        libvdpau-va-gl
        nvidia-vaapi-driver
        vdpauinfo
        libva
        libva-utils
      ];
    };

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      nvidiaPersistenced = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
  };
}
