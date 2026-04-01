# Tak_OS · intel-drivers.nix — Intel GPU driver stack (i915 + intel-media-driver)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.drivers.intel;
in {
  options.drivers.intel = {
    enable = mkEnableOption "Enable Intel Graphics Drivers";
  };

  config = mkIf cfg.enable {
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
    };

    hardware.graphics = {
      extraPackages = with pkgs; [
        intel-media-driver
        libvdpau-va-gl
        libva
        libva-utils
      ];
    };
  };
}
