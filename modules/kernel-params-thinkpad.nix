# Tak_OS · kernel-params-thinkpad.nix — Kernel parameters for ThinkPad (i915 GuC/HuC + power)
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# ThinkPad T480 kernel-level parameters and Intel CPU/GPU tuning.
# Does not configure any GPU driver (Intel graphics are built-in).
# hardware.graphics.* is set unconditionally in configuration.nix.
#
{ config, lib, ... }:

with lib;
let
  cfg = config.kernel-params.thinkpad;
in
{
  options.kernel-params.thinkpad = {
    enable = mkEnableOption "ThinkPad T480 kernel parameters and Intel GPU tuning";
  };

  config = mkIf cfg.enable {

    boot.kernel.sysctl = {
      "kernel.sysrq"          = 1;
      "kernel.panic"          = 10;
      "vm.swappiness"         = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    # i915: enable GuC/HuC firmware, faster display init, framebuffer compression
    boot.kernelParams = [
      "i915.enable_guc=3"
      "i915.enable_fbc=1"
    ];

    hardware.cpu.intel.updateMicrocode = true;

    # power-profiles-daemon manages CPU power profile.
    # GameMode also controls the CPU governor — force power-profiles-daemon off
    # when GameMode is enabled, otherwise leave Plasma's default behavior intact.
    services.power-profiles-daemon.enable =
      if config.programs.gamemode.enable
      then lib.mkForce false
      else lib.mkDefault true;
    services.tlp.enable = false; # avoid conflict with power-profiles-daemon

    hardware.enableRedistributableFirmware = true;
  };
}
