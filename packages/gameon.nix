# Tak_OS · gameon.nix — GLF-OS-inspired gaming package stack
# github.com/tak0dan/Tak_OS · GNU GPLv3
# =============================================================================
#
# Loaded when features.gameon.enable = true.  Every group below is gated by
# its own sub-toggle so individual stacks can be enabled / disabled without
# touching the others.
#
# Package groups (all require features.gameon.enable = true):
#
#   compat.wine      — Wine WoW64 Staging + winetricks
#   compat.protonGE  — Proton-GE extra compat tool for Steam
#   launchers        — Lutris, Heroic, Faugus, UMU launcher, Oversteer
#   graphics.overlays   — MangoHud, GOverlay, vkBasalt, vulkan-tools, mesa-demos
#   hardware.controllers — Piper (mouse), OpenTabletDriver, linuxConsoleTools
#   graphics.streaming   — Full GStreamer codec pack + noisetorch
#
# Hardware services (gameon.nix module):
#   hardware.rgb / hardware.remap / hardware.wheels.fanatec / hardware.wheels.logitech
#
# =============================================================================
{ pkgs, features }:

let
  gameon = features.gameon;
  go     = gameon.enable;
in

# ── Wine stack ──────────────────────────────────────────────────────────────
(pkgs.lib.optionals (go && gameon.compat.wine) (with pkgs; [
  wineWow64Packages.staging   # WoW64 Wine with staging patches (32+64-bit)
  winetricks                  # DLL/runtime installer for Wine prefixes
]))

# ── Proton-GE ───────────────────────────────────────────────────────────────
++ (pkgs.lib.optionals (go && gameon.compat.protonGE) (with pkgs; [
  proton-ge-bin               # Custom Proton build with extra game patches
]))

# ── Game launchers ───────────────────────────────────────────────────────────
++ (pkgs.lib.optionals (go && gameon.launchers) (with pkgs; [
  lutris                      # Multi-platform game launcher (GOG, Wine, etc.)
  heroic                      # Native GOG / Epic / Amazon launcher
  faugus-launcher             # Lightweight Windows-app launcher via Steam Runtime
  umu-launcher                # Unified launcher: Steam Linux Runtime + Proton
  oversteer                   # Steering-wheel profile manager (udev/evdev)
]))

# ── Performance overlays ─────────────────────────────────────────────────────
++ (pkgs.lib.optionals (go && gameon.graphics.overlays) (with pkgs; [
  mangohud                    # FPS/GPU/CPU Vulkan+OpenGL overlay
  goverlay                    # GUI configurator for MangoHud and vkBasalt
  vkbasalt                    # Vulkan post-processing (sharpening, CAS, SMAA…)
  vulkan-tools                # vulkaninfo, vkcube — required by goverlay/vkbasalt
  mesa-demos                  # glxgears, glxinfo — quick hardware sanity checks
]))

# ── Peripheral tools ─────────────────────────────────────────────────────────
++ (pkgs.lib.optionals (go && gameon.hardware.controllers) (with pkgs; [
  piper                       # Ratbag GUI — configure gaming mice profiles
  opentabletdriver            # Drawing-tablet driver (Wacom, XP-Pen, Huion…)
  linuxConsoleTools           # evdev-joystick — needed by Fanatec udev rules
]))

# ── Full GStreamer codec pack + noise suppression ─────────────────────────────
++ (pkgs.lib.optionals (go && gameon.graphics.streaming) (with pkgs; [
  gst_all_1.gstreamer
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-good
  gst_all_1.gst-plugins-bad
  gst_all_1.gst-plugins-ugly
  gst_all_1.gst-libav
  gst_all_1.gst-vaapi
  noisetorch                  # Real-time microphone noise suppression
]))
