# Tak_OS · manifest-wiring.nix — Public manifest wiring and shared module args
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Keeps configuration.nix as the public feature manifest while moving the
# mechanical cross-module wiring into one explicit ownership point.
#
# Public interface preserved:
#   - features.* remains the user-facing manifest surface
#   - filterPkgs remains globally available through _module.args
#   - gpu.kernelParams / gpu.driver still derive from features.kernelParams / features.gpu
#   - SDDM remains explicitly owned instead of relying on display-manager fallback
{ features, filterPkgs, ... }:
{
  _module.args = { inherit features filterPkgs; };

  gpu.kernelParams = features.kernelParams;
  gpu.driver       = features.gpu;

  sddm.enable = true;
}
