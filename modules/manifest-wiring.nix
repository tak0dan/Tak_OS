# Tak_OS · manifest-wiring.nix — Public manifest wiring and shared module args
# github.com/tak0dan/Tak_OS
#
# Keeps configuration.nix as the public feature manifest while moving the
# mechanical cross-module wiring into one explicit ownership point.
#
# Public interface preserved:
#   - features.* remains the user-facing manifest surface
#   - filterPkgs remains globally available through _module.args
#
# SDDM is owned by modules/sddm.nix and loaded through foundation.nix.

{ features, filterPkgs, ... }:

{
  _module.args = {
    inherit features filterPkgs;
  };
}
