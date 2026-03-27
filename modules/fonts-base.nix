# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# FONTS-BASE.NIX — Minimal always-present font set
# =================================================
# Loaded unconditionally. The full Hyprland font collection
# (Nerd fonts, CJK, icon fonts, etc.) lives in modules/fonts.nix
# and is only loaded when features.hyprland = true.

{ pkgs, ... }:
{
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono   # Main programming font
      nerd-fonts.symbols-only     # Extra glyphs / icons
    ];
  };
}
