# Tak_OS · copilot-cli.nix — GitHub Copilot CLI integration
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# COPILOT-CLI.NIX — GitHub Copilot CLI package wiring
# ====================================================
# Activated when features.copilot = true (set in configuration.nix).
# Pure/declarative: the CLI comes from nixpkgs instead of a network installer.

{ pkgs, lib, features, ... }:
{
  environment.systemPackages =
    lib.optionals features.copilot [ (builtins.getAttr "github-copilot-cli" pkgs) ];
}
