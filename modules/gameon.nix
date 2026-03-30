# Tak_OS · gameon.nix — GLF-OS-inspired gaming stack (NixOS module)
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#                           NixOS_GameOn Module
# =============================================================================
#
# Loaded exclusively when features.gameon.enable = true.
# Setting features.gameon.enable = false removes this module from the import
# list entirely — every change made here is automatically reverted.
#
# Sub-toggles (all require gameon.enable = true):
#
#   wine              Wine WoW64 Staging + winetricks
#   proton-ge         proton-ge-bin as Steam extraCompatPackage
#   launchers         Lutris / Heroic / Faugus / UMU / Oversteer (packages)
#   overlays          MangoHud / GOverlay / vkBasalt + vkBasalt compat symlinks
#   streaming         Full GStreamer codec pack + noisetorch
#   peripherals       xone / xpadneo / hid-tmff2 kernel mods; ratbagd; piper;
#                     opentabletdriver; steam-hardware; DualSense udev rules
#   openrgb           OpenRGB service (all-plugins build)
#   input-remapper    input-remapper daemon + polkit auto-grant + autoload unit
#   fanatec-wheel     hid-fanatecff kernel module (local source, off by default)
#   logitech-wheel    new-lg4ff force-feedback module  (local source, off by default)
#   sysctl-tweaks     Gaming-optimised kernel/vm sysctl values
#   zram              zram-swap (zstd, 25 % RAM, priority 5)
#   bfq-scheduler     BFQ I/O scheduler applied via udev on every block device
#   low-latency-audio PipeWire 256-sample fixed-quantum clock
#
# Source layout for out-of-tree kernel modules (no build-time fetching):
#   assets/kernel-modules/hid-fanatecff/   — git-cloned Fanatec driver source
#   assets/kernel-modules/new-lg4ff/       — git-cloned Logitech LG4FF source
#
# =============================================================================
{ config, lib, pkgs, features, ... }:

