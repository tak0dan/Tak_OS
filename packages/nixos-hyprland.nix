{ pkgs }:

with pkgs; [

  # =========================
  # Hyprland Extras
  # =========================
  hypridle
  hyprpolkitagent
  uwsm
  hyprlang
  hyprshot
  hyprcursor
  mesa
  nwg-look
  waypaper

  # =========================
  # Apps
  # =========================
  power-profiles-daemon
  loupe
  appimage-run
  brightnessctl
  baobab
  btrfs-progs
  cmatrix
  distrobox
  dua
  duf
  cava
  cliphist
  dysk
  eog
  feh
  file-roller
  glib
  google-chrome
  gnome-system-monitor
  gsettings-qt
  fastfetch
  grimblast
  gtk-engine-murrine
  inxi
  psmisc   # provides killall and other process utilities
  kdePackages.qt6ct
  kdePackages.qtwayland
  kdePackages.qtstyleplugin-kvantum
  lazydocker
  lazygit
  libappindicator
  libsForQt5.qtstyleplugin-kvantum
  libsForQt5.qt5ct
  (mpv.override { scripts = [ mpvScripts.mpris ]; })
  nvtopPackages.full
  openssl
  pciutils
  networkmanagerapplet
  pamixer
  pavucontrol
  pulseaudio
  playerctl
  rsync
  kdePackages.polkit-kde-agent-1
  swappy
  serie
  unzip
  wdisplays
  wlr-randr
  wget
  xarchiver
  yad
  xdg-user-dirs
  yt-dlp
  onefetch
  curl
  figlet
  fd

  # =========================
  # Development
  # =========================
  cargo
  clang
  cmake
  gcc
  gnumake
  go
  luarocks
  nh

  # =========================
  # Utils
  # =========================
  ctop
  erdtree
  frogmouth
  lstr
  lolcat
  lsd
  macchina
  mcat
  mdcat
  parallel-disk-usage
  pik
  oh-my-posh
  ncdu
  ncftp
  netop
  ripgrep
  starship
  trippy
  tldr
  tuptime
  ugrep
  unrar
  v4l-utils
  zoxide

  # =========================
  # Hardware / Monitoring
  # =========================
  atop
  bandwhich
  caligula
  cpufetch
  cpuid
  cpu-x
  cyme
  cpufrequtils
  gdu
  glances
  gping
  hyfetch
  ipfetch
  pfetch
  smartmontools
  lm_sensors
  mission-center

  # =========================
  # Internet / Communication
  # =========================
  discord

  # =========================
  # Virtualisation
  # =========================
  virt-viewer
  libvirt

  # =========================
  # Video
  # =========================
  vlc

  # =========================
  # Terminals
  # =========================
  ghostty
  wezterm

]
