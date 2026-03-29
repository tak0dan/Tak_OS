# Tak_OS · configuration.nix — System entry point — feature flags and module wiring
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, lib, ... }:

# =============================================================================
#                           🧠 CONFIG OVERVIEW
# =============================================================================
# Modular NixOS configuration driven by feature flags and GPU profiles.
#
# ┌─ HOW TO USE ───────────────────────────────────────────────────────────┐
# │  1. Set your options in the `features` block below.                    │
# │  2. Run: nixos-smart-rebuild                                           │
# │  3. If something breaks, check which feature flag controls it and      │
# │     open the module file listed in that flag's comment.                │
# └────────────────────────────────────────────────────────────────────────┘
#
# ┌─ MODULE LOADING RULES ─────────────────────────────────────────────────┐
# │  Always loaded:                                                        │
# │    hardware, boot, display/login, core system, shell                   │
# │    fonts-base, hardware-graphics, keyring, nix-settings                │
# │    kde, openssh, gaming, system-packages (guarded internally)          │
# │    hm-local-bootstrap, copilot-cli (guarded internally)                │
# │                                                                        │
# │  Loaded when features.home-manager = true:                             │
# │    <home-manager/nixos>  modules/hm-users.nix                          │
# │                                                                        │
# │  Loaded when features.hyprland = true:                                 │
# │    window-managers, portals, quickshell, fonts, theme, overlays, nh    │
# │    hyprlock (screen lock + hypridle.conf generation)                   │
# │    wlogout  (theme deployment → features.wlogout-profile)              │
# │    vm-guest-services (*), local-hardware-clock (*)                     │
# │    (*) imported but inactive until their own option is set             │
# │                                                                        │
# │  Loaded when features.uwu = true:                                      │
# │    modules/uwu/nixowos.nix        — NixOwOS logo + OS identity         │
# │  Loaded when features.uwu = false:                                     │
# │    modules/default-fastfetch.nix  — plain NixOS logo wrapper           │
# │  Loaded when features.uwuPackages = true:                              │
# │    packages/uwu.nix  → packages/catgirldownloader.nix (+ future pkgs) │
# │                                                                        │
# │  Loaded when features.virtualisation = true:                           │
# │    modules/virtualbox.nix  (also enables Docker)                       │
# └────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================


