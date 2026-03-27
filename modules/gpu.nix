# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# GPU.NIX — Hardware profile selector
# ====================================
# Two fully independent profiles, set separately in configuration.nix:
#
#   gpu.kernelParams  — which kernel-level parameters to apply (mandatory)
#   gpu.driver        — which GPU driver module to activate (optional, "none" = no driver)
#
# These two profiles are intentionally decoupled:
#   - Kernel params are boot-time hardware tuning (boot.*, cpu.*, firmware)
#   - Drivers are userspace/display configuration (hardware.nvidia.*, videoDrivers, etc.)
#   - No kernel-params module sets hardware.nvidia.* or services.xserver.videoDrivers
#   - No driver module sets boot.kernelModules or boot.kernelParams
#
# Typical combinations:
#   kernelParams = "nvidia"  +  driver = "nvidia"         — standalone Nvidia
#   kernelParams = "nvidia"  +  driver = "nvidia-prime"   — Nvidia PRIME hybrid
#   kernelParams = "thinkpad" + driver = "none"           — ThinkPad T480 (Intel built-in)
#   kernelParams = "amd"     +  driver = "amd"            — AMD system
#   kernelParams = "generic" +  driver = "intel"          — generic Intel box
#   kernelParams = "generic" +  driver = "none"           — no dedicated GPU
#
{ lib, config, ... }:
let
  kp  = config.gpu.kernelParams;
  drv = config.gpu.driver;
in
{
  imports = [
    # Kernel parameter modules — boot-time only, no hardware.nvidia.*
    ./kernel-params-generic.nix
    ./kernel-params-thinkpad.nix
    ./kernel-params-nvidia.nix
    ./kernel-params-amd.nix

    # Driver modules — userspace/display only, no boot.kernelModules
    ./amd-drivers.nix
    ./intel-drivers.nix
    ./nvidia-drivers.nix
    ./nvidia-prime-drivers.nix
  ];

  options.gpu = {

    kernelParams = lib.mkOption {
      type = lib.types.enum [ "generic" "thinkpad" "nvidia" "amd" ];
      default = "generic";
      description = ''
        Kernel parameter profile. Mandatory — "generic" is the safe default.

          "generic"   Sane defaults for any hardware (sysrq, panic, swappiness, firmware)
          "thinkpad"  ThinkPad T480 — i915 GuC/HuC, Intel microcode, power-profiles-daemon
          "nvidia"    Nvidia — DRM modesetting, nvidia modules in initrd, cold-boot fix
          "amd"       AMD — amd_iommu, ppfeaturemask, AMD microcode, amdgpu early load
      '';
    };

    driver = lib.mkOption {
      type = lib.types.enum [ "none" "amd" "intel" "nvidia" "nvidia-prime" ];
      default = "none";
      description = ''
        GPU driver profile. "none" loads no driver module.

          "none"         No GPU driver (VM, headless, or hardware with built-in driver)
          "amd"          AMD discrete/integrated — amdgpu videoDriver + VA-API packages
          "intel"        Intel integrated — intel-media-driver + VA-API packages
          "nvidia"       Nvidia discrete — nvidia videoDriver + full hardware.nvidia config
          "nvidia-prime" Nvidia + Intel PRIME hybrid offload (generic, not T480-specific)

        Note: "nvidia" and "nvidia-prime" pair with kernelParams = "nvidia".
              "amd" pairs with kernelParams = "amd".
              "intel" pairs with kernelParams = "generic" or "thinkpad".
      '';
    };
  };

  config = {
    # -------------------------------------------------------------------------
    # Kernel parameter profiles — exactly one active at a time
    # -------------------------------------------------------------------------
    kernel-params.generic.enable  = kp == "generic";
    kernel-params.thinkpad.enable = kp == "thinkpad";
    kernel-params.nvidia.enable   = kp == "nvidia";
    kernel-params.amd.enable      = kp == "amd";

    # -------------------------------------------------------------------------
    # Driver profiles — at most one active, "none" activates nothing
    # -------------------------------------------------------------------------
    drivers.amdgpu.enable        = drv == "amd";
    drivers.intel.enable         = drv == "intel";
    drivers.nvidia.enable        = drv == "nvidia" || drv == "nvidia-prime";
    drivers.nvidia-prime.enable  = drv == "nvidia-prime";
  };
}
