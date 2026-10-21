{ config, pkgs, ... }:

let
  xamppDir = "/opt/lampp";
in
{
  # Add XAMPP to PATH when enabled
  options.xampp = {
    enable = pkgs.mkOption {
      type = pkgs.types.bool;
      default = false;
      description = "Enable XAMPP (Apache + MySQL + PHP)";
    };
  };

  config = pkgs.stdenv.mkIf config.options.xampp.enable {
    # Add XAMPP to the system path
    environment.path = [
      "${xamppDir}/bin"
      environment.path
    ];

    # Create xampp control wrapper
    scripts."xampp" = ''
      #!/bin/sh
      exec "${xamppDir}/lampp" "$@"
    '';

    # Create lampp wrapper
    scripts."lampp" = ''
      #!/bin/sh
      exec "${xamppDir}/lampp" "$@"
    '';
  };
}