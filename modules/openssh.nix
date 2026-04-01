# Tak_OS · openssh.nix — OpenSSH server — enabled only when features.ssh=true
# github.com/tak0dan/Tak_OS · GNU GPLv3
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
