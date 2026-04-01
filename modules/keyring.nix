# Tak_OS · keyring.nix — GNOME keyring / libsecret daemon
# github.com/tak0dan/Tak_OS · GNU GPLv3
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
