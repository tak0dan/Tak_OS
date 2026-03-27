# Tak_OS · users.nix — System user accounts
# github.com/tak0dan/Tak_OS · GNU GPLv3
# users.nix
{ config, pkgs, ... }:

{
  users.users.tak_1 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Elder Evil";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
      pkgs.zsh
    ];
  };
}
