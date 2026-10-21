# Tak_OS · gpu.nix — GPU driver selector — routes to the right driver module
# https://github.com/tak0dan/Tak_OS
# This module defines GPU kernel param and driver options, and assertions
# The actual kernel parameter configuration is managed by modules/kernel-params*.nix
{ lib, config, ... }:
let
  kp  = config.gpu.kernelParams;
  drv = config.gpu.driver;
in
{
  options.gpu = {
    kernelParams = lib.mkOption {
      type = lib.types.enum [ "generic" "thinkpad" "nvidia" "amd" "alurin" ];
      default = "generic";
      description = ''
        Kernel parameter profile. Mandatory — "generic" is the safe default.

          "generic"   Sane defaults for any hardware (sysrq, panic, swappiness, firmware)
          "thinkpad"  ThinkPad T480 — i915 GuC/HuC, Intel microcode, power-profiles-daemon
          "nvidia"    Nvidia — DRM modesetting, nvidia modules in initrd, cold-boot fix
          "amd"       AMD — amd_iommu, ppfeaturemask, AMD microcode, amdgpu early load
          "alurin"    AMD host profile derived from hardware-configuration-dani.nix
      '';
    };

    driver = lib.mkOption {
      type = lib.types.enum [ "none" "amd" "intel" "nvidia" "nvidia-prime" "alurin" ];
      default = "none";
      description = ''
        GPU driver profile. "none" loads no driver module.

        "none"         No GPU driver (VM, headless, or hardware with built-in driver)
        "amd"          AMD discrete/integrated — amdgpu videoDriver + VA-API packages
        "alurin"      Alurin AMD host profile — reuses amdgpu userspace stack
        "intel"        Intel integrated — intel-media-driver + VA-API packages
        "nvidia"       Nvidia discrete — nvidia videoDriver + full hardware.nvidia config
        "nvidia-prime" Nvidia + Intel PRIME hybrid offload (generic, not T480-specific)

        Note: "nvidia" and "nvidia-prime" pair with kernelParams = "nvidia".
              "amd" pairs with kernelParams = "amd".
              "alurin" pairs with kernelParams = "alurin".
              "intel" pairs with kernelParams = "generic" or "thinkpad".
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = drv != "amd" || kp == "amd";
        message = ''
          GPU profile "amd" requires kernelParams = "amd".
          Update graph.platform.kernelProfile / features.kernelParams to match.
        '';
      }
      {
        assertion = !(builtins.elem drv [ "nvidia" "nvidia-prime" ]) || kp == "nvidia";
        message = ''
          GPU profiles "nvidia" and "nvidia-prime" require kernelParams = "nvidia".
          Update graph.platform.kernelProfile / features.kernelParams to match.
        '';
      }
      {
        assertion = drv != "intel" || builtins.elem kp [ "generic" "thinkpad" ];
        message = ''
          GPU profile "intel" requires kernelParams = "generic" or "thinkpad".
          Update graph.platform.kernelProfile / features.kernelParams to match.
        '';
      }
      {
        assertion = drv != "alurin" || kp == "alurin";
        message = ''
          GPU profile "alurin" requires kernelParams = "alurin".
          Update graph.platform.kernelProfile / features.kernelParams to match.
        '';
      }
    ];
  };
}