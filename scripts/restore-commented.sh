#!/usr/bin/env bash
# Tak_OS · restore-commented.sh — restore packages commented out during build
# github.com/tak0dan/Tak_OS · GNU GPLv3
set -euo pipefail

LOG="/etc/nixos/.auto-commented-packages.log"

[[ ! -f "$LOG" ]] && {
    echo "No log file found."
    exit 0
}

echo "Restoring commented packages..."

while IFS=: read -r file lineno var; do
    if [[ -f "$file" ]]; then
        sed -i "${lineno}s/^# AUTO-COMMENTED (${var}): //" "$file"
    fi
done < "$LOG"

rm -f "$LOG"

echo "Done. Now rebuild manually."
