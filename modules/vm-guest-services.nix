# Tak_OS · vm-guest-services.nix — QEMU/Spice guest tools for VM environments
# github.com/tak0dan/Tak_OS · GNU GPLv3
{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.vm.guest-services;
in {
  options.vm.guest-services = {
    enable = mkEnableOption "Enable Virtual Machine Guest Services";
  };

  config = mkIf cfg.enable {
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;
    services.spice-webdavd.enable = true;
  };
}
