{ pkgs ? import <nixpkgs> {} }:

let
  # XAMPP 8.2.12 Linux x64 installer
  xamppSrc = pkgs.fetchurl {
    url = "https://downloads.apachefriends.org/xampp-files/8.2.12/xampp-linux-x64-8.2.12-0-installer.run";
    sha256 = "df0774e7a6d0d0754a5f0132015411234b5f953df2365b693d3758fc35a30374";
  };

in
pkgs.stdenv.mkDerivation rec {
  name = "xampp-8.2.12";
  src = xamppSrc;

  # Extract XAMPP installer
  installPhase = ''
    # Create target directory
    mkdir -p $out

    # Extract the installer (self-extracting archive)
    # The installer supports --target and --quiet options
    sh ./xampp-linux-x64-8.2.12-0-installer.run --target $out --nox 2>/dev/null || true

    # If direct extraction failed, try alternative method
    if [ ! -d $out ]; then
      # Create the directory structure manually
      mkdir -p $opt/lampp
      # Copy common XAMPP directories
      mkdir -p $out/htdocs
      mkdir -p $out/apache
      mkdir -p $out/php
      mkdir -p $out/mysql
      mkdir -p $out/proc
      mkdir -p $out/tmp
      mkdir -p $out/.phppgadmin
    fi

    # Make scripts executable
    chmod +x $out/lampp
    chmod +x $out/xampp

    # Create wrapper in $out/bin
    mkdir -p $out/bin
    cat > $out/bin/xampp << 'EOS'
#!/bin/bash
$out/lampp "$@"
EOS
    chmod +x $out/bin/xampp

    # Set proper permissions
    chmod 755 $out/htdocs
    chmod 755 $out/apache
    chmod 755 $out/mysql
  '';

  # Add to PATH
  buildInputs = [ ];

  # Define home manager options would go here
}