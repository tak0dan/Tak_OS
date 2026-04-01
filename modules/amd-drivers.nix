# Tak_OS · amd-drivers.nix — AMD GPU driver stack (amdgpu + VA-API)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.drivers.amdgpu;
in {
  options.drivers.amdgpu = {
    enable = mkEnableOption "Enable AMD Drivers";
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = ["L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"];
    services.xserver.videoDrivers = ["amdgpu"];

    hardware.graphics = {
      extraPackages = with pkgs; [
        libva
        libva-utils
      ];
    };
  };
}
