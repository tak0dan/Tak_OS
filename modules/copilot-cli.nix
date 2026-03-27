# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# COPILOT-CLI.NIX — GitHub Copilot CLI installation
# ==================================================
# Activated when features.copilot = true (set in configuration.nix).
# Runs on every rebuild so it can also clean up when the feature is disabled.
#
# Install:  curl -fsSL https://gh.io/copilot-install | bash
# Guard:    /var/lib/copilot-cli/.installed  (sentinel — runs only once)
# Binary:   /usr/local/bin/copilot
#
# ⚠️  Requires internet access on first activation.
#     To force re-install, remove: /var/lib/copilot-cli/.installed

{ pkgs, lib, features, ... }:
{
  system.activationScripts.copilot-cli.text = ''
    SENTINEL="/var/lib/copilot-cli/.installed"
    BINARY="/usr/local/bin/copilot"

    if [ "${lib.boolToString features.copilot}" = "true" ]; then
      if [ ! -f "$SENTINEL" ]; then
        echo "[*] Installing GitHub Copilot CLI..."
        mkdir -p /var/lib/copilot-cli
        ${pkgs.curl}/bin/curl -fsSL https://gh.io/copilot-install | ${pkgs.bash}/bin/bash
        touch "$SENTINEL"
        echo "[✓] GitHub Copilot CLI installed."
      fi
    else
      if [ -f "$SENTINEL" ] || [ -f "$BINARY" ]; then
        echo "[*] Removing GitHub Copilot CLI..."
        rm -f "$BINARY"
        rm -rf /var/lib/copilot-cli
        echo "[✓] GitHub Copilot CLI removed."
      fi
    fi
  '';
}
