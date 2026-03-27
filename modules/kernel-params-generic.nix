# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.kernel-params.generic;
in
{
  options.kernel-params.generic = {
    enable = mkEnableOption "Generic kernel parameters (sane defaults for any hardware)";
  };

  config = mkIf cfg.enable {

    boot.kernel.sysctl = {
      "kernel.sysrq"          = 1;   # enable SysRq for emergency recovery
      "kernel.panic"          = 10;  # auto-reboot 10s after kernel panic
      "vm.swappiness"         = 10;  # prefer RAM over swap
      "vm.vfs_cache_pressure" = 50;  # retain directory/inode cache longer
    };

    hardware.enableRedistributableFirmware = true;
  };
}
