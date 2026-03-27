# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
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
      "i915.fastboot=1"
      "i915.enable_fbc=1"
    ];

    hardware.cpu.intel.updateMicrocode = true;

    services.power-profiles-daemon.enable = true;
    services.tlp.enable = false; # avoid conflict with power-profiles-daemon

    hardware.enableRedistributableFirmware = true;
  };
}
