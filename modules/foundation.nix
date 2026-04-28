# Tak_OS · foundation.nix — Always-loaded architectural foundation
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# This hub owns the always-present system graph.  It keeps configuration.nix
# small and preserves the distinction between:
#   - the public manifest (`features.*` in configuration.nix)
#   - the architectural hubs (files like this one)
#   - the implementation modules (bootloader.nix, networking.nix, zsh.nix, ...)
{ ... }:
{
  imports = [
    # --- Boot / platform ---
    ./bootloader.nix
    ./grub-theme.nix
    ./gpu.nix
    ./sddm.nix

    # --- Core system ---
    ./locale.nix
    ./networking.nix
    ../bluetooth.nix
    ./users.nix
    ./audio.nix
    ./hardware-graphics.nix
    ./keyring.nix

    # --- Shell / environment ---
    ./environment.nix
    ./zsh.nix
    ./rebuild-error-hook.nix
    ./nix-ld.nix
    ./nix-settings.nix

    # --- Base packages / local scaffolding ---
    ./fonts-base.nix
    ./system-packages.nix
    ./hm-local-bootstrap.nix
  ];
}
