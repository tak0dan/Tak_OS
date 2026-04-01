#!/usr/bin/env bash
# Tak_OS · nixos-comment.sh — auto-comment broken package references
# github.com/tak0dan/Tak_OS · GNU GPLv3
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: sudo nixos-comment <package-name>"
  exit 1
fi

NAME="$1"
PKG_DIR="/etc/nixos/packages"

echo "[*] Target: $NAME"
echo "[*] Scanning $PKG_DIR ..."

files=$(grep -ril --include="*.nix" -i "$NAME" "$PKG_DIR" || true)

if [[ -z "$files" ]]; then
  echo "[!] No matches found."
  exit 0
fi

for file in $files; do
  echo "[*] Processing $file"

  # Match:
  #   steam
  #   pkgs.steam
  # But NOT already commented lines

  sed -i -E "
    s/^([[:space:]]*)(pkgs\.)?$NAME([[:space:];]*)$/\1# \2$NAME\3  # nixos-comment: $NAME/I
  " "$file"

done

echo "[✓] Done."
