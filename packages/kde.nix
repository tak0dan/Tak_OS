# Tak_OS · kde.nix — KDE Plasma specific packages
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs }:

with pkgs; [

  # =========================
  # Core KDE Applications
  # =========================
  kdePackages.dolphin      # KDE file manager
  kdePackages.discover     # Software center
  kdePackages.kcalc        # KDE calculator
  kdePackages.konsole      # KDE terminal emulator
  kdePackages.ksystemlog   # KDE system log viewer

  # =========================
  # KDE Frameworks (Qt6)
  # =========================
  kdePackages.frameworkintegration   # Integrates non-KDE apps with KDE look-and-feel
  kdePackages.kconfig                # Configuration framework
  kdePackages.kcmutils               # Configuration module (KCM) utilities
  kdePackages.kcoreaddons            # Core add-ons for KDE frameworks
  kdePackages.kdeplasma-addons       # Plasma applets and widgets
  kdePackages.knewstuff              # Hot New Stuff — in-app content download

  # =========================
  # KDE Frameworks (Qt5)
  # CRITICAL: Required for legacy KCMs and Qt5-based KDE apps
  # =========================
  libsForQt5.kconfig       # Qt5 KConfig
  libsForQt5.kcmutils      # Qt5 KCM utilities
  libsForQt5.kcoreaddons   # Qt5 KCoreAddons
  libsForQt5.kiconthemes   # Qt5 icon theme support
  libsForQt5.kio           # Qt5 KIO file-access framework
  libsForQt5.knewstuff     # Qt5 Hot New Stuff

  # Fixes: QtGraphicalEffects QML module missing error
  libsForQt5.qtgraphicaleffects   # Qt5 QML graphical effects
  libsForQt5.qtmultimedia         # Qt5 multimedia playback support

  # =========================
  # KIO (File Access Framework)
  # =========================
  kdePackages.kio          # KIO core — file dialogs, remote protocols
  kdePackages.kio-admin    # KIO admin plugin — file ops as root
  kdePackages.kio-extras   # KIO extra protocols (ftp, sftp, smb, …)
  kdePackages.kservice     # KDE service framework

  # =========================
  # Plasma / Workspace Integration
  # =========================
  kdePackages.plasma-integration   # Plasma integration for non-Plasma apps
  kdePackages.plasma-workspace     # Plasma shell and workspace

  # =========================
  # Theming
  # =========================
  kdePackages.breeze        # Breeze widget style (Qt6)
  kdePackages.breeze-gtk    # Breeze GTK theme
  kdePackages.breeze-icons  # Breeze icon theme

  # =========================
  # Qt Theming Tools
  # =========================
  libsForQt5.qt5ct    # Qt5 configuration tool (fonts, style, icons)
  nwg-look            # GTK theme switcher for wlroots desktops
  qt6Packages.qt6ct   # Qt6 configuration tool

  # ---------------------------
  # Qt6 KDE (modern)
  # NOTE: Entries below are intentionally repeated for group independence.
  # ---------------------------
  kdePackages.frameworkintegration
  kdePackages.kconfig
  kdePackages.kcmutils
  kdePackages.kcoreaddons
  kdePackages.knewstuff

  # ---------------------------
  # Qt5 KDE (REQUIRED for KCMs)
  # ---------------------------
  libsForQt5.kconfig
  libsForQt5.kcmutils
  libsForQt5.kcoreaddons
  libsForQt5.knewstuff

  # 🔥 THIS FIXES YOUR ERROR
  libsForQt5.qtgraphicaleffects

  # Stability deps (often missing in partial KDE setups)
  libsForQt5.kiconthemes
  libsForQt5.kio

]
