# Tak_OS · kde.nix — KDE Plasma desktop environment
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# KDE.NIX — KDE/Qt runtime libraries (no Plasma session)
# =======================================================
# Provides Qt/KDE integration so KDE apps work well under Hyprland.
# Activated when features.kde = true (set in configuration.nix).
#
#   qt platformTheme            — native KDE file dialogs and styling
#   polkit-kde-agent            — authentication popups, wired to hyprland-session.target
#   udisks2                     — disk mounting/unmounting for Dolphin and other file managers
#   QML2_IMPORT_PATH            — Qt5 declarative component import paths
#   plasma-applications.menu    — XDG application menu from Plasma workspace
#
# ⚠️  polkit-kde-agent depends on hyprland-session.target.
#     This target is provided by services.hyprland.enable in window-managers.nix.
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

  # Udisks2 — disk mounting/unmounting for Dolphin and other file managers
  services.udisks2.enable = lib.mkIf features.kde true;

  # Enable polkit KDE integration
  services.polkit.kdeIntegration.enable = lib.mkIf features.kde true;

  # Polkit rules — allow users to mount/unmount disks without password prompt
  security.polkit.extraConfig = lib.mkIf features.kde ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.udisks2.") === 0 &&
          action.id !== "org.freedesktop.udisks2.enable-disc") {
        return polkit.Result.YES;
      }
    });
  '';

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
