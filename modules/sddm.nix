# Tak_OS · sddm.nix
# SDDM display manager + Catppuccin Mocha/Mauve theme

{ config, pkgs, lib, ... }:

{
  services.displayManager.sddm = {
    enable = true;

    theme = "catppuccin-mocha-mauve";

    extraPackages = with pkgs; [
      kdePackages.qtsvg
      kdePackages.qtmultimedia
#     kdePackages.qtvirtualkeyboard
    ];
  };

  environment.systemPackages = [
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "mauve";
    })
  ];
}
