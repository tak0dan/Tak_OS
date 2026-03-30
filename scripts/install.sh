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

# ── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { printf "${CYAN}[*]${RESET} %s\n"  "$*"; }
ok()    { printf "${GREEN}[✓]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
die()   { printf "${RED}[✗]${RESET} %s\n"   "$*" >&2; exit 1; }
step()  { printf "\n${BOLD}${CYAN}──── %s ────${RESET}\n" "$*"; }

# ── Root check ───────────────────────────────────────────────────────────────
[[ "${EUID}" -ne 0 ]] && die "Run as root:  sudo $0"

# ── Banner ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}"
cat << 'EOF'
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗      ╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝ ╚══════╝
         Fresh Install Bootstrap
EOF
printf "${RESET}\n"

# ── Auto-detect: username ────────────────────────────────────────────────────
# Priority: SUDO_USER (set when running via sudo) → logname → parse existing config
INSTALL_USER="${SUDO_USER:-}"

if [[ -z "$INSTALL_USER" ]]; then
    INSTALL_USER="$(logname 2>/dev/null || true)"
fi

if [[ -z "$INSTALL_USER" ]]; then
    # Last resort: pull the first isNormalUser entry from the live NixOS config.
    INSTALL_USER="$(
        grep -oP 'users\.users\.\K[a-z_][a-z0-9_-]+(?=\s*=\s*\{)' \
            "${TARGET_DIR}/configuration.nix" 2>/dev/null | head -1 || true
    )"
fi

[[ -z "$INSTALL_USER" ]] && die \
    "Could not auto-detect your username. Run the script with sudo rather than as root directly."

# ── Auto-detect: hostname ────────────────────────────────────────────────────
INSTALL_HOST="$(hostname -s 2>/dev/null || hostname)"
[[ -z "$INSTALL_HOST" ]] && die "Could not detect hostname."

# ── Auto-detect: target NixOS version from repo ─────────────────────────────
REPO_VERSION="$(
    grep -oP 'stateVersion\s*=\s*"\K[^"]+' \
        "${PROJECT_DIR}/configuration.nix" | head -1
)"
[[ -z "$REPO_VERSION" ]] && die \
    "Could not read system.stateVersion from ${PROJECT_DIR}/configuration.nix."

# ── Summary and confirmation ─────────────────────────────────────────────────
printf "Detected settings:\n\n"
printf "  ${BOLD}Username${RESET}        : ${CYAN}${INSTALL_USER}${RESET}\n"
printf "  ${BOLD}Hostname${RESET}        : ${CYAN}${INSTALL_HOST}${RESET}\n"
printf "  ${BOLD}Target NixOS${RESET}    : ${CYAN}${REPO_VERSION}${RESET}\n"
printf "  ${BOLD}Kernel params${RESET}   : ${CYAN}generic${RESET} (safe default — change in configuration.nix later)\n"
printf "\n"
read -rp "$(printf "${BOLD}Proceed with installation?${RESET} [Y/n] ")" _confirm
[[ "${_confirm,,}" == "n" ]] && die "Aborted."

# ============================================================================
# PHASE 1 — Channel upgrade + first rebuild (keeps your existing config)
# ============================================================================
step "Phase 1: Channel upgrade"

info "Adding nixos-${REPO_VERSION} channel…"
nix-channel --add "https://nixos.org/channels/nixos-${REPO_VERSION}" nixos

info "Adding home-manager channel (release-${REPO_VERSION})…"
nix-channel --add \
    "https://github.com/nix-community/home-manager/archive/release-${REPO_VERSION}.tar.gz" \
    home-manager

info "Updating channels…"
nix-channel --update
ok "Channels set to NixOS ${REPO_VERSION} + home-manager ${REPO_VERSION}."

info "Rebuilding your current config on NixOS ${REPO_VERSION} (safe baseline)…"
nixos-rebuild switch
ok "Phase 1 complete — system is running NixOS ${REPO_VERSION}."

# ============================================================================
# PHASE 2 — Patch project files, deploy Tak_OS, rebuild
# ============================================================================
step "Phase 2: Deploy Tak_OS"

# ── 2a. Patch project files ──────────────────────────────────────────────────
info "Patching project files…"

#   modules/users.nix
#     · users.users.tak_1  →  users.users.<user>
#     · users.groups.tak_1 →  users.groups.<user>
#     · group = "tak_1"    →  group = "<user>"
#     · description        →  username (clear the personal placeholder)
sed -i \
    -e "s/users\.users\.tak_1/users.users.${INSTALL_USER}/g" \
    -e "s/users\.groups\.tak_1/users.groups.${INSTALL_USER}/g" \
    -e "s/group = \"tak_1\"/group = \"${INSTALL_USER}\"/" \
    -e "s/description = \"Elder Evil\"/description = \"${INSTALL_USER}\"/" \
    "${PROJECT_DIR}/modules/users.nix"

