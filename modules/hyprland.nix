# Tak_OS · hyprland.nix — Hyprland desktop integration
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# HYPRLAND.NIX — Hyprland/system integration
# ==========================================
# Provides system-level integration required for Hyprland to
# function as a complete Wayland desktop session.
#
# Package ownership:
#   packages/hyprland.nix — Hyprland, Wayland applications and
#                           Hyprland-related packages
#
# Runtime/system integration:
#   programs.hyprland       — Hyprland NixOS integration
#   UWSM                     — Systemd-managed Wayland sessions
#   graphical-session.target — graphical user session lifecycle
#   wayland-session target   — Wayland session lifecycle
#   xdg-desktop-portal      — desktop portal integration
#
# Hyprland is used as a compositor/window manager, but Tak_OS
# treats it as a complete desktop session. This means graphical
# applications and user services must be able to integrate with
# systemd-user targets.
#
# UWSM is responsible for connecting the Hyprland session with
# these systemd targets. This is particularly important for
# services such as:
#   - KDE Polkit authentication agent
#   - desktop portals
#   - graphical-session user services
#   - XDG autostart applications
#
# Do not manually start graphical-session.target from the
# Hyprland configuration when UWSM is enabled.
#
# Hyprland's current systemd integration handles the session
# targets automatically.

{ pkgs, lib, features, ... }:

{
  # =========================
  # Hyprland
  # =========================
  #
  # Enables the NixOS Hyprland module.
  #
  # Besides providing the compositor itself, the NixOS module
  # performs system-level integration such as session files and
  # the required Wayland desktop environment infrastructure.
  #
  # UWSM integration is enabled so Hyprland becomes a properly
  # managed systemd user session rather than simply being started
  # as a standalone process.

  programs.hyprland = lib.mkIf features.hyprland {
    enable = true;
    withUWSM = true;

    # Enable XWayland for applications which still require the
    # X11 compatibility layer.
    xwayland.enable = true;
  };

  # =========================
  # Polkit — System Authentication
  # =========================
  #
  # Provides the system-wide authorization authority required
  # for privileged operations such as mounting filesystems
  # through Dolphin or other KDE applications.
  #
  # This declaration is independent of kde.nix so the Hyprland
  # module can function without the general KDE module.

  security.polkit.enable =
    lib.mkIf features.hyprland true;

  # =========================
  # KDE Polkit Authentication Agent
  # =========================
  #
  # Provides graphical authentication dialogs for applications
  # requiring elevated privileges under Hyprland.
  #
  # The service is attached to graphical-session.target so the
  # authentication agent starts together with the Wayland
  # session managed by UWSM.

  systemd.user.services.polkit-kde-agent =
    lib.mkIf features.hyprland {

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
  # UWSM — Universal Wayland
  # Session Manager
  # =========================
  #
  # UWSM connects standalone Wayland compositors with systemd.
  #
  # This provides the session lifecycle required by desktop
  # applications and user services.
  #
  # In particular, it allows Hyprland to activate:
  #
  #   graphical-session-pre.target
  #              ↓
  #   graphical-session.target
  #              ↓
  #   graphical-session services
  #
  # This is important for applications such as the KDE Polkit
  # authentication agent, which is attached to
  # graphical-session.target in kde.nix.
  #
  # programs.hyprland.withUWSM already configures the required
  # Hyprland/UWSM integration, so no manual systemd target
  # activation is required here.

  # =========================
  # Wayland Desktop Portal
  # =========================
  #
  # Provides desktop portal support for Wayland applications.
  #
  # Hyprland uses the Hyprland portal backend for compositor-
  # specific functionality such as screenshots, screen sharing
  # and other Wayland desktop integration.
  #
  # The KDE portal remains useful for KDE/Qt applications where
  # appropriate.
  #
  # Portal configuration belongs here because it is part of the
  # compositor/desktop-session integration rather than the KDE
  # application package set.

  xdg.portal = lib.mkIf features.hyprland {
    enable = true;

    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
  };
}
