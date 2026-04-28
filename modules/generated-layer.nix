# Tak_OS · generated-layer.nix — Optional generated package layer
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# The generated layer is intentionally isolated from the canonical config.  This
# hub is the only place that bridges the user-owned manifest to nixorcist's
# generated output.
{ lib, features, ... }:
{
  imports = lib.optionals features.nixorcist [ ../nixorcist/generated/all-packages.nix ];
}
