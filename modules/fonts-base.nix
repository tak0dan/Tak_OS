# Tak_OS · fonts-base.nix — Core system fonts (Noto, DejaVu, emoji)
# github.com/tak0dan/Tak_OS · GNU GPLv3
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
