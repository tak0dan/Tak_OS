{ pkgs }:

with pkgs; [

  # =========================
  # Game Platform
  # NOTE: Steam is enabled via programs.steam in configuration.nix
  #       (feature flag). Do not add it here to avoid conflicts.
  # =========================

  # =========================
  # Gaming Utilities
  # =========================
  discover-overlay   # Discord overlay for Linux gaming
  mangohud           # In-game performance overlay (FPS, temps, VRAM, …)
  obs-studio         # Screen recording and live streaming
  wine               # Windows compatibility layer for running .exe files

  # =========================
  # Graphics Drivers (Vulkan)
  # =========================
  mesa                      # Open-source Mesa 3D graphics library
  vulkan-loader             # Vulkan ICD loader
  vulkan-tools              # Vulkan utilities (vulkaninfo, vkcube, …)
  vulkan-validation-layers  # Vulkan validation layers for debugging

  # 32-bit Vulkan — required for many Steam / Wine games
  pkgsi686Linux.mesa
  pkgsi686Linux.vulkan-loader

]
