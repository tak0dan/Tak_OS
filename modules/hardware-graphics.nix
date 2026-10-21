# Tak_OS · hardware-graphics.nix — hardware.graphics base (OpenGL / DRI) settings
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# HARDWARE-GRAPHICS.NIX — Base Mesa / VA-API acceleration
# ========================================================
# Enables hardware-accelerated rendering and 32-bit graphics libs
# (required for Steam and most games).
# Hardware-specific driver policy belongs in the machine hardware configuration.

{ ... }:
{
  hardware.graphics.enable      = true;
  hardware.graphics.enable32Bit = true;
}
