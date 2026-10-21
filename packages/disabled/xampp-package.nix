# DISABLED: not imported by the configuration. Kept for reference; fix before re-enabling.
{ config, pkgs, ... }:

let
  xamppDir = "/opt/lampp";
in
{
  # Add XAMPP to system path
  environment.path = [
    "$(xamppDir)/bin"
    environment.path
  ];

  # Create activation script for xampp
  xampp.enable = false;

  # Define options
  options.xampp = {
    enable = pkgs.mkOption {
      type = pkgs.types.bool;
      default = false;
      description = "Enable XAMPP (Apache + MySQL + PHP)";
    };

    adminEmail = pkgs.mkOption {
      type = pkgs.types.str;
      default = "post@localhost";
      description = "Server admin email";
    };
  };

  # Create wrapper to start/stop XAMPP
  config = {
    # Start XAMPP services
    services.xampp = pkgs.stdenv.mkIf config.options.xampp.enable {
      # Create wrapper script
      scripts."${config.xampp.enable and '' or ''}" = ''
        #!/bin/bash
        if [ "$1" = "start" ]; then
          /opt/lampp/lampp start
        elif [ "$1" = "stop" ]; then
          /opt/lampp/lampp stop
        elif [ "$1" = "restart" ]; then
          /opt/lampp/lampp restart
        elif [ "$1" = "status" ]; then
          /opt/lampp/lampp status
        else
          echo "Usage: $0 {start|stop|restart|status}"
        fi
      '';
    };

    # Add XAMPP bin to PATH
    # (already done via environment.path above)
  };
}