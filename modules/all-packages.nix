# Tak_OS · all-packages.nix — Master package-module import hub
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    libsecret  # provides secret-tool for keyring access
  ];
}
