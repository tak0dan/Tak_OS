# Tak_OS · environment.nix — Session environment variables
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, ... }:

{
  environment.variables = {
   
  };

  systemd.tmpfiles.rules = [
    "d /var/log/journal 2755 root systemd-journal"
  ];

  services.printing.enable = true;
}
