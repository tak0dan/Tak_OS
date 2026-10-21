{ mkIf, ... }:

let
  xamppDir = "/opt/lampp";
in
mkIf true {
  # Export XAMPP bin directory
  exportPath = true;

  # Create the xampp control script
  bin."xampp" = ''
    #!/bin/sh
    exec "$0"/../lampp/lampp "$@"
  '';

  # Make lampp script executable
  #