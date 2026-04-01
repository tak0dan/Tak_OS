# Tak_OS · local-hardware-clock.nix — RTC hardware clock — keep local time for dual-boot
# github.com/tak0dan/Tak_OS · GNU GPLv3
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