let
  gameon = features.gameon;

  # ── Fanatec hid-fanatecff kernel module (built from local source) ──────────
  fanatecModule = config.boot.kernelPackages.callPackage
    ({ stdenv, kernel, kmod, linuxConsoleTools }:
      let
        moduledir = "lib/modules/${kernel.modDirVersion}/kernel/drivers/hid";
      in
      stdenv.mkDerivation {
        pname   = "hid-fanatecff";
        version = "0.2.1";

        src = /etc/nixos/assets/kernel-modules/hid-fanatecff;

        hardeningDisable  = [ "pic" "format" ];
        nativeBuildInputs = kernel.moduleBuildDependencies;

        patchPhase = ''
          mkdir -p $out/lib/udev/rules.d
          mkdir -p $out/${moduledir}
          substituteInPlace Makefile \
            --replace "/etc/udev/rules.d" "$out/lib/udev/rules.d"
          substituteInPlace fanatec.rules \
            --replace "/usr/bin/evdev-joystick" \
                      "${linuxConsoleTools}/bin/evdev-joystick" \
            --replace "/bin/sh" "${stdenv.shell}"
          sed -i '/depmod/d' Makefile
        '';

        makeFlags = [
          "KVERSION=${kernel.modDirVersion}"
          "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          "MODULEDIR=$(out)/${moduledir}"
        ];

        meta = with lib; {
          description = "Fanatec HID force-feedback kernel module";
          license     = licenses.gpl2Only;
          platforms   = platforms.linux;
        };
      }
    ) {};

  # ── Logitech new-lg4ff kernel module (built from local source) ────────────
  lg4ffModule = config.boot.kernelPackages.callPackage
    ({ stdenv, kernel }:
      stdenv.mkDerivation {
        pname   = "new-lg4ff";
        version = "0-unstable-local";

        src = /etc/nixos/assets/kernel-modules/new-lg4ff;

        preBuild = ''
          substituteInPlace Makefile \
            --replace-fail "modules_install" \
                           "INSTALL_MOD_PATH=$out modules_install"
          sed -i '/depmod/d' Makefile
          sed -i "10i\\\trmmod hid-logitech 2> /dev/null || true"    Makefile
          sed -i "11i\\\trmmod hid-logitech-new 2> /dev/null || true" Makefile

          # Stub CONFIG_LOGIWHEELS_FF for kernels >= 6.15
          sed -i '1i\#ifndef CONFIG_LOGIWHEELS_FF\n#define CONFIG_LOGIWHEELS_FF 1\n#endif' hid-lg4ff.c
          sed -i '1i\#ifndef CONFIG_LOGIWHEELS_FF\n#define CONFIG_LOGIWHEELS_FF 1\n#endif' hid-lg.c
        '';

        nativeBuildInputs = kernel.moduleBuildDependencies;

        makeFlags = [
          "KVERSION=${kernel.modDirVersion}"
          "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        ];

        meta = with lib; {
          description = "Experimental Logitech force-feedback module (new-lg4ff)";
          license     = licenses.gpl2Only;
          platforms   = lib.platforms.linux;
          broken      = stdenv.hostPlatform.isAarch64;
        };
      }
    ) {};

in
lib.mkIf gameon.enable {

  # ── Kernel modules (peripherals) ───────────────────────────────────────────
  boot.extraModulePackages =
    lib.optionals (gameon.hardware.controllers) (with config.boot.kernelPackages; [
      hid-tmff2   # Thrustmaster T300/T500/TS-XW force-feedback
      xone        # Xbox One / Series wireless dongle driver
      xpadneo     # Xbox controller Bluetooth advanced driver
    ])
    ++ lib.optionals gameon.hardware.wheels.fanatec  [ fanatecModule ]
    ++ lib.optionals gameon.hardware.wheels.logitech [ lg4ffModule   ];

  boot.kernelModules =
    lib.optionals gameon.hardware.wheels.fanatec  [ "hid-fanatec"      ]
    ++ lib.optionals gameon.hardware.wheels.logitech [ "hid-logitech-new" ];

  # ── Fanatec udev + users.groups.games ──────────────────────────────────────
  services.udev.packages = lib.optionals gameon.hardware.wheels.fanatec [ fanatecModule ];

  users.groups.games = lib.mkIf gameon.hardware.wheels.fanatec {
    members = builtins.filter
      (u: config.users.users.${u}.isNormalUser)
      (builtins.attrNames config.users.users);
  };

  # ── Logitech wheel udev rule ────────────────────────────────────────────────
  services.udev.extraRules = lib.concatStringsSep "\n" (
    # DualSense / DualShock touchpad — ignore in libinput (always on)
    [''
      # USB
      ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      # Bluetooth
      ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '']
    ++ lib.optionals gameon.hardware.wheels.logitech [''
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c261", \
        RUN+="${pkgs.usb-modeswitch}/bin/usb_modeswitch -v 046d -p c261 -m 01 -r 01 -C 03 -M '0f00010142'"
    '']
    ++ lib.optionals gameon.system.ioScheduler [''
      ACTION=="add|change", SUBSYSTEM=="block", ATTR{queue/scheduler}="bfq"
    '']
  );

  # ── Hardware services ───────────────────────────────────────────────────────
  hardware.steam-hardware.enable   = lib.mkIf gameon.hardware.controllers true;
  hardware.opentabletdriver.enable = lib.mkIf gameon.hardware.controllers true;
  services.ratbagd.enable          = lib.mkIf gameon.hardware.controllers true;

  services.hardware.openrgb = lib.mkIf gameon.hardware.rgb {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
  };

  # ── OpenRGB package (for the service) ──────────────────────────────────────
  environment.systemPackages =
    lib.optionals gameon.hardware.rgb [ pkgs.openrgb-with-all-plugins ];

  # ── Input-remapper ──────────────────────────────────────────────────────────
  services.input-remapper = lib.mkIf gameon.hardware.remap {
    enable  = true;
    package = pkgs.input-remapper.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/share/applications/input-remapper-autoload.desktop
      '';
    });
  };

  # Allow users group to run input-remapper without a password prompt
  security.polkit.extraConfig = lib.mkIf gameon.hardware.remap ''
    polkit.addRule(function(action, subject) {
      if (action.id == "inputremapper" && subject.isInGroup("users")) {
        return polkit.Result.YES;
      }
      if (action.id == "org.freedesktop.policykit.exec" &&
          action.lookup("program").indexOf("input-remapper") !== -1 &&
          subject.isInGroup("users")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Autoload input-remapper profiles after graphical login
  systemd.user.services.input-remapper-autoload = lib.mkIf gameon.hardware.remap {
    description = "Autoload Input Remapper profiles";
    wantedBy    = [ "graphical-session.target" ];
    after       = [ "graphical-session.target" ];
    serviceConfig = {
      Type             = "oneshot";
      RemainAfterExit  = true;
      ExecStartPre     = "${pkgs.coreutils}/bin/sleep 3";
      ExecStart        = "${pkgs.input-remapper}/bin/input-remapper-control --command autoload";
    };
  };

  # ── Steam extras (proton-ge, session env, fire-and-forget compat paths) ────
  programs.steam = lib.mkIf features.steam {
    extraCompatPackages = lib.optionals gameon.compat.protonGE [ pkgs.proton-ge-bin ];
    package = lib.mkIf gameon.compat.protonGE (pkgs.steam.override {
      extraEnv = {
        TZ                           = ":/etc/localtime";
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
      };
    });
  };

  # ── vkBasalt GOverlay compatibility symlinks ────────────────────────────────
  # GOverlay hard-codes /usr/share and /usr/lib — neither exists on NixOS.
  system.activationScripts.gameon-vkbasalt-compat = lib.mkIf gameon.graphics.overlays {
    deps = [];
    text = ''
      mkdir -p /usr/share/vulkan/implicit_layer.d
      ln -sf /run/current-system/sw/share/vulkan/implicit_layer.d/vkBasalt.json \
             /usr/share/vulkan/implicit_layer.d/vkBasalt.json 2>/dev/null || true
      mkdir -p /usr/lib
      if [ -f "${pkgs.vkbasalt}/lib/libvkbasalt.so" ]; then
        ln -sf "${pkgs.vkbasalt}/lib/libvkbasalt.so" /usr/lib/libvkbasalt.so
      fi
    '';
  };

  # ── Gaming-optimised sysctl ─────────────────────────────────────────────────
  boot.kernel.sysctl = lib.mkIf gameon.system.sysctl {
    "vm.swappiness"                 = 10;
    "vm.vfs_cache_pressure"         = 50;
    "vm.dirty_bytes"                = 268435456;   # 256 MiB
    "vm.dirty_background_bytes"     = 67108864;    #  64 MiB
    "vm.dirty_writeback_centisecs"  = 1500;
    "vm.max_map_count"              = 16777216;     # Required by many modern games
    "kernel.split_lock_mitigate"    = 0;
    "kernel.nmi_watchdog"           = 0;
    "kernel.printk"                 = "3 3 3 3";
    "kernel.unprivileged_userns_clone" = 1;
  };

  # ── zram swap ───────────────────────────────────────────────────────────────
  zramSwap = lib.mkIf gameon.system.zram {
    enable        = true;
    algorithm     = "zstd";
    memoryPercent = 25;
    priority      = 5;
  };

  # ── Mesa shader cache size ──────────────────────────────────────────────────
  environment.variables = lib.mkIf gameon.system.sysctl {
    MESA_SHADER_CACHE_MAX_SIZE = "12G";
  };

  # ── PipeWire low-latency clock ──────────────────────────────────────────────
  services.pipewire.extraConfig.pipewire."92-gameon-low-latency" =
    lib.mkIf gameon.system.audio {
      "context.properties" = {
        "default.clock.rate"        = 48000;
        "default.clock.quantum"     = 256;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 256;
      };
    };

  # ── usbcore autosuspend off (audio/input stability) ─────────────────────────
  boot.kernelParams = lib.optionals gameon.system.audio [
    "usbcore.autosuspend=-1"
  ];

}
