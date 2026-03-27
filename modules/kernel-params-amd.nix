# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.kernel-params.amd;
in
{
  options.kernel-params.amd = {
    enable = mkEnableOption "Generic AMD kernel parameters";
  };

  config = mkIf cfg.enable {

    boot.kernel.sysctl = {
      "kernel.sysrq"          = 1;
      "kernel.panic"          = 10;
      "vm.swappiness"         = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    boot.kernelParams = [
      "amd_iommu=on"                    # enable AMD IOMMU (improves isolation)
      "iommu=pt"                        # passthrough mode (better perf, needed for VFIO)
      "amdgpu.ppfeaturemask=0xffffffff" # expose all power/clock tuning knobs
    ];

    boot.kernelModules = [ "amdgpu" ];

    hardware.cpu.amd.updateMicrocode = true;

    hardware.enableRedistributableFirmware = true;
  };
}
