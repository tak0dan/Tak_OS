# Tak_OS · core.nix — Essential CLI tools and base utilities
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs }:

with pkgs; [

  # =========================
  # Bluetooth
  # =========================
  adw-bluetooth   # GNOME-style Bluetooth manager (adwaita)
  blueman         # GTK Bluetooth manager
  overskride      # Bluetooth manager (GTK4)

  # =========================
  # Archive & Compression
  # =========================
  p7zip           # 7-Zip archive support (.7z, .zip, .rar, …)

  # =========================
  # File Utilities
  # =========================
  bat             # Better cat — syntax highlighting and Git integration
  eza             # Better ls — icons, Git status, tree view
  file            # Identify file types by magic bytes
  findutils       # GNU find, locate, xargs
  fzf             # Fuzzy finder — integrates with shell, vim, etc.
  lsd             # ls with color icons (alternative to eza)
  tree            # Print directory trees
  yazi            # Terminal file manager (async, image preview)

  # =========================
  # File Managers (GUI)
  # =========================
  thunar          # GTK file manager (XFCE)

  # =========================
  # Media Utilities
  # =========================
  ffmpeg          # Audio/video encoder, decoder, and converter
  imagemagick     # Image manipulation — convert, resize, compose
  libnotify       # Send desktop notifications (notify-send)

  # =========================
  # Network Tools
  # =========================
  nettools            # Classic tools: ifconfig, route, netstat, …
  nmap                # Network scanner and security auditing tool
  socat               # Socket relay — multipurpose network debugging
  sshpass             # Non-interactive SSH password authentication
  unixtools.ifconfig  # ifconfig from inetutils
  wget                # Non-interactive file downloader

  # =========================
  # Package Management & VCS
  # =========================
  flatpak   # Universal app sandboxing and distribution runtime
  gh        # GitHub CLI
  git       # Distributed version control system

  # =========================
  # Process & System Monitoring
  # =========================
  bottom    # Modern system monitor TUI (btm)
  btop      # Resource monitor with graphs and mouse support
  htop      # Interactive process viewer
  procps    # ps, top, kill, watch, and other /proc tools

  # =========================
  # Shell & Prompt
  # =========================
  bash      # GNU Bourne Again shell
  fish      # User-friendly interactive shell
  pipewire  # Low-latency audio/video server (replaces PulseAudio)
  starship  # Cross-shell customizable prompt (fast, zero-config)
  zsh       # Z shell

  # =========================
  # System Information
  # =========================
  dmidecode   # Read DMI/SMBIOS tables (hardware info)
  # fastfetch — provided by modules/default-fastfetch.nix (uwu=false)
  #             or modules/uwu/nixowos.nix (uwu=true); not listed here to
  #             avoid binary collision between the two wrappers.
  hwinfo      # Detailed hardware information tool
  lm_sensors  # Read hardware temperature and fan sensors
  lshw        # List hardware components
  mesa-demos  # OpenGL demo programs (glxgears, glxinfo, …)
  pciutils    # PCI bus utilities (lspci)
  usbutils    # USB utilities (lsusb)

  # =========================
  # System Tools
  # =========================
  bc           # Arbitrary-precision calculator language
  efibootmgr   # Manage EFI boot entries
  jq           # Command-line JSON processor and formatter
  os-prober    # Detect other OSes for multi-boot (GRUB)
  pacman       # Arch Linux package manager (compatibility / scripts)

  # =========================
  # Terminal Emulators
  # =========================
  alacritty   # GPU-accelerated terminal emulator (Rust)
  ghostty     # Modern GPU-native terminal emulator
  kitty       # Feature-rich GPU terminal with image protocol

  # =========================
  # Text Editors
  # =========================
  neovim  # Extensible Vim-based editor
  vim     # Classic Vi-compatible editor

  # =========================
  # Qt Multimedia
  # =========================
  libsForQt5.qtmultimedia  # Qt5 multimedia playback support

]
