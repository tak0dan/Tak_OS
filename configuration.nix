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
# │    vm-guest-services (*), local-hardware-clock (*)                     │
# │    (*) imported but inactive until their own option is set             │
# │                                                                        │
# │  Loaded when features.uwu = true:                                      │
# │    modules/uwu/nixowos.nix                                             │
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

     # Optional hardware support (inactive until their enable option is set)
     ./modules/vm-guest-services.nix    # QEMU guest agent + SPICE
     ./modules/local-hardware-clock.nix # RTC in local time (dual-boot Windows)
   ]

   ++ lib.optionals features.uwu [
     ./modules/uwu/nixowos.nix
   ]

   ++ lib.optionals features.virtualisation [
     ./modules/virtualbox.nix  # VirtualBox host + Docker
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
