# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# HM-LOCAL-BOOTSTRAP.NIX — ~/.hm-local directory scaffold
# ========================================================
# Runs on every rebuild regardless of features.home-manager so that:
#   • Directories exist before home-manager first activates.
#   • Disabling home-manager never removes them (NixOS activation never
#     deletes directories it did not create declaratively).
#
# On every rebuild, for each user in features.home-manager-users:
#   • Creates ~/.hm-local/ if missing.
#   • Writes a scaffold home.nix if the file is missing, empty,
#     or contains a Nix syntax error — so a broken file never blocks a rebuild.
#   • Scaffold content is read from modules/hm-home-scaffold.nix.
#   • Fixes ownership so the user can edit/delete without sudo.

{ lib, pkgs, features, ... }:
{
  system.activationScripts.hm-local-dirs.text =
    lib.concatMapStrings (user: ''
      # ── directory ────────────────────────────────────────────────────────
      if [ ! -d "/home/${user}/.hm-local" ]; then
        mkdir -p "/home/${user}/.hm-local"
        echo "[*] Created /home/${user}/.hm-local"
      fi

      # ── scaffold home.nix ────────────────────────────────────────────────
      # Write the scaffold if:
      #   • neither home.nix nor default.nix exists, OR
      #   • home.nix exists but is empty or has a syntax error
      _needs_scaffold=0
      if [ ! -f "/home/${user}/.hm-local/home.nix" ] && \
         [ ! -f "/home/${user}/.hm-local/default.nix" ]; then
        _needs_scaffold=1
      elif [ -f "/home/${user}/.hm-local/home.nix" ]; then
        if [ ! -s "/home/${user}/.hm-local/home.nix" ]; then
          echo "[!] /home/${user}/.hm-local/home.nix is empty — recreating scaffold"
          _needs_scaffold=1
        else
          _nix_inst=$(command -v nix-instantiate 2>/dev/null || echo /run/current-system/sw/bin/nix-instantiate)
          if ! "$_nix_inst" --parse "/home/${user}/.hm-local/home.nix" \
               > /dev/null 2>&1; then
            echo "[!] /home/${user}/.hm-local/home.nix has a syntax error — recreating scaffold"
            _needs_scaffold=1
          fi
        fi
      fi

      if [ "$_needs_scaffold" = "1" ]; then
        _hm_tmp=$(mktemp "/home/${user}/.hm-local/.home.nix.XXXXXX")
        cat > "$_hm_tmp" << 'HMEOF'
${builtins.readFile ./hm-home-scaffold.nix}HMEOF
        mv -f "$_hm_tmp" "/home/${user}/.hm-local/home.nix"
        echo "[*] Wrote /home/${user}/.hm-local/home.nix (scaffold)"
      fi

      # ── ownership: user must be able to edit/delete without sudo ─────────
      chown -R "${user}:" "/home/${user}/.hm-local"
      chmod  u+rwX        "/home/${user}/.hm-local"
    '') features.home-manager-users;
}
