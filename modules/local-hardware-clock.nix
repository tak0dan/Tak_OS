# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.local.hardware-clock;
in {
  options.local.hardware-clock = {
    enable = mkEnableOption "Change Hardware Clock To Local Time";
  };

  config = mkIf cfg.enable {time.hardwareClockInLocalTime = true;};
}
