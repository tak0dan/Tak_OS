{ config, lib, pkgs, features, ... }:

let
  cfg = features.autoupdate;

  # ── schedule helpers ──────────────────────────────────────────────────────

  baseHours =
    if cfg.updates_per == "day"    then 24
    else if cfg.updates_per == "week"   then 24 * 7
    else if cfg.updates_per == "hour"   then 1
    else if cfg.updates_per == "month"  then 24 * 30
    else if cfg.updates_per == "custom" then cfg.custom.every_hours
    else 24;

  intervalHours =
    if cfg.update_times > 0
    then baseHours / cfg.update_times
    else baseHours;

  # Plain attrset via listToAttrs — avoids lib.mkMerge submodule overhead.
  # Each timer carries an explicit Unit so it triggers the correct service.
  timers = lib.listToAttrs (map (i: {
    name  = "takos-auto-upgrade-${toString i}";
    value = {
      wantedBy  = [ "timers.target" ];
      timerConfig = {
        Unit       = "takos-auto-upgrade.service";
        OnCalendar = "*-*-* ${toString (i * intervalHours)}:00:00";
        Persistent = true;
      } // lib.optionalAttrs cfg.randomDelay {
        RandomizedDelaySec = "20min";
      };
    };
  }) (lib.range 0 (cfg.update_times - 1)));


  # ── upgrade script ────────────────────────────────────────────────────────

  upgradeScript = pkgs.writeShellScript "takos-auto-upgrade" ''
    set -euo pipefail

    LOG="/var/log/takos-auto-upgrade.log"

    log() {
      printf '[%s] %s\n' "$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')" "$*" \
        | ${pkgs.coreutils}/bin/tee -a "$LOG"
    }

    ${lib.optionalString cfg.notify ''
    # Deliver a desktop notification to every active graphical session.
    # Exports env vars then calls notify-send as the session owner via su -m
    # (which preserves the caller's environment in the child shell).
    notify_all() {
      local summary="$1" body="$2" urgency="''${3:-normal}"
      local bus uid uname

      for bus in /run/user/*/bus; do
        [[ -S "$bus" ]] || continue
        uid="''${bus%/bus}"; uid="''${uid##*/run/user/}"
        uname=$(${pkgs.coreutils}/bin/id -nu "$uid" 2>/dev/null) || continue

        export DBUS_SESSION_BUS_ADDRESS="unix:path=''${bus}"
        export XDG_RUNTIME_DIR="/run/user/''${uid}"
        export NOTIFY_SUMMARY="''${summary}"
        export NOTIFY_BODY="''${body}"
        export NOTIFY_URGENCY="''${urgency}"

        ${pkgs.shadow}/bin/su -m "''${uname}" -s ${pkgs.bash}/bin/bash -c \
          '${pkgs.libnotify}/bin/notify-send \
            --app-name="Tak_OS Updater" \
            --icon="system-software-update" \
            --urgency="$NOTIFY_URGENCY" \
            "$NOTIFY_SUMMARY" "$NOTIFY_BODY"' \
          2>/dev/null || true
      done
    }
    ''}

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "🔄 Tak_OS auto-upgrade starting"
    ${lib.optionalString cfg.notify
      ''notify_all "🔄 System Update" "Running auto-upgrade…" low''}

    # ── run upgrade ───────────────────────────────────────────────────────

    EXIT_CODE=0
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade 2>&1 \
      | ${pkgs.coreutils}/bin/tee -a "$LOG" \
      || EXIT_CODE=$?

    # ── report result ─────────────────────────────────────────────────────

    if [[ $EXIT_CODE -eq 0 ]]; then
      log "✅ Upgrade completed successfully"
      ${lib.optionalString cfg.notify
        ''notify_all "✅ Update Complete" "System upgraded successfully." normal''}

      ${lib.optionalString cfg.allowReboot ''
      booted=$(${pkgs.coreutils}/bin/readlink /run/booted-system  2>/dev/null || true)
      current=$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system 2>/dev/null || true)
      if [[ -n "$booted" && "$booted" != "$current" ]]; then
        log "🔁 New kernel detected — rebooting in 60 s"
        ${lib.optionalString cfg.notify
          ''notify_all "🔁 Reboot Scheduled" "New kernel applied. Rebooting in 60 s." critical''}
        ${pkgs.coreutils}/bin/sleep 60
        ${pkgs.systemd}/bin/systemctl reboot
      fi
      ''}
    else
      log "❌ Upgrade failed (exit $EXIT_CODE)"
      log "   → journalctl -u takos-auto-upgrade -n 50"
      ${lib.optionalString cfg.notify
        ''notify_all "❌ Update Failed" "Auto-upgrade failed (exit $EXIT_CODE). Check logs." critical''}
    fi

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  '';

in
{
  config = lib.mkIf cfg.enable {

    systemd.services.takos-auto-upgrade = {
      description = "Tak_OS Auto Upgrade";
      serviceConfig = {
        Type             = "oneshot";
        ExecStart        = upgradeScript;
        StandardOutput   = "journal+console";
        StandardError    = "journal+console";
        SyslogIdentifier = "takos-auto-upgrade";
      };
    };

    systemd.timers = timers;

  };
}
