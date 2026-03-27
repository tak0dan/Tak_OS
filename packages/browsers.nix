# Tak_OS · browsers.nix — Web browsers
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs }:

with pkgs; [

  # =========================
  # Mainstream Browsers
  # =========================
  chromium   # Open-source base of Google Chrome (no Google services)
  firefox    # Mozilla Firefox — fast, extensible, standards-compliant

  # =========================
  # Privacy-Focused Browsers
  # =========================
  librewolf   # Firefox fork — hardened privacy and security defaults
  tor-browser # Tor Browser — anonymity via the Tor network

]
