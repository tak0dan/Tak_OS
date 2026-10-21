# Tak_OS · kde.nix — KDE Plasma specific packages
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# KDE.NIX — KDE/Qt desktop applications and supporting packages
# ================================================================
# Provides KDE applications, KDE Frameworks and desktop integration
# packages used by Tak_OS.
#
# Runtime/system integration such as:
#   - Qt platform configuration
#   - UDisks2
#   - Polkit
#   - KDE Polkit authentication agent
#   - XDG menu integration
#
# is handled by the main kde.nix module.
#
# This file owns KDE packages themselves.

{ pkgs }:

with pkgs; [

  # Native KDE/KIO popup bridge used by the Hyprland desktop grid.
  (callPackage /home/tak_1/native-kio-context-menu/package.nix { })

  # =========================
  # Core KDE Applications
  # =========================
  #
  # Main KDE applications used by Tak_OS.
  #
  # Dolphin provides the KDE file manager.
  # Ark provides archive management and integrates with Dolphin
  # through the Dolphin plugins package below.

  kdePackages.dolphin
  kdePackages.discover
  kdePackages.kcalc
  kdePackages.konsole
  kdePackages.ksystemlog
  kdePackages.kate
  kdePackages.ark

  # =========================
  # Dolphin Integration
  # =========================
  #
  # Additional Dolphin plugins and context-menu integrations.
  #
  # In particular, this provides archive-related integration with
  # Ark so archives can be managed directly from Dolphin instead
  # of requiring Ark to be opened separately.
  #
  # Dolphin itself is responsible for file management, while Ark
  # handles archive operations.

  kdePackages.dolphin-plugins

  # =========================
  # KDE Frameworks — Qt6
  # =========================
  #
  # Core KDE Frameworks required by KDE applications and their
  # integration with the Qt6 desktop environment.

  kdePackages.frameworkintegration
  kdePackages.kconfig
  kdePackages.kcmutils
  kdePackages.kcoreaddons
  kdePackages.kdeplasma-addons
  kdePackages.knewstuff

  # =========================
  # KIO — File Access Framework
  # =========================
  #
  # KIO provides KDE's file access and URL handling infrastructure.
  #
  # These components allow Dolphin and other KDE applications to
  # work with local files, network locations and additional KDE
  # protocols.
  #
  # kio-admin additionally provides administrative file operations
  # through KDE's KIO infrastructure.
  #
  # kio-extras provides additional KIO protocols and integrations.

  kdePackages.kio
  kdePackages.kio-admin
  kdePackages.kio-extras
  kdePackages.kservice

  # =========================
  # Plasma / Workspace Integration
  # =========================
  #
  # Provides KDE/Plasma integration libraries and workspace
  # components needed by KDE applications even when Plasma itself
  # is not the active desktop session.
  #
  # Plasma is not started by this package list; Tak_OS can use
  # these components from Hyprland.

  kdePackages.plasma-integration
  kdePackages.plasma-workspace

  # =========================
  # Theming
  # =========================
  #
  # KDE's standard visual theme, GTK integration and icon set.
  #
  # These allow KDE applications to retain consistent KDE styling
  # when running under Hyprland.

  kdePackages.breeze
  kdePackages.breeze-gtk
  kdePackages.breeze-icons

  # =========================
  # Qt / GTK Theming Tools
  # =========================
  #
  # Configuration utilities for Qt and GTK applications.
  #
  # qt5ct    — Qt5 appearance/configuration
  # qt6ct    — Qt6 appearance/configuration
  # nwg-look — GTK appearance/configuration under Wayland/WMs

  libsForQt5.qt5ct
  qt6Packages.qt6ct
  nwg-look
]
