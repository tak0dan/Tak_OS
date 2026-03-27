# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# KEYRING.NIX — GNOME Keyring (secret storage daemon)
# ====================================================
# Provides a secure store for passwords, keys, and certificates.
# Used by many apps (browsers, SSH agents, git credentials) regardless
# of whether GNOME/KDE is the desktop environment.

{ ... }:
{
  services.gnome.gnome-keyring.enable = true;
}
