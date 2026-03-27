# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# Nvidia kernel-level parameters only.
# All hardware.nvidia.* configuration lives in nvidia-drivers.nix.
# These two modules are designed to be used together:
#   kernelParams = "nvidia"  +  gpu = "nvidia"
#   kernelParams = "nvidia"  +  gpu = "nvidia-prime"
#
{ config, lib, ... }:

with lib;
let
  cfg = config.kernel-params.nvidia;
in
{
  options.kernel-params.nvidia = {
    enable = mkEnableOption "Nvidia kernel parameters (DRM modesetting, initrd modules)";
  };

  config = mkIf cfg.enable {

    boot.kernel.sysctl = {
      "kernel.sysrq"  = 1;
      "kernel.panic"  = 10;
    };

    # Load nvidia modules early so DRM is available before display manager starts
    boot.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    boot.initrd.availableKernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    boot.kernelParams = [ "nvidia_drm.modeset=1" ];

    # Cold boot GPU fix — PCI rescan + rebind in initrd
    # Replace 0000:01:00.0 with your actual GPU PCI address (lspci | grep -i nvidia)
    boot.initrd.preDeviceCommands = ''
      echo "[Initrd] Triggering PCI rescan"
      echo 1 > /sys/bus/pci/rescan

      GPU="0000:01:00.0"
      echo $GPU > /sys/bus/pci/drivers/nvidia/unbind || true
      sleep 0.5
      echo $GPU > /sys/bus/pci/drivers/nvidia/bind || true

      echo "[Initrd] NVIDIA GPU rebind done"
    '';

    hardware.enableRedistributableFirmware = true;
  };
}
