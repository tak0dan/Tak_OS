#!/usr/bin/env bash
# =============================================================================
#  nixos-rebuild-error-listener.sh
#
#  Reads nixos-rebuild output from stdin.
#  Passes EVERYTHING to stdout unchanged (caller's terminal sees full output).
#  Writes ONLY error lines to the persistent error log.
#
#  Called automatically by /etc/nixos/scripts/nixos-rebuild (the wrapper).
#  That wrapper is found first in sudo's secure_path, so the full chain:
#    nixorcist → nix-rebuild-smart.sh → sudo nixos-rebuild → wrapper → here
# =============================================================================

LOG_FILE="${NIXOS_REBUILD_ERROR_LOG:-/var/log/nixos-rebuild-errors.log}"
SESSION_START=$(date '+%Y-%m-%d %H:%M:%S')
CMD_LABEL="${NIXOS_REBUILD_CMD:-nixos-rebuild}"

# ── Error patterns ────────────────────────────────────────────────────────────
# Covers nix evaluation errors, builder failures, activation errors.
ERROR_REGEX='(^error:|^Error:|^fatal error:|^Fatal error:'\
'|builder for .+ failed'\
'|build of .+ failed'\
'|^nix-env: error:'\
'|attribute .+ missing'\
'|undefined variable'\
'|syntax error,'\
'|type error:'\
'|infinite recursion'\
'|cannot find package'\
'|function called without required argument'\
'|value is .+ while .+ was expected'\
'|while evaluating'\
'| FAILED$'\
'|Failed to start'\
'|activation script snippet.*failed'\
'|nixos-rebuild: error:'\
'|systemctl.*failed)'

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"

# Simple size-based rotation: keep last run's log as .old when > 5 MB
if [[ -f "$LOG_FILE" ]] && (( $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) > 5242880 )); then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

{
    printf '\n'
    printf '═%.0s' {1..60}
    printf '\n'
    printf ' %s  %s\n' "$SESSION_START" "$CMD_LABEL"
    printf '═%.0s' {1..60}
    printf '\n'
} >> "$LOG_FILE"

# ── Main loop: read stdin, pass through, capture errors ───────────────────────
error_count=0

while IFS= read -r line || [[ -n "$line" ]]; do
    # Always pass the line to stdout — caller sees unmodified output
    printf '%s\n' "$line"

    # Check against error patterns (case-insensitive)
    if printf '%s' "$line" | grep -Eiq "$ERROR_REGEX"; then
        printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$line" >> "$LOG_FILE"
        (( error_count++ )) || true
    fi
done

# ── Footer ────────────────────────────────────────────────────────────────────
if (( error_count > 0 )); then
    printf '─%.0s' {1..60}    >> "$LOG_FILE"
    printf '\n'                >> "$LOG_FILE"
    printf ' ↑ %d error(s) captured\n' "$error_count" >> "$LOG_FILE"
else
    printf ' ✓ no errors detected\n' >> "$LOG_FILE"
fi
