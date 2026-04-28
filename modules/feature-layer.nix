# Tak_OS · feature-layer.nix — Always-imported feature modules with internal guards
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Modules listed here stay in the graph regardless of whether their feature is
# enabled.  They are expected to guard their own config via features.* so the
# public interface remains stable while the import graph stays predictable.
{ ... }:
{
  imports = [
    ./kde.nix
    ./openssh.nix
    ./gaming.nix
    ./virtualbox.nix
    ./flatpak.nix
    ./auto-upgrade.nix
    ./copilot-cli.nix
  ];
}
