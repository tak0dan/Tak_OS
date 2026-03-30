#!/usr/bin/env bash
# Tak_OS · bootstrap.sh — Hardened Bootstrap Script
# github.com/tak0dan/Tak_OS · GNU GPLv3

set -Eeuo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/tak0dan/Tak_OS"
DEST="${HOME}/Tak_OS"
BRANCH="${BRANCH:-main}"

INCLUDE_WALLPAPERS="ask"   # ask | yes | no
DRY_RUN="${DRY_RUN:-0}"
FORCE_RECLONE="${FORCE_RECLONE:-0}"

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { printf "[%s] %b\n" "$(date +%H:%M:%S)" "$*"; }
info() { log "${CYAN}[*]${RESET} $*"; }
ok()   { log "${GREEN}[✓]${RESET} $*"; }
warn() { log "${YELLOW}[!]${RESET} $*"; }
die()  { log "${RED}[✗]${RESET} $*" >&2; exit 1; }

# ── Error handling ──────────────────────────────────────────────────────────
trap 'die "Error on line $LINENO"' ERR

cleanup() {
    if [[ -d "$DEST/.git" ]]; then
        warn "Cleaning up incomplete clone..."
        rm -rf "$DEST"
    fi
}
trap cleanup ERR

# ── Helpers ─────────────────────────────────────────────────────────────────
run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY] $*"
    else
        "$@"
    fi
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

check_network() {
    info "Checking internet connectivity..."
    curl -fsSL https://github.com >/dev/null || die "No internet access"
    ok "Network OK"
}

install_git() {
    if command -v git >/dev/null 2>&1; then
        ok "Git already installed"
        return
    fi

    warn "Git not found"

    # ── Nix (modern, flake-compatible)
    if command -v nix >/dev/null 2>&1; then
        info "Installing Git via nix profile..."

        run nix profile install nixpkgs#git \
            || warn "nix profile install failed"

        if command -v git >/dev/null 2>&1; then
            ok "Git installed via nix profile"
            return
        fi
    fi

    # ── Legacy nix-env fallback
    if command -v nix-env >/dev/null 2>&1; then
        info "Trying legacy nix-env..."

        run nix-env -iA nixpkgs.git \
            || warn "nix-env install failed"

        if command -v git >/dev/null 2>&1; then
            ok "Git installed via nix-env"
            return
        fi
    fi

    # ── Absolute fallback: bail out
    die "Git installation failed. Install it manually (nix profile install nixpkgs#git)"
}

prompt_wallpapers() {
    if [[ "$INCLUDE_WALLPAPERS" == "ask" ]]; then
        printf "${BOLD}Install wallpapers?${RESET} (~200MB) [Y/n]: "
        read -r answer || true
        case "${answer,,}" in
            n|no) INCLUDE_WALLPAPERS="no" ;;
            *)    INCLUDE_WALLPAPERS="yes" ;;
        esac
    fi
}

clone_repo() {
    if [[ -d "$DEST" && "$FORCE_RECLONE" != "1" ]]; then
        warn "Directory exists — skipping clone"
        return
    fi

    if [[ "$FORCE_RECLONE" == "1" && -d "$DEST" ]]; then
        warn "Force reclone enabled — removing existing directory"
        run rm -rf "$DEST"
    fi

    if [[ "$INCLUDE_WALLPAPERS" == "no" ]]; then
        info "Cloning without wallpapers..."

        run git clone --filter=blob:none --sparse \
            --branch "$BRANCH" "$REPO_URL" "$DEST"

        cd "$DEST" || die "cd failed"

        run git sparse-checkout set --cone
        run git sparse-checkout set . ':(exclude)assets/Wallpapers'

    else
        info "Cloning full repository..."

        run git clone --branch "$BRANCH" \
            "$REPO_URL" "$DEST"
    fi

    ok "Repository cloned"
}

run_installer() {
    INSTALL_SCRIPT="${DEST}/scripts/install.sh"

    [[ -f "$INSTALL_SCRIPT" ]] \
        || die "Installer not found: $INSTALL_SCRIPT"

    info "Launching installer..."
    run sudo "$INSTALL_SCRIPT"
}

# ── Banner ──────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}"
cat << 'EOF'
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗      ╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝ ╚══════╝
         Bootstrap — Hardened Edition
EOF
printf "${RESET}\n"

# ── CLI Arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-wallpapers) INCLUDE_WALLPAPERS="yes" ;;
        --no-wallpapers)   INCLUDE_WALLPAPERS="no" ;;
        --dry-run)         DRY_RUN=1 ;;
        --force)           FORCE_RECLONE=1 ;;
        --branch)          BRANCH="$2"; shift ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
    shift
done

# ── Execution Flow ───────────────────────────────────────────────────────────
require_cmd curl
require_cmd sudo

check_network
install_git
prompt_wallpapers
clone_repo
run_installer

ok "Bootstrap completed successfully."
