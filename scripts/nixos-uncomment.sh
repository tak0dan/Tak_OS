#!/usr/bin/env bash
# Tak_OS · nixos-uncomment.sh — restore auto-commented package references
# github.com/tak0dan/Tak_OS · GNU GPLv3
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: sudo nixos-uncomment <package-name>"
  exit 1
fi

NAME="$1"
PKG_DIR="/etc/nixos/packages"

echo "[*] Restoring: $NAME"

files=$(grep -ril --include="*.nix" "nixos-comment: $NAME" "$PKG_DIR" || true)

if [[ -z "$files" ]]; then
  echo "[!] No managed entries found."
  exit 0
fi

for file in $files; do
  echo "[*] Processing $file"

  sed -i -E "
    s/^([[:space:]]*)# ([[:space:]]*(pkgs\.)?$NAME[[:space:];]*)[[:space:]]*# nixos-comment: $NAME$/\1\2/I
  " "$file"

done

echo "[✓] Restored."
