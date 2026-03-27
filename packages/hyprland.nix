{ pkgs }:

with pkgs; [

  # =========================
  # Wayland Compositor
  # =========================
  hyprland             # The Hyprland Wayland tiling compositor

  # =========================
  # Screen Capture
  # =========================
  grim    # Screenshot utility for Wayland
  slurp   # Interactive region selector (used with grim)

  # =========================
  # Display Configuration
  # =========================
  nwg-displays   # Graphical display layout configurator for Hyprland

  # =========================
  # Bars & Widgets
  # =========================
  ags        # Aylur's GTK Shell — JavaScript-powered widget system
  eww        # Elkowar's widget system (Wayland + X11)
  quickshell # QtQuick / QML-based shell and widget toolkit
  waybar     # Highly customizable Wayland status bar

  # =========================
  # Launchers
  # =========================
  rofi   # Application launcher (Wayland mode)
  wofi   # GTK Wayland application launcher

  # =========================
  # Lock & Logout
  # =========================
  hyprlock   # Hyprland GPU-based screen locker
  wlogout    # Wayland logout / power menu

  # =========================
  # Notifications
  # =========================
  swaynotificationcenter   # Notification center for Sway / Hyprland (swaync)

  # =========================
  # Wallpaper
  # =========================
  hyprpaper   # Hyprland wallpaper utility (static images)
  mpvpaper    # MPV-based animated wallpaper renderer
  swww        # Smooth animated wallpaper daemon for Wayland
  wallust     # Color-scheme generator from wallpapers (pywal fork)

  # =========================
  # Clipboard
  # =========================
  wl-clipboard   # Wayland clipboard utilities (wl-copy / wl-paste)

  # =========================
  # Qt / Wayland Integration
  # NOTE: These allow Qt and KDE apps to render natively on Wayland.
  # =========================
  hyprland-qt-support                   # Qt integration bridge for Hyprland
  kdePackages.xdg-desktop-portal-kde   # XDG portal backend for KDE / Qt apps
  libsForQt5.qtwayland                  # Qt5 Wayland platform plugin
  qt6.qtwayland                         # Qt6 Wayland platform plugin

  # =========================
  # General Utilities
  # NOTE: Duplicated intentionally — this group is designed to be
  #       usable standalone without depending on core.nix.
  # =========================
  alacritty     # GPU-accelerated terminal emulator
  bat           # Better cat — syntax highlighting
  bc            # Arbitrary-precision calculator
  bottom        # Modern system monitor TUI
  btop          # Resource monitor with graphs
  eza           # Better ls — icons, Git status
  ffmpeg        # Audio / video encoder and converter
  file          # Identify file types by magic bytes
  findutils     # GNU find, locate, xargs
  fzf           # Fuzzy finder
  git           # Distributed version control
  htop          # Interactive process viewer
  imagemagick   # Image manipulation toolkit
  jq            # Command-line JSON processor
  kitty         # Feature-rich GPU terminal
  libnotify     # Send desktop notifications (notify-send)
  nmap          # Network scanner
  procps        # ps, top, kill and other /proc tools
  socat         # Socket relay / network debugging
  swww          # Wallpaper daemon (also declared above for group clarity)
  thunar        # GTK file manager
  yazi          # Terminal file manager

]
