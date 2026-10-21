# Tak_OS · kde.nix — KDE Plasma integration
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# KDE.NIX — KDE/Qt desktop integration
# =====================================
# Provides KDE/Qt integration so KDE applications work correctly
# under Hyprland.
#
# Package ownership:
#   packages/kde.nix — KDE applications, plugins and libraries
#
# Runtime integration:
#   qt platformTheme     — native KDE/Qt styling and dialogs
#   polkit               — system-wide authentication authority
#   polkit-kde-agent     — graphical KDE authentication agent
#   udisks2              — disk management and removable media
#   applications.menu    — Plasma application menu
#
# No Qt5 QML compatibility paths are required here.
# KDE/Qt packages are managed by packages/kde.nix.

{ pkgs, lib, features, ... }:

{
  # =========================
  # Qt / KDE Integration
  # =========================
  #
  # Enables NixOS Qt integration and tells Qt applications to use
  # the KDE platform theme.
  #
  # This allows KDE/Qt applications running under Hyprland to use
  # the expected KDE appearance and desktop integration.
  #
  # KDE applications themselves are installed separately through
  # packages/kde.nix.

  qt = lib.mkIf features.kde {
    enable = true;
    platformTheme = "kde";
  };

  # =========================
  # UDisks2 — Disk Management
  # =========================
  #
  # Provides the system D-Bus service used by desktop environments
  # and applications for managing block devices.
  #
  # Dolphin/KIO uses this infrastructure for operations such as:
  #   - discovering storage devices
  #   - mounting filesystems
  #   - unmounting filesystems
  #   - ejecting removable media
  #
  # UDisks2 works together with Polkit when an operation requires
  # user authentication.

  services.udisks2.enable =
    lib.mkIf features.kde true;

  # =========================
  # Polkit — System Authentication
  # =========================
  #
  # Polkit provides the system-wide authorization authority.
  #
  # It is responsible for determining whether a desktop user is
  # allowed to perform privileged operations, for example:
  #   - mounting certain filesystems
  #   - unlocking or managing storage devices
  #   - changing system configuration
  #
  # The KDE authentication agent below is only the graphical
  # frontend which asks the user for authentication when Polkit
  # requires it.

  security.polkit.enable =
    lib.mkIf features.kde true;

  # =========================
  # KDE Polkit Authentication Agent
  # =========================
  #
  # Provides graphical authentication dialogs for applications
  # requiring elevated privileges.
  #
  # This is especially important when using KDE applications such
  # as Dolphin under a non-Plasma compositor such as Hyprland.
  #
  # The service is attached to graphical-session.target so the
  # authentication agent starts together with the graphical user
  # session instead of requiring Plasma itself.
  #
  # graphical-session-pre.target is used for ordering so the agent
  # starts after the graphical session environment has been prepared,
  # while still being pulled in by graphical-session.target.

  systemd.user.services.polkit-kde-agent =
    lib.mkIf features.kde {

      description = "KDE Polkit Authentication Agent";

      wantedBy = [
        "graphical-session.target"
      ];

      after = [
        "graphical-session-pre.target"
      ];

      serviceConfig = {
        Type = "simple";

        ExecStart =
          "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";

        Restart = "on-failure";
        RestartSec = 1;
      };
    };

  # =========================
  # KDE Application Menu
  # =========================
  #
  # Provides the Plasma application menu definition so KDE
  # applications are correctly represented in XDG application
  # menus even when Plasma itself is not running.
  #
  # This is useful when KDE applications are used under Hyprland.

  environment.etc."xdg/menus/applications.menu".source =
    lib.mkIf features.kde
      "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
}
