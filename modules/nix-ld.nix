# Tak_OS · nix-ld.nix — nix-ld — run unpackaged binaries
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs, ... }:

{
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    openssl
  ];
}
