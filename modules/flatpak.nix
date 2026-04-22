# Tak_OS · flatpak.nix — Flatpak support (guarded by features.flatpak)
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# FLATPAK.NIX — optional Flatpak runtime + Flathub remote
# ========================================================
# Activated when features.flatpak = true.
# Enables system Flatpak support and registers the Flathub remote.
#
# Useful for apps that are easier to consume outside nixpkgs or when a
# sandboxed app distribution is more practical than native packaging.

{ lib, pkgs, features, ... }:
{
  services.flatpak.enable = lib.mkIf features.flatpak true;

  environment.systemPackages = lib.mkIf features.flatpak [ pkgs.flatpak ];

  systemd.services.flatpak-flathub = lib.mkIf features.flatpak {
    description = "Ensure Flathub Flatpak remote exists";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "flatpak-system-helper.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };
}