#   modules/virtualbox.nix
#     · users.users.tak_1  →  users.users.<user>
sed -i \
    -e "s/users\.users\.tak_1/users.users.${INSTALL_USER}/g" \
    "${PROJECT_DIR}/modules/virtualbox.nix"

#   modules/networking.nix
#     · hostname placeholder  →  real hostname
#     · polkit user literals  →  real username (code + comments)
sed -i \
    -e "s/networking\.hostName = \"Tak0_NixOS\"/networking.hostName = \"${INSTALL_HOST}\"/" \
    -e "s/subject\.user == \"tak_1\"/subject.user == \"${INSTALL_USER}\"/" \
    -e "s/# Polkit allows tak_1/# Polkit allows ${INSTALL_USER}/" \
    -e "s/# Allow tak_1 to manage/# Allow ${INSTALL_USER} to manage/" \
    "${PROJECT_DIR}/modules/networking.nix"

#   configuration.nix
#     · home-manager-users "tak_1"  →  real username
#     · kernelParams "thinkpad"     →  "generic" (safe for any hardware)
sed -i \
    -e "s/\"tak_1\"/\"${INSTALL_USER}\"/" \
    -e 's/kernelParams = "thinkpad"/kernelParams = "generic"/' \
    "${PROJECT_DIR}/configuration.nix"

ok "Project files patched."

# ── 2b. Preserve machine-specific files before rsync ────────────────────────
info "Preserving hardware-configuration.nix and nixorcist cache…"

_tmpdir="$(mktemp -d /tmp/takos-install.XXXXXX)"
trap 'rm -rf "$_tmpdir"' EXIT

HW_CONF="${TARGET_DIR}/hardware-configuration.nix"
[[ -f "$HW_CONF" ]] && cp "$HW_CONF" "${_tmpdir}/hardware-configuration.nix"

NIXORCIST_CACHE="${TARGET_DIR}/nixorcist/cache"
NIXORCIST_GEN="${TARGET_DIR}/nixorcist/generated"
[[ -d "$NIXORCIST_CACHE" ]] && cp -a "$NIXORCIST_CACHE" "${_tmpdir}/nixorcist-cache"
[[ -d "$NIXORCIST_GEN"   ]] && cp -a "$NIXORCIST_GEN"   "${_tmpdir}/nixorcist-generated"

# ── 2c. Deploy project to /etc/nixos ────────────────────────────────────────
info "Deploying Tak_OS to ${TARGET_DIR}…"
rsync -a --delete "${PROJECT_DIR}/" "${TARGET_DIR}/"

# Restore preserved files
[[ -f "${_tmpdir}/hardware-configuration.nix" ]] && \
    cp "${_tmpdir}/hardware-configuration.nix" "$HW_CONF"

if [[ -d "${_tmpdir}/nixorcist-cache" ]]; then
    mkdir -p "${TARGET_DIR}/nixorcist/cache"
    cp -a "${_tmpdir}/nixorcist-cache/." "${TARGET_DIR}/nixorcist/cache/"
fi
if [[ -d "${_tmpdir}/nixorcist-generated" ]]; then
    mkdir -p "${TARGET_DIR}/nixorcist/generated"
    cp -a "${_tmpdir}/nixorcist-generated/." "${TARGET_DIR}/nixorcist/generated/"
fi

ok "Tak_OS deployed to ${TARGET_DIR}."

# ── 2d. Final rebuild into Tak_OS ───────────────────────────────────────────
info "Rebuilding into Tak_OS…"
nixos-rebuild switch
ok "Phase 2 complete — Tak_OS is active."

# ── Done ─────────────────────────────────────────────────────────────────────
printf "\n${BOLD}${GREEN}Installation complete!${RESET}\n\n"
printf "  ${BOLD}Hostname${RESET}  : ${CYAN}${INSTALL_HOST}${RESET}\n"
printf "  ${BOLD}User${RESET}      : ${CYAN}${INSTALL_USER}${RESET}\n"
printf "\n"
printf "Your home-manager scaffold will be written to:\n"
printf "  ${BOLD}/home/${INSTALL_USER}/.hm-local/home.nix${RESET}\n"
printf "Edit it freely — it won't be overwritten unless it is empty or broken.\n"
printf "\n"
printf "${YELLOW}Tip:${RESET} Open ${BOLD}configuration.nix${RESET} and set your GPU driver and kernel profile\n"
printf "when you know your hardware (currently set to safe generic defaults).\n\n"
