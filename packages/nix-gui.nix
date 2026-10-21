{ lib, symlinkJoin, writeShellApplication, makeDesktopItem, nix }:

let
  launcher = writeShellApplication {
    name = "nix-gui";
    runtimeInputs = [ nix ];

    text = ''
      set -euo pipefail

      # Upstream nix-gui is currently stale; keep the launcher pinned so the
      # system package set stays reproducible enough for day-to-day use.
      flake_ref="github:nix-gui/nix-gui/f463b3e9683e3f3341bb0778c8f215de45441a92"
      config_path="/etc/nixos/configuration.nix"
      pkexec_bin="/run/wrappers/bin/pkexec"
      declare -a forwarded=()

      while [[ $# -gt 0 ]]; do
        case "$1" in
          -c|--config-path)
            if [[ $# -lt 2 ]]; then
              echo "nix-gui: $1 requires a value" >&2
              exit 1
            fi
            config_path="$2"
            forwarded+=("$1" "$2")
            shift 2
            ;;
          *)
            forwarded+=("$1")
            shift
            ;;
        esac
      done

      if [[ ! " ''${forwarded[*]} " =~ [[:space:]](--config-path|-c)[[:space:]] ]]; then
        forwarded=(--config-path "$config_path" "''${forwarded[@]}")
      fi

      export QT_QPA_PLATFORM="xcb"
      export QT_STYLE_OVERRIDE="Fusion"

      if [[ "''${NIX_GUI_LAUNCHED_AS_ROOT:-0}" != "1" && "$EUID" -ne 0 ]]; then
        exec "$pkexec_bin" env \
          NIX_GUI_LAUNCHED_AS_ROOT=1 \
          DISPLAY="''${DISPLAY:-}" \
          XAUTHORITY="''${XAUTHORITY:-}" \
          XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-}" \
          DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-}" \
          WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-}" \
          QT_QPA_PLATFORM="$QT_QPA_PLATFORM" \
          QT_STYLE_OVERRIDE="$QT_STYLE_OVERRIDE" \
          "$0" "''${forwarded[@]}"
      fi

      exec nix run --accept-flake-config "$flake_ref" -- "''${forwarded[@]}"
    '';

    meta = with lib; {
      description = "Pinned launcher for nix-gui, a graphical NixOS configuration editor";
      homepage = "https://github.com/nix-gui/nix-gui";
      license = licenses.mit;
      mainProgram = "nix-gui";
      platforms = platforms.linux;
    };
  };

  desktopItem = makeDesktopItem {
    name = "nix-gui";
    desktopName = "Nix GUI";
    genericName = "NixOS Configuration Editor";
    comment = "Browse and edit NixOS configuration options graphically";
    exec = "nix-gui";
    terminal = false;
    categories = [ "System" "Settings" "Utility" ];
    keywords = [ "NixOS" "Nix" "Configuration" "GUI" "Packages" ];
    icon = "system-software-install";
  };
in
symlinkJoin {
  name = "nix-gui";
  paths = [ launcher desktopItem ];
  meta = launcher.meta;
}
