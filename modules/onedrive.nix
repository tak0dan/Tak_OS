# Tak_OS · onedrive.nix — OneDrive cloud sync
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# ONEDRIVE.NIX — OneDrive client
# ==========================
# Activated when features.onedrive = true (set in configuration.nix).
#
#   services.onedrive.enable — Onedrive systemd user service
#
# Requires: nixpkgs.services.onedrive (provided by nixpkgs)

{ lib, features, ... }:
{
  services.onedrive = lib.mkIf features.onedrive {
    enable = true;
  };
}