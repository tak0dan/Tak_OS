# Tak_OS · hm-home-scaffold.nix — Default home.nix template written to ~/.hm-local/
# github.com/tak0dan/Tak_OS · GNU GPLv3
# ~/.hm-local/home.nix — per-user Home Manager config
#
# NOTE: home.username, home.homeDirectory, and home.stateVersion
#       are already set by the system NixOS module — do not redefine them here.
#
# This file is yours to edit freely. It will NOT be overwritten on rebuild
# unless it is empty or contains a syntax error.
# To reset to this scaffold, delete the file and run nixos-smart-rebuild.

{ config, pkgs, lib, ... }:
{
  # ── Packages ──────────────────────────────────────────────────────────────
  # home.packages = with pkgs; [
  #   htop
  #   ripgrep
  #   bat
  # ];

  # ── Shell ─────────────────────────────────────────────────────────────────
  # programs.bash.enable = true;
  # programs.zsh.enable  = true;

  # ── Git ───────────────────────────────────────────────────────────────────
  # programs.git = {
  #   enable    = true;
  #   userName  = "Your Name";
  #   userEmail = "you@example.com";
  # };
}
