{ config, pkgs, ... }:

let
  home_dir = "/home/$USER";
  local_state = "/var/lib/nix";
  xdg_data_dir = "${home_dir}/.local/share";
  
  # Define the MIME type definition
  nist_mime_type = {
    name = "application/x-nist";
    comment = "Nist Installer Package";
    glob = [ "*.nist" ];
    icon = "application-x-nist";
    subClassOf = [ "application/x-tar" "application/zip" ];
  };

  # Define the Nist desktop entry
  nist_desktop_entry = {
    name = "Nist Installer";
    exec = "${pkgs.nixorcist}/bin/nixorcist";
    mimeTypes = [ "application/x-nist" ];
    type = "Application";
    categories = [ "System" "PackageManager" ];
    terminal = false;
    comment = "Double-click to install Nix packages declaratively or imperatively";
  };

  # Define the Dolphin service menu
  nist_service_menu = {
    type = "Service";
    serviceTypes = [ "KonqPopupMenu/Plugin" "AllFiles" ];
    mimeTypes = [ "application/x-nist" ];
    actions = [ "InstallWithNist" "InstallImperative" "InstallDeclarative" ];
    xKDEPriority = "TopLevel";
  };

  # Install actions
  nist_install_actions = {
    "InstallWithNist" = {
      name = "Install with nist (both modes)";
      exec = "${pkgs.nixorcist}/bin/nixorcist %f";
      icon = "system-software-install";
      onlyIn = [ "Desktop" "Documents" "Downloads" ];
    };
    "InstallImperative" = {
      name = "Install imperatively (nix profile)";
      exec = "${pkgs.nixorcist}/bin/nixorcist --imperative-only %f";
      icon = "application-x-addon";
      onlyIn = [ "Desktop" "Documents" "Downloads" ];
    };
    "InstallDeclarative" = {
      name = "Install declaratively (NixOS)";
      exec = "${pkgs.nixorcist}/bin/nixorcist --declarative-only --rebuild %f";
      icon = "system-config-software";
      onlyIn = [ "Desktop" "Documents" "Downloads" ];
    };
  };
in
{
  # Register the .nist MIME type
  programs.xdg.mimeTypes.nist = {
    comment = "Nist Installer Package";
    glob = [ "*.nist" ];
    subClassOf = [ "application/x-tar" "application/zip" ];
    icon = "application-x-nist";
  };

  # Install the service menu
  programs.xdg.services.nist-installer = {
    moduleType = "Service";
    module.serviceType = "KonqPopupMenu/Plugin";
    module.serviceTypes = [ "KonqPopupMenu/Plugin" "AllFiles" ];
    module.MimeType = "application/x-nist";
    module.actions = [
      { name = "InstallWithNist"; exec = "${pkgs.nixorcist}/bin/nixorcist %f"; }
      { name = "InstallImperative"; exec = "${pkgs.nixorcist}/bin/nixorcist --imperative-only %f"; }
      { name = "InstallDeclarative"; exec = "${pkgs.nixorcist}/bin/nixorcist --declarative-only --rebuild %f"; }
    ];
    module.XKDEPriority = "TopLevel";
  };

  # Install the desktop entry (for double-click)
  programs.xdg.desktopEntries.nist-installer = {
    name = "Nist Installer";
    exec = "${pkgs.nixorcist}/bin/nixorcist %f";
    mimeTypes = [ "application/x-nist" ];
    type = "Application";
    categories = [ "System" "PackageManager" ];
    terminal = false;
    comment = "Double-click to install Nix packages declaratively or imperatively";
  };

  # Install MIME type definition
  environment.etc."mime-xist.xml" = builtins.toFile "nist.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info/1.0">
      <mime-type type="application/x-nist">
        <comment>Nist Installer Package</comment>
        <glob pattern="*.nist"/>
        <icon-name>application-x-nist</icon-name>
        <sub-class-of type="application/x-tar"/>
        <sub-class-of type="application/zip"/>
      </mime-type>
    </mime-info>
  '';

  # Install service menu
  environment.etc."nixorcist.desktop" = builtins.toFile "nixorcist.desktop" ''
    [Desktop Entry]
    Type=Service
    ServiceTypes=KonqPopupMenu/Plugin,AllFiles
    MimeType=application/x-nist;
    Actions=InstallWithNist;InstallImperative;InstallDeclarative;
    X-KDE-Priority=TopLevel

    [InstallWithNist Action]
    Name=Install with nist (both modes)
    Exec=nixorcist %f
    Icon=system-software-install
    OnlyIn=Desktop,Documents,Downloads

    [InstallImperative Action]
    Name=Install imperatively (nix profile)
    Exec=nixorcist --imperative-only %f
    Icon=application-x-addon
    OnlyIn=Desktop,Documents,Downloads

    [InstallDeclarative Action]
    Name=Install declaratively (NixOS)
    Exec=nixorcist --declarative-only --rebuild %f
    Icon=system-config-software
    OnlyIn=Desktop,Documents,Downloads
  '';

  # Install default app (double-click .nist files)
  environment.etc."nixorcist-default.desktop" = builtins.toFile "nixorcist-desktop" ''
    [Desktop Entry]
    Name=Nist Installer
    Comment=Double-click to install Nix packages declaratively or imperatively
    Exec=nixorcist %f
    MimeType=application/x-nist;
    Type=Application
    Icon=system-software-install
    Categories=System;PackageManager;
    Terminal=false
    StartupNotify=true
    Comment[en_US]=Double-click .nist files to install packages on NixOS
  '';
}
