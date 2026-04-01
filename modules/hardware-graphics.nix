# Tak_OS · hardware-graphics.nix — hardware.graphics base (OpenGL / DRI) settings
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# HARDWARE-GRAPHICS.NIX — Base Mesa / VA-API acceleration
# ========================================================
# Enables hardware-accelerated rendering and 32-bit graphics libs
# (required for Steam and most games).
# GPU-specific driver config lives in modules/gpu.nix and its sub-modules.

{ ... }:
{
  hardware.graphics.enable      = true;
  hardware.graphics.enable32Bit = true;
}
