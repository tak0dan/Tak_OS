# Tak_OS · nixvim.nix — NixVim — Neovim configured via Nix
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs, ... }:

{
  environment.systemPackages = [
    (import /etc/nixos/external/nixvim { inherit pkgs; })
  ];
}
