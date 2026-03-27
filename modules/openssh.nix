# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# OPENSSH.NIX — SSH daemon
# ========================
# Activated when features.openssh = true (set in configuration.nix).
#
# ⚠️  Password authentication is ON — fine for LAN, risky on the internet.
#     Switch PasswordAuthentication to false and add your public key to
#     users.users.<name>.openssh.authorizedKeys.keys for exposed machines.

{ lib, features, ... }:
{
  services.openssh = lib.mkIf features.openssh {
    enable   = true;
    settings = {
      PermitRootLogin         = "no";
      PasswordAuthentication  = true;
    };
  };
}
