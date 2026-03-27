# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# KDE.NIX — KDE/Qt runtime libraries (no Plasma session)
# =======================================================
# Provides Qt/KDE integration so KDE apps work well under Hyprland.
# Activated when features.kde = true (set in configuration.nix).
#
#   qt platformTheme            — native KDE file dialogs and styling
#   polkit-kde-agent            — authentication popups, wired to hyprland-session.target
#   QML2_IMPORT_PATH            — Qt5 declarative component import paths
#   plasma-applications.menu    — XDG application menu from Plasma workspace
#
# ⚠️  polkit-kde-agent is hardwired to hyprland-session.target.
#     If features.hyprland = false, authentication popups will not auto-start.

{ pkgs, lib, features, ... }:
{
  qt = lib.mkIf features.kde {
    enable        = true;
    platformTheme = "kde";
  };

  environment.sessionVariables = lib.mkIf features.kde {
    QML2_IMPORT_PATH = lib.mkForce (
      lib.concatStringsSep ":" [
        "${pkgs.libsForQt5.qtgraphicaleffects}/lib/qt-5/qml"
        "${pkgs.libsForQt5.kcmutils}/lib/qt-5/qml"
        "${pkgs.libsForQt5.knewstuff}/lib/qt-5/qml"
      ]
    );
  };

  systemd.user.services.polkit-kde-agent = lib.mkIf features.kde {
    description = "Polkit KDE Authentication Agent";
    after    = [ "hyprland-session.target" ];
    wantedBy = [ "hyprland-session.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  environment.etc."xdg/menus/applications.menu".source =
    lib.mkIf features.kde
      "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
}