# =============================================================================
#                           🚀 FEATURE TOGGLES
# =============================================================================
let
  features = {

    # =========================================================================
    # 🪟 HYPRLAND
    # =========================================================================
    # Wayland compositor (tiling window manager).
    #
    # Turning ON also loads:
    #   modules/window-managers.nix        — Hyprland + bspwm/i3 fallback, xkb
    #   modules/portals.nix                — XDG desktop portals (screen share, etc.)
    #   modules/quickshell.nix             — Wayland shell widget system
    #   modules/fonts.nix                  — Large font collection for bars/terminals
    #   modules/theme.nix                  — GTK/cursor/dconf dark theme
    #   modules/overlays.nix               — nixpkgs patches (waybar-weather, etc.)
    #   modules/nh.nix                     — Nix helper + nix-output-monitor
    #   modules/vm-guest-services.nix      — (inactive unless vm.guest-services.enable)
    #   modules/local-hardware-clock.nix   — (inactive unless local.hardware-clock.enable)
    #   packages/hyprland.nix              — Hyprland-specific user packages
    #
    hyprland = true;

    # ─── Hyprland sub-toggles ──────────────────────────────────────────────
    # All sub-toggles below require hyprland = true to have any effect.
    #
    # 🔒 HYPRLOCK — GPU-accelerated screen locker
    #   enable  — install hyprlock and configure it in hypridle
    #   timeout — seconds of idle before the screen locks
    #             (a warning notification fires 60 s before the lock)
    #
    hyprlock = { enable = true; timeout = 600; };

    # 💤 HYPRIDLE — idle daemon that fires hyprlock on inactivity
    #   Manages ~/.config/hypr/hypridle.conf for every user in home-manager-users.
    #   Set to false to skip the idle daemon entirely (and leave the conf untouched).
    #
    hypridle = true;

    # 📊 WAYBAR — Wayland status bar
    waybar = true;

    # 🔔 SWAYNC — Notification centre (swaync)
    swaync = true;

    # 🚪 WLOGOUT — Logout / power-off menu
    wlogout = true;

    # 🎨 WLOGOUT THEME — Visual theme for the wlogout screen
    #
    # Available profiles (assets live in /etc/nixos/assets/wlogout/<profile>/):
    #   "default"     — Rounded icon buttons with wallust colour import
    #                   (original ~/.config/wlogout theme, LinuxBeginnings)
    #   "catppuccin"  — Catppuccin Mocha / Mauve  (https://github.com/catppuccin/wlogout)
    #   "minimal"     — Minimal dark style, system wlogout icons
    #                   (https://github.com/shivalingeshwar6/wlogout-minimal)
    #   "end4"        — Material Symbols font icons, translucent dark
    #                   (https://github.com/end-4/dots-hyprland)
    #
    wlogout-profile = "catppuccin";

    # 🔍 ROFI — Application launcher (Wayland mode)
    rofi = true;

    # =========================================================================
    # 🎮 GAMEON — GLF-OS-inspired gaming stack
    # =========================================================================
    # Master toggle: set enable = true to activate everything below.
    # Set enable = false to revert ALL changes (module is not imported at all).
    #
    # Sub-toggles (only active when enable = true):
    #
    #   wine              Wine WoW64 Staging + winetricks
    #   proton-ge         proton-ge-bin as Steam extra compat tool
    #   launchers         Lutris / Heroic / Faugus / UMU / Oversteer
    #   overlays          MangoHud / GOverlay / vkBasalt + compat symlinks
    #   streaming         Full GStreamer codec pack + noisetorch
    #   peripherals       xone / xpadneo / hid-tmff2; ratbagd; piper;
    #                       opentabletdriver; steam-hardware; DualSense udev
    #   openrgb           OpenRGB service (all-plugins build)
    #   input-remapper    input-remapper daemon + polkit + autoload unit
    #   fanatec-wheel     hid-fanatecff kernel module  (local src, OFF by default)
    #   logitech-wheel    new-lg4ff kernel module       (local src, OFF by default)
    #   sysctl-tweaks     Gaming sysctl / Mesa shader-cache env vars
    #   zram              zram-swap (zstd, 25 % RAM, priority 5)
    #   bfq-scheduler     BFQ I/O scheduler udev rule on all block devices
    #   low-latency-audio PipeWire 256-sample fixed quantum + usbcore.autosuspend=-1
    #
    # Sources for out-of-tree kernel modules (cloned locally — no fetchFromGitHub):
    #   /etc/nixos/assets/kernel-modules/hid-fanatecff/
    #   /etc/nixos/assets/kernel-modules/new-lg4ff/
    # =========================================================================
    gameon = {
      enable            = false;   # ← set to true to activate the entire stack

      wine              = true;
      proton-ge         = true;
      launchers         = true;
      overlays          = true;
      streaming         = true;   # heavy GStreamer pack — disabled by default

      peripherals       = true;
      openrgb           = true;
      input-remapper    = true;
      fanatec-wheel     = true;   # build from local source — off by default
      logitech-wheel    = true;   # build from local source — off by default

      sysctl-tweaks     = true;
      zram              = true;
      bfq-scheduler     = true;
      low-latency-audio = true;
    };

    # =========================================================================
    # 🖥️  KERNEL PARAMS PROFILE
    # =========================================================================
    # Selects boot-time kernel tuning.
    # → modules/gpu.nix  (dispatches to the profile sub-module below)
    #
    #==================#=====================================================================================#
    # NOTE:(IMPORTANT):# These modules ARE NOT tailored for your system and might cause kernel panics        #
    # NOTE:(IMPORTANT):# The ONLY module tailored so far is Thinkpad one, and it is made for Thinkpad T-480  #
    # NOTE:(IMPORTANT):# It is HIGHLY RECOMMENDED to create your own                                         #
    #==================#=====================================================================================#
    #
    # "generic"   → modules/kernel-params-generic.nix   Sane defaults for any hardware
    # "thinkpad"  → modules/kernel-params-thinkpad.nix  ThinkPad T480 (i915, power mgmt)
    # "nvidia"    → modules/kernel-params-nvidia.nix    Discrete Nvidia (DRM, initrd)
    # "amd"       → modules/kernel-params-amd.nix       AMD (iommu, microcode, early load)
    #
    kernelParams = "thinkpad";

    # =========================================================================
    # 🎮 GPU DRIVER PROFILE
    # =========================================================================
    # Selects the GPU driver loaded on top of the kernel params above.
    # → modules/gpu.nix  (dispatches to the driver sub-module below)
    #
    # NOTE: Sometimes less is better, check your hardware before enabling any of these profiles!
    #
    # "none"         → (no driver module)
    # "amd"          → modules/amd-drivers.nix          Pair with: kernelParams = "amd"
    # "intel"        → modules/intel-drivers.nix         Pair with: kernelParams = "thinkpad" or "generic"
    # "nvidia"       → modules/nvidia-drivers.nix        Pair with: kernelParams = "nvidia"
    # "nvidia-prime" → modules/nvidia-prime-drivers.nix  Pair with: kernelParams = "nvidia"
    #
    gpu = "none";

    # =========================================================================
    # 🎨 KDE RUNTIME
    # =========================================================================
    # KDE libraries and Qt integration for apps — does NOT install Plasma.
    # → modules/kde.nix
    # → packages/kde.nix  (user packages)
    #
    # ⚠️  polkit-kde-agent is hardwired to hyprland-session.target.
    #     If hyprland = false, polkit popups will not auto-start.
    #
    kde = true;

    # =========================================================================
    # 🎮 STEAM / GAMING
    # =========================================================================
    # Steam with Gamescope + GameMode performance governor.
    # → modules/gaming.nix
    # → packages/games.nix  (user packages: Lutris, Heroic, MangoHud, etc.)
    #
    steam = true;

    # =========================================================================
    # 🐾 UWU  (meme / aesthetic stack)
    # =========================================================================
    # NixOwOS branding: os-release + fastfetch ASCII logo overlay.
    # → modules/uwu/nixowos.nix
    #
    # Disabling this reverts all branding; no other modules are affected.
    #
    # All credits to yunfachi. Original dots: https://github.com/yunfachi/NixOwOS
    #
    uwu = true; #<--- I know you want to enable it, you femboy.
    uwuPackages = false;
    #~~~~~~~~~~~~~~~~~~
    #                 |
    #                 ∨
    # Sub-toggle: UwU packages (requires uwu = true to be meaningful)
    # Installs catgirldownloader and other UwU-specific packages.
    # → packages/uwu.nix  (standalone derivations in packages/catgirldownloader.nix)
    #


    # =========================================================================
    # 📦 VIRTUALISATION
    # =========================================================================
    # Enables Docker + VirtualBox host.
    # → modules/virtualbox.nix
    #
    # ⚠️  VirtualBox kernel module takes significant time to build.
    #     Disable on first rebuild if you don't need it immediately.
    #
    virtualisation = true;

    # =========================================================================
    # 🤖 NIXORCIST
    # =========================================================================
    # Custom package automation system (see /etc/nixos/nixorcist/).
    # Exposes the `nixorcist` CLI and loads auto-generated package lists.
    # → nixorcist/generated/all-packages.nix
    # → modules/system-packages.nix  (nixorcist CLI wrapper)
    #
    nixorcist = true;

    # =========================================================================
    # 🔐 OPENSSH
    # =========================================================================
    # Enables the SSH daemon for remote access.
    # → modules/openssh.nix
    #
    # ⚠️  Password authentication is ON. Switch to key-based auth for
    #     production or internet-exposed machines.
    #
    openssh = true;

    # =========================================================================
    # 🏠 HOME-MANAGER
    # =========================================================================
    # Declarative management of /home/ (dotfiles, user packages, services).
    # → modules/hm-users.nix          — profile declarations per user
    # → modules/hm-local-bootstrap.nix — ~/.hm-local scaffold + validation
    # → modules/hm-home-scaffold.nix  — default home.nix template
    #
    # Each user's config is read from:  /home/<user>/.hm-local/home.nix
    #                              or:  /home/<user>/.hm-local/default.nix
    # The scaffold is auto-written on rebuild if the file is missing, empty,
    # or contains a syntax error — so a broken file never blocks a rebuild.
    #
    # home-manager only controls what you explicitly declare inside home.nix;
    # it will never touch files not mentioned there.
    #
    home-manager = true;
    home-manager-users = [
      "tak_1"
      # "alice"
      # "bob"
    ];

    # =========================================================================
    # 🤖 GITHUB COPILOT CLI
    # =========================================================================
    # Installs the GitHub Copilot CLI via the official installer script.
    # → modules/copilot-cli.nix
    #
    # ⚠️  Requires internet access on first activation.
    #     Installation is guarded by a sentinel file and only runs once.
    #     To re-install, remove: /var/lib/copilot-cli/.installed
    #
    copilot = true;
  };


  # ===========================================================================
  # 🚫 DISABLED PACKAGES
  # ===========================================================================
  # Managed by the CLI tools — prefer those over manual edits here.
  #
  #   nixos-comment   <pkg>   disable a package globally
  #   nixos-uncomment <pkg>   re-enable a package
  #
  # Source of truth:  packages/disabled/disabled-packages.nix
  # Format:           [ "steam" "discord" "telegram-desktop" ]
  #
  # You can also add quick one-off names directly to `extraDisabled` below
  # without touching the managed file — they are merged at evaluation time.
  #
  extraDisabled    = [];
  disabledPackages = import ./packages/disabled/disabled-packages.nix;
  isEnabled        = pkg: !(builtins.elem (lib.getName pkg) disabledPackages);
  filterPkgs       = list: builtins.filter isEnabled list;


