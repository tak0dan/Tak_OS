{ config, pkgs, lib, ... }:

# =============================================================================
#                         Personal Modular NixOS Configuration
# =============================================================================

let

  # ---------------------------------------------------------------------------
  # Feature Toggles
  # ---------------------------------------------------------------------------

  systemUwUfied = true;

in
{

  # ===========================================================================
  #                                   Imports
  # ===========================================================================

  imports = [

    # -------------------------------------------------------------------------
    # Hardware
    # -------------------------------------------------------------------------

    ./hardware-configuration.nix


    # -------------------------------------------------------------------------
    # Boot System
    # -------------------------------------------------------------------------

    ./modules/bootloader.nix
    ./modules/grub-theme.nix
    ./modules/kernel-params.nix
    #./modules/virtualbox.nix


    # -------------------------------------------------------------------------
    # Display Manager
    # -------------------------------------------------------------------------

    ./modules/sddm.nix



    # -------------------------------------------------------------------------
    # Window Managers / Desktop Environment
    # -------------------------------------------------------------------------

    ./modules/window-managers.nix


    # -------------------------------------------------------------------------
    # Core System Modules
    # -------------------------------------------------------------------------

    ./modules/locale.nix
    ./modules/networking.nix
    ./modules/users.nix
    ./modules/audio.nix


    # -------------------------------------------------------------------------
    # Shell / Environment
    # -------------------------------------------------------------------------

    ./modules/environment.nix
    ./modules/zsh.nix
    ./modules/rebuild-error-hook.nix


    # -------------------------------------------------------------------------
    # Generated packages (Nixorcist)
    # -------------------------------------------------------------------------

    ./nixorcist/generated/all-packages.nix

    # -------------------------------------------------------------------------
    # VM Testing — comment out for production
    # -------------------------------------------------------------------------
    # ./modules/vm.nix

  ]

  ++ lib.optionals systemUwUfied [

    # -------------------------------------------------------------------------
    # UwU Mode
    # -------------------------------------------------------------------------

    ./modules/uwu/nixowos.nix

  ];


  # ===========================================================================
  #                                   Fonts
  # ===========================================================================

  fonts = {

    fontDir.enable = true;

    packages = with pkgs; [

      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only

    ];

  };


  # ===========================================================================
  #                         SDDM Runtime Dependencies
  # ===========================================================================

  services.displayManager.sddm.extraPackages = with pkgs; [
    #qt5.qtmultimedia
  ];



  # ===========================================================================
  #                            Graphics / Hardware
  # ===========================================================================

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;


  # ===========================================================================
  #                               Audio (PipeWire)
  # ===========================================================================

  services.pipewire.enable = true;


  # ===========================================================================
  #                    Desktop Environment / Window Managers
  # ===========================================================================

  programs.hyprland.enable = true;

  qt = {
    enable = true;
    platformTheme = "kde";
  };


  # ===========================================================================
  #                                 Networking
  # ===========================================================================

  services.openssh = {

    enable = true;

    settings = {

      PermitRootLogin = "no";
      PasswordAuthentication = true;

    };

  };


  # ===========================================================================
  #                         Containers / Virtualisation
  # ===========================================================================

  virtualisation.docker.enable = true;


  # ===========================================================================
  #                                   Gaming
  # ===========================================================================

  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;


  # ===========================================================================
  #                               Global Nix Options
  # ===========================================================================

  nixpkgs.config.allowUnfree = true;

  nix.settings = {

    experimental-features = [ "nix-command" "flakes" ];

    download-buffer-size = 324217728;
    http-connections = 50;

  };


  # ===========================================================================
  #                                  Polkit
  # ===========================================================================

  security.polkit.enable = true;

  systemd.user.services.polkit-kde-agent = {

    description = "Polkit KDE Authentication Agent";

    after = [ "hyprland-session.target" ];
    wantedBy = [ "hyprland-session.target" ];

    serviceConfig = {

      ExecStart =
        "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";

      Restart = "on-failure";

    };

  };


  # ===========================================================================
  #                          KDE Menu Compatibility Fix
  # ===========================================================================

  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";


  # ===========================================================================
  #                               System Packages
  # ===========================================================================

  environment.systemPackages =

    (import ./packages/all-packages.nix { inherit pkgs; })

    ++ [

      pkgs.kdePackages.polkit-kde-agent-1
      pkgs.kdePackages.kio-admin
      pkgs.hyprland-qt-support

      (pkgs.writeShellScriptBin "nixorcist" ''
        exec /etc/nixos/nixorcist/nixorcist.sh "$@"
      '')

    ];


  # ===========================================================================
  #                              System State Version
  # ===========================================================================

  system.stateVersion = "25.11";

}
