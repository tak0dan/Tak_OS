#!/usr/bin/env bash
# Tak_OS · install.sh — Fresh-install bootstrap
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Run once after cloning the repo on a fresh NixOS machine.
# No manual file editing required — everything is detected and patched automatically.
#
# What this script does:
#   Phase 1 — Channel upgrade
#     · Detects your username, hostname and the NixOS version the repo targets.
#     · Adds nixos-<version> and home-manager channels.
#     · Rebuilds your *existing* NixOS config on the new channel (safe baseline).
#
#   Phase 2 — Tak_OS deployment
#     · Patches modules/users.nix, modules/networking.nix and configuration.nix
#       with your real username and hostname (replaces the repo placeholders).
#     · Defaults kernelParams to "generic" — safe for any hardware.
#     · Deploys the config to /etc/nixos, preserving hardware-configuration.nix
#       and any cached nixorcist data.
#     · Rebuilds into Tak_OS.
#
# Usage:
#   sudo bash /path/to/Tak_OS/scripts/install.sh
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="/etc/nixos"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { printf "${CYAN}[*]${RESET} %s\n"  "$*"; }
ok()    { printf "${GREEN}[✓]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
die()   { printf "${RED}[✗]${RESET} %s\n"   "$*" >&2; exit 1; }
step()  { printf "\n${BOLD}${CYAN}──── %s ────${RESET}\n" "$*"; }

[[ "${EUID}" -ne 0 ]] && die "Run as root: sudo $0"

INSTALL_USER="${SUDO_USER:-}"
[[ -z "$INSTALL_USER" ]] && INSTALL_USER="$(logname 2>/dev/null || true)"

if [[ -z "$INSTALL_USER" ]]; then
    INSTALL_USER="$(
        grep -oP 'users\.users\.\K[a-z_][a-z0-9_-]+(?=\s*=\s*\{)' \
            "${TARGET_DIR}/configuration.nix" 2>/dev/null | head -1 || true
    )"
fi

[[ -z "$INSTALL_USER" ]] && die "Could not auto-detect your username."

INSTALL_HOST="$(hostname -s 2>/dev/null || hostname)"
[[ -z "$INSTALL_HOST" ]] && die "Could not detect hostname."

REPO_VERSION="$(
    grep -oP 'stateVersion\s*=\s*"\K[^"]+' \
        "${PROJECT_DIR}/configuration.nix" | head -1
)"
[[ -z "$REPO_VERSION" ]] && die "Could not read system.stateVersion."

printf "Detected settings:\n\n"
printf "  Username     : ${INSTALL_USER}\n"
printf "  Hostname     : ${INSTALL_HOST}\n"
printf "  NixOS        : ${REPO_VERSION}\n\n"

read -rp "Proceed? [Y/n] " _confirm
[[ "${_confirm,,}" == "n" ]] && die "Aborted."

step "Phase 1: Channel upgrade"

nix-channel --add "https://nixos.org/channels/nixos-${REPO_VERSION}" nixos
nix-channel --add \
  "https://github.com/nix-community/home-manager/archive/release-${REPO_VERSION}.tar.gz" \
  home-manager
nix-channel --update

nixos-rebuild switch
ok "Phase 1 complete"

step "Phase 2: Deploy Tak_OS"

info "Patching project files…"

sed -i \
  -e "s/users\.users\.tak_1/users.users.${INSTALL_USER}/g" \
  -e "s/description = \"Elder Evil\"/description = \"${INSTALL_USER}\"/" \
  "${PROJECT_DIR}/modules/users.nix"

sed -i \
  -e "s/networking\.hostName = \"Tak0_NixOS\"/networking.hostName = \"${INSTALL_HOST}\"/" \
  -e "s/subject\.user == \"tak_1\"/subject.user == \"${INSTALL_USER}\"/" \
  "${PROJECT_DIR}/modules/networking.nix"

sed -i \
  -e "s/\"tak_1\"/\"${INSTALL_USER}\"/g" \
  -e 's/kernelParams = "thinkpad"/kernelParams = "generic"/' \
  "${PROJECT_DIR}/configuration.nix"

ok "Project files patched."

info "Preserving hardware config…"

_tmpdir="$(mktemp -d)"
trap 'rm -rf "$_tmpdir"' EXIT

[[ -f "${TARGET_DIR}/hardware-configuration.nix" ]] && \
  cp "${TARGET_DIR}/hardware-configuration.nix" "$_tmpdir/"

rsync -a --delete "${PROJECT_DIR}/" "${TARGET_DIR}/"

[[ -f "$_tmpdir/hardware-configuration.nix" ]] && \
  cp "$_tmpdir/hardware-configuration.nix" "${TARGET_DIR}/"

ok "Deployment complete."

# ===========================
# 🔍 VALIDATION + AUTO-FIX
# ===========================
step "Validating user consistency"

LEFTOVERS="$(grep -R "users.users.tak_1" "$TARGET_DIR" || true)"

if [[ -n "$LEFTOVERS" ]]; then
    warn "Leftover tak_1 references found:"
    printf "%s\n" "$LEFTOVERS"

    printf "\nAttempt automatic fix? [y/N] "
    read -r _fix

    if [[ "${_fix,,}" == "y" ]]; then
        info "Fixing user references safely…"

        find "$TARGET_DIR" -type f -name "*.nix" -exec sed -i \
          -e "s/users\.users\.tak_1/users.users.${INSTALL_USER}/g" \
          -e "s/users\.users\.tak_1\./users.users.${INSTALL_USER}./g" \
          {} +

        ok "Auto-fix applied."
    else
        die "Aborted due to inconsistent config."
    fi
fi

# Catch sneaky attribute definitions
if grep -R "tak_1\s*=" "$TARGET_DIR" | grep "users.users" >/dev/null; then
    warn "Possible attribute-style leftover (users.users = { tak_1 = ... }) detected."
fi

# Hard fail if still broken
if grep -R "users.users.tak_1" "$TARGET_DIR" >/dev/null; then
    die "Refusing to rebuild: unresolved tak_1 references remain."
fi

ok "User config validated."

# ===========================
# 🚀 REBUILD
# ===========================
info "Rebuilding system…"
nixos-rebuild switch

ok "Tak_OS installation complete"