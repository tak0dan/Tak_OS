#!/usr/bin/env bash
# Tak_OS · bootstrap.sh — Clone the repo and launch the installer
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# One-liner usage (run from any machine):
#   bash <(curl -fsSL https://raw.githubusercontent.com/tak0dan/Tak_OS/main/scripts/bootstrap.sh)
#
# What this script does:
#   1. Checks whether ~/Tak_OS already exists; skips cloning if it does.
#   2. Asks whether you want to include wallpapers (~200 MB extra).
#      · Yes → full clone
#      · No  → sparse clone that excludes assets/Wallpapers
#   3. Runs scripts/install.sh as root to bootstrap the system.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_URL="https://github.com/tak0dan/Tak_OS"
DEST="${HOME}/Tak_OS"

# ── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { printf "${CYAN}[*]${RESET} %s\n"  "$*"; }
ok()    { printf "${GREEN}[✓]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
die()   { printf "${RED}[✗]${RESET} %s\n"   "$*" >&2; exit 1; }

# ── Banner ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}"
cat << 'EOF'
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗      ╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝ ╚══════╝
         Bootstrap — Clone & Install
EOF
printf "${RESET}\n"

# ── Step 1: Clone (if needed) ────────────────────────────────────────────────
if [[ -d "$DEST" ]]; then
    warn "Directory ${BOLD}${DEST}${RESET}${YELLOW} already exists — skipping clone, using existing copy."
else
    # ── Step 2: Wallpaper prompt ─────────────────────────────────────────────
    printf "${BOLD}Install wallpapers?${RESET} "
    printf "(assets/Wallpapers, ~200 MB extra) [Y/n] "
    read -r _wp

    if [[ "${_wp,,}" == "n" ]]; then
        info "Cloning repository without wallpapers…"
        git clone --filter=blob:none --no-checkout "$REPO_URL" "$DEST"
        cd "$DEST"
        git sparse-checkout set --no-cone '/*' '!/assets/Wallpapers'
        git checkout
        ok "Cloned (wallpapers excluded)."
    else
        info "Cloning full repository (including wallpapers)…"
        git clone "$REPO_URL" "$DEST"
        ok "Cloned (full)."
    fi
fi

# ── Step 3: Run installer ────────────────────────────────────────────────────
INSTALL_SCRIPT="${DEST}/scripts/install.sh"
[[ -f "$INSTALL_SCRIPT" ]] || die "Installer not found at ${INSTALL_SCRIPT}. Is the clone complete?"

info "Launching installer…"
sudo bash "$INSTALL_SCRIPT"
