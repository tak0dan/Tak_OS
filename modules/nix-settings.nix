# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# NIX-SETTINGS.NIX — Core Nix daemon / nixpkgs configuration
# ===========================================================
# Applies to every rebuild regardless of feature flags.
#
#   nixpkgs.config.allowUnfree  — required for Steam, CUDA, proprietary drivers
#   nix.settings                — flakes, download tuning, connection pool

{ ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size  = 324217728;  # 324 MiB — reduces re-fetches on slow links
    http-connections      = 50;
  };
}
