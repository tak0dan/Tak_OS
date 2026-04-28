# Tak_OS · kernel-params-alurin.nix — Conservative AMD host profile from hardware-configuration-dani.nix
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Derived from:
#   /run/media/tak_1/Ventoy/hardware-configuration-dani.nix
#
# Facts available from that hardware scan:
#   - AMD CPU (`kvm-amd`)
#   - x86_64 host
#   - no explicit discrete-GPU module hints in the generated file
#
# This profile therefore stays intentionally conservative:
#   - keep the standard recovery / VM sysctl defaults,
#   - enable the AMD host/kernel modules we can justify from the scan,
#   - avoid aggressive tuning that assumes VFIO, overclocking, or a specific APU.
{ config, lib, ... }:

with lib;
let
  cfg = config.kernel-params.alurin;
in
{
  options.kernel-params.alurin = {
    enable = mkEnableOption "Alurin AMD host kernel parameters";
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl = {
      "kernel.sysrq"          = 1;
      "kernel.panic"          = 10;
      "vm.swappiness"         = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    boot.kernelModules = [
      "kvm-amd"
      "amdgpu"
    ];

    hardware.cpu.amd.updateMicrocode = true;
    hardware.enableRedistributableFirmware = true;
  };
}