in
{

  # ===========================================================================
  # 📦 IMPORTS
  # ===========================================================================
  # Modules are split into three groups:
  #
  #   1. Always loaded — hardware, boot, core system, gpu.nix
  #   2. Conditionally loaded — driven by feature flags above
  #   3. Never import the individual driver modules directly;
  #      gpu.nix manages amd/intel/nvidia/nvidia-prime internally.
  #
  imports =
   [
     # --- Hardware ---
     ./hardware-configuration.nix

     # --- Boot ---
     ./modules/bootloader.nix
     ./modules/grub-theme.nix

     # --- GPU (always loaded; profile + driver activation via features above) ---
     # gpu.nix pulls in: kernel-params.nix, kernel-params-nvidia.nix,
     #                   amd-drivers.nix, intel-drivers.nix,
     #                   nvidia-drivers.nix, nvidia-prime-drivers.nix
     # Activation is controlled by gpu.kernelParams and gpu.driver below.
     ./modules/gpu.nix

     # --- Display / Login ---
     ./modules/sddm.nix #<--- Idk, this shit ocasionally works, but don't really rely on it :)

     # --- Core system ---
     ./modules/locale.nix        #<--- Make sure to use YOUR locale
     ./modules/networking.nix    #<--- Change your networking name here
     ./modules/users.nix         #<--- Set up your user here
     ./modules/audio.nix         # PipeWire (ALSA + PulseAudio compat + rtkit)
     ./modules/hardware-graphics.nix  # Mesa / VA-API + 32-bit libs
     ./modules/keyring.nix       # GNOME Keyring secret store

     # --- Shell / environment ---
     ./modules/environment.nix
     ./modules/zsh.nix
     ./modules/rebuild-error-hook.nix

     # --- Compatibility ---
     ./modules/nix-ld.nix

     # --- Nix daemon + nixpkgs settings ---
     ./modules/nix-settings.nix

     # --- Fonts (base set; full set loaded with hyprland below) ---
     ./modules/fonts-base.nix

     # --- Feature modules (always imported; guarded internally by features.*) ---
     ./modules/kde.nix           # Qt/KDE runtime → features.kde
     ./modules/openssh.nix       # SSH daemon      → features.openssh
     ./modules/gaming.nix        # Steam + GameMode → features.steam

     # --- System packages (assembles all package groups) ---
     ./modules/system-packages.nix

     # --- ~/.hm-local scaffold + validation (runs regardless of home-manager toggle) ---
     ./modules/hm-local-bootstrap.nix

     # --- GitHub Copilot CLI (install / cleanup on every rebuild) ---
     ./modules/copilot-cli.nix

     # --- Auto-generated package lists (managed by nixorcist) ---
     ./nixorcist/generated/all-packages.nix
   ]

   # Declarative user environment — dotfiles, user packages, services.
   # Config is read from ~/.hm-local/home.nix (or default.nix).
   ++ lib.optionals features.home-manager [
     <home-manager/nixos>
     ./modules/hm-users.nix
   ]

   # Hyprland stack — everything that only makes sense on a Wayland compositor.
   #
   # vm-guest-services and local-hardware-clock are included here because they
   # originate from the Hyprland config set. They are safe no-ops by default;
   # activate them by setting:
   #   vm.guest-services.enable      = true;
   #   local.hardware-clock.enable   = true;
   ++ lib.optionals features.hyprland [
     # Compositor + Wayland plumbing
     ./modules/window-managers.nix   # Hyprland, bspwm, i3, xkb layout
     ./modules/portals.nix           # XDG portals: screen share, file picker
     ./modules/quickshell.nix        # Wayland shell widget layer

     # Visual environment
     ./modules/fonts.nix             # Nerd fonts, CJK, icon fonts, etc.
     ./modules/theme.nix             # GTK Adwaita-dark, cursors, dconf defaults
     ./modules/overlays.nix          # nixpkgs patches (waybar-weather, cmake fixes)

     # Tooling
     ./modules/nh.nix                # `nh` Nix helper + nix-output-monitor + nvd

     # Screen lock + hypridle.conf generation
     ./modules/hyprlock.nix          # hyprlock package + generates ~/.config/hypr/hypridle.conf

     # Wlogout theme deployment
     ./modules/wlogout.nix           # deploys features.wlogout-profile theme to ~/.config/wlogout/

     # Optional hardware support (inactive until their enable option is set)
     ./modules/vm-guest-services.nix    # QEMU guest agent + SPICE
     ./modules/local-hardware-clock.nix # RTC in local time (dual-boot Windows)
   ]

   ++ lib.optionals features.uwu [
     ./modules/uwu/nixowos.nix        # NixOwOS logo + OS identity
   ]

   ++ lib.optionals (!features.uwu) [
     ./modules/default-fastfetch.nix  # Plain NixOS logo
   ]

   ++ lib.optionals features.virtualisation [
     ./modules/virtualbox.nix  # VirtualBox host + Docker
   ]

   ++ lib.optionals features.gameon.enable [
     ./modules/gameon.nix      # GLF-OS-inspired gaming stack (all sub-features inside)
   ];


  # Pass feature flags and package filter to all modules via _module.args.
  # Modules that need them declare: { features, filterPkgs, ... }:
  _module.args = { inherit features filterPkgs; };


  # ── Hardware profile wiring ─────────────────────────────────────────────────
  # Connects the feature flags above to gpu.nix's custom options.
  # These are the only two "wiring" lines that belong here rather than a module
  # because gpu.nix defines these options and cannot set its own options.
  gpu.kernelParams = features.kernelParams;
  gpu.driver       = features.gpu;


  # ===========================================================================
  # 📦 SYSTEM PACKAGES
  # ===========================================================================
  # Add packages here directly — the same as on a stock NixOS system.
  # These are merged with the module-assembled list in modules/system-packages.nix.
  # For larger curated groups, use the files under packages/ instead.
  #
  # Example:
  #   environment.systemPackages = with pkgs; [
  #     vim
  #     wget
  #     git
  #   ];
  #
  environment.systemPackages = with pkgs; [
    # put your packages here
  ];


  # ===========================================================================
  # 🚫 EXTRA DISABLED PACKAGES
  # ===========================================================================
  # Add package names here to block them from being installed anywhere.
  # These are merged with packages/disabled/disabled-packages.nix at eval time.
  # For permanent changes, use the CLI tools instead:
  #
  #   nixos-comment   <pkg>   → adds to packages/disabled/disabled-packages.nix
  #   nixos-uncomment <pkg>   → removes from packages/disabled/disabled-packages.nix
  #
  kool.disabledPackages = [
    # "discord"
    # "telegram-desktop"
  ];


  # ===========================================================================
  # 🧾 STATE VERSION
  # ===========================================================================
  # DO NOT CHANGE unless you are doing a NixOS release upgrade and know
  # exactly what stateful things will be migrated.
  #
  system.stateVersion = "25.11";

}
