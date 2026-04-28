# Tak_OS · gpu.nix — GPU driver selector — routes to the right driver module
# github.com/tak0dan/Tak_OS · GNU GPLv3
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
#   kernelParams = "amd"     +  driver = "amd"            — generic AMD system
#   kernelParams = "alurin"  +  driver = "alurin"         — Alurin AMD host profile
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
    ./kernel-params-alurin.nix

    # Driver modules — userspace/display only, no boot.kernelModules
    ./amd-drivers.nix
    ./intel-drivers.nix
    ./nvidia-drivers.nix
    ./nvidia-prime-drivers.nix
  ];

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

    # -------------------------------------------------------------------------
    # Kernel parameter profiles — exactly one active at a time
    # -------------------------------------------------------------------------
    kernel-params.generic.enable  = kp == "generic";
    kernel-params.thinkpad.enable = kp == "thinkpad";
    kernel-params.nvidia.enable   = kp == "nvidia";
    kernel-params.amd.enable      = kp == "amd";
    kernel-params.alurin.enable   = kp == "alurin";

    # -------------------------------------------------------------------------
    # Driver profiles — at most one active, "none" activates nothing
    # -------------------------------------------------------------------------
    drivers.amdgpu.enable        = drv == "amd" || drv == "alurin";
    drivers.intel.enable         = drv == "intel";
    drivers.nvidia.enable        = drv == "nvidia" || drv == "nvidia-prime";
    drivers.nvidia-prime.enable  = drv == "nvidia-prime";
  };
}
