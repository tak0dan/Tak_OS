# =============================================================================
#  modules/rebuild-error-hook.nix
#
#  Hooks the nixos-rebuild error listener into the system WITHOUT modifying
#  the nix package manager or nixos-rebuild binary.
#
#  Mechanism:
#   1. system.activationScripts — ensures /var/log/nixos-rebuild-errors.log
#      exists with correct permissions on every nixos-rebuild switch.
#   2. security.sudo.extraConfig — prepends /etc/nixos/scripts to sudo's
#      secure_path so `sudo nixos-rebuild` resolves to the wrapper FIRST.
#   3. environment.shellAliases — catches direct (non-sudo) `nixos-rebuild`
#      calls from interactive shells (e.g. when already root in the VM).
#
#  The wrapper (/etc/nixos/scripts/nixos-rebuild) calls the real binary and
#  pipes all output through nixos-rebuild-error-listener.sh.  Errors are
#  appended to /var/log/nixos-rebuild-errors.log; all output reaches the
#  terminal unchanged.
# =============================================================================
{ ... }:
{
  # ── 1. Log file setup ───────────────────────────────────────────────────────
  system.activationScripts.nixosRebuildErrorLog = {
    text = ''
      LOG=/var/log/nixos-rebuild-errors.log
      if [ ! -f "$LOG" ]; then
        touch "$LOG"
        chmod 640  "$LOG"
        chown root:wheel "$LOG" 2>/dev/null || chown root:root "$LOG"
        echo "# NixOS rebuild error log — created $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
      fi
    '';
    deps = [];
  };

  # ── 2. sudo secure_path intercept ──────────────────────────────────────────
  # Prepends /etc/nixos/scripts so `sudo nixos-rebuild` hits our wrapper.
  # The wrapper is in scripts/ alongside nix-rebuild-smart.sh (which nixorcist
  # calls), so the symlink /etc/nixos/scripts → /etc/nixos/nixos-build/scripts
  # already created by the install script covers both.
  security.sudo.extraConfig = ''
    Defaults secure_path="/etc/nixos/scripts:/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  '';

  # ── 3. Shell alias for non-sudo interactive calls ──────────────────────────
  environment.shellAliases = {
    nixos-rebuild = "/etc/nixos/scripts/nixos-rebuild";
  };
}
