#!/usr/bin/env bash
set -euo pipefail

# Deploy nixos-build into /etc/nixos with rotating home backup.
# Behavior:
# 1) If ~/nixos-backup exists, rename it to ~/nixos-backup-before-<timestamp>
# 2) Create a fresh ~/nixos-backup from current /etc/nixos
# 3) Copy this nixos-build directory contents into /etc/nixos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="/etc/nixos"

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run as root (example: sudo $0)" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER" 2>/dev/null || true)"
if [[ -z "$TARGET_HOME" ]]; then
  echo "ERROR: Could not resolve home directory for user: $TARGET_USER" >&2
  exit 1
fi
if [[ -z "$TARGET_GROUP" ]]; then
  echo "ERROR: Could not resolve primary group for user: $TARGET_USER" >&2
  exit 1
fi

BACKUP_DIR="$TARGET_HOME/nixos-backup"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ROTATED_BACKUP_DIR="$TARGET_HOME/nixos-backup-before-$TIMESTAMP"
NIXORCIST_RUNTIME_DIR="$TARGET_DIR/nixorcist"
PRESERVE_ROOT="$(mktemp -d)"
PRESERVE_CACHE_DIR="$PRESERVE_ROOT/cache"
PRESERVE_GENERATED_DIR="$PRESERVE_ROOT/generated"

cleanup() {
  rm -rf "$PRESERVE_ROOT"
}
trap cleanup EXIT

echo "Deploy source: $BUILD_DIR"
echo "Deploy target: $TARGET_DIR"
echo "Backup owner: $TARGET_USER"
echo

if [[ -e "$BACKUP_DIR" ]]; then
  echo "Existing backup found: $BACKUP_DIR"
  echo "Renaming to: $ROTATED_BACKUP_DIR"
  mv "$BACKUP_DIR" "$ROTATED_BACKUP_DIR"
fi

if [[ -d "$TARGET_DIR" ]]; then
  echo "Creating fresh backup: $BACKUP_DIR"
  cp -a "$TARGET_DIR" "$BACKUP_DIR"
else
  echo "Target directory does not exist yet. Creating: $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  echo "Creating empty backup directory: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
fi

# Ensure backup ownership is with the invoking user, not root.
chown -R "$TARGET_USER":"$TARGET_GROUP" "$BACKUP_DIR"

if [[ -d "$NIXORCIST_RUNTIME_DIR/cache" ]]; then
  cp -a "$NIXORCIST_RUNTIME_DIR/cache" "$PRESERVE_CACHE_DIR"
fi
if [[ -d "$NIXORCIST_RUNTIME_DIR/generated" ]]; then
  cp -a "$NIXORCIST_RUNTIME_DIR/generated" "$PRESERVE_GENERATED_DIR"
fi

echo "Deploying build into $TARGET_DIR ..."
# --delete keeps /etc/nixos aligned with this build output.
rsync -a --delete "$BUILD_DIR/" "$TARGET_DIR/"

if [[ -d "$PRESERVE_CACHE_DIR" ]]; then
  rm -rf "$NIXORCIST_RUNTIME_DIR/cache"
  cp -a "$PRESERVE_CACHE_DIR" "$NIXORCIST_RUNTIME_DIR/cache"
fi
if [[ -d "$PRESERVE_GENERATED_DIR" ]]; then
  rm -rf "$NIXORCIST_RUNTIME_DIR/generated"
  cp -a "$PRESERVE_GENERATED_DIR" "$NIXORCIST_RUNTIME_DIR/generated"
fi

echo

echo "Deployment complete."
echo "Fresh backup: $BACKUP_DIR"
if [[ -e "$ROTATED_BACKUP_DIR" ]]; then
  echo "Previous backup rotated to: $ROTATED_BACKUP_DIR"
fi
