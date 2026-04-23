#!/usr/bin/env bash
# Tak_OS · bootstrap.sh — Fully Hardened Bootstrap (Upgraded)

set -Eeuo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/tak0dan/Tak_OS"
DEST="${HOME}/Tak_OS"
BRANCH="${BRANCH:-main}"

INCLUDE_WALLPAPERS="ask"   # ask | yes | no
FORCE_RECLONE="${FORCE_RECLONE:-0}"
DRY_RUN="${DRY_RUN:-0}"
DEBUG="${DEBUG:-0}"

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { printf "[%s] %b\n" "$(date +%H:%M:%S)" "$*"; }
info() { log "${CYAN}[*]${RESET} $*"; }
ok()   { log "${GREEN}[✓]${RESET} $*"; }
warn() { log "${YELLOW}[!]${RESET} $*"; }
die()  { log "${RED}[✗]${RESET} $*" >&2; exit 1; }

debug() {
    [[ "$DEBUG" == "1" ]] && log "[DEBUG] $*"
}

trap 'die "Error on line $LINENO"' ERR

# ── Interrupt cleanup ────────────────────────────────────────────────────────
cleanup_on_interrupt() {
    warn "Interrupted — cleaning up incomplete repository"
    [[ -d "$DEST/.git" ]] && rm -rf "$DEST"
    exit 1
}
trap cleanup_on_interrupt INT TERM

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

# ── Git wrapper (Nix fallback) ──────────────────────────────────────────────
git_run() {
    if command -v git >/dev/null 2>&1; then
        run git "$@"
    else
        run nix --extra-experimental-features "nix-command flakes" \
            shell nixpkgs#git -c git "$@"
    fi
}

# ── Repo validation ─────────────────────────────────────────────────────────
is_repo_valid() {
    [[ -d "$DEST/.git" ]] || return 1

    git_run -C "$DEST" rev-parse HEAD >/dev/null 2>&1 || return 1

    [[ -f "$DEST/scripts/install.sh" ]] || return 1

    return 0
}

# ── Retry logic ─────────────────────────────────────────────────────────────
clone_with_retry() {
    local attempts=3
    local delay=2

    for ((i=1; i<=attempts; i++)); do
        info "Clone attempt $i/$attempts..."

        if "$@"; then
            return 0
        fi

        warn "Clone failed (attempt $i)"
        sleep "$delay"
    done

    die "Failed to clone repository after $attempts attempts"
}

# ── Wallpaper prompt ────────────────────────────────────────────────────────
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

# ── Clone using system Git ──────────────────────────────────────────────────
clone_native() {
    info "Cloning repository..."

    clone_with_retry git clone --branch "$BRANCH" "$REPO_URL" "$DEST"

    if [[ "$INCLUDE_WALLPAPERS" == "no" ]]; then
        info "Removing wallpapers..."
        run rm -rf "$DEST/assets/Wallpapers"
    fi
}

# ── Clone using Nix Git ─────────────────────────────────────────────────────
clone_with_nix() {
    warn "Git not found — using temporary Git via Nix"

    clone_with_retry nix \
        --extra-experimental-features "nix-command flakes" \
        shell nixpkgs#git -c \
        git clone --branch "$BRANCH" "$REPO_URL" "$DEST"

    if [[ "$INCLUDE_WALLPAPERS" == "no" ]]; then
        info "Removing wallpapers..."
        run rm -rf "$DEST/assets/Wallpapers"
    fi
}

# ── Clone controller ────────────────────────────────────────────────────────
clone_repo() {
    if [[ -d "$DEST" ]]; then
        if is_repo_valid && [[ "$FORCE_RECLONE" != "1" ]]; then
            warn "Valid repository exists — skipping clone"
            return
        else
            warn "Existing repo invalid or incomplete — cleaning up"
            run rm -rf "$DEST"
        fi
    fi

    if command -v git >/dev/null 2>&1; then
        clone_native
    else
        require_cmd nix
        clone_with_nix
    fi

    is_repo_valid || die "Repository clone succeeded but is invalid"

    ok "Repository cloned"
}

# ── Installer preflight ─────────────────────────────────────────────────────
preflight_check() {
    INSTALL_SCRIPT="${DEST}/scripts/install.sh"

    [[ -f "$INSTALL_SCRIPT" ]] \
        || die "Installer missing after clone"

    [[ -x "$INSTALL_SCRIPT" ]] || chmod +x "$INSTALL_SCRIPT"
}

# ── Installer ───────────────────────────────────────────────────────────────
run_installer() {
    preflight_check

    info "Launching installer..."
    run sudo "$DEST/scripts/install.sh"
}

# ── Banner ──────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}"
cat << 'EOF'
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗█████╗╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═══╝ ╚═════╝ ╚══════╝
         Bootstrap — Hardened Edition
EOF
printf "${RESET}\n"

# ── CLI Args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-wallpapers) INCLUDE_WALLPAPERS="yes" ;;
        --no-wallpapers)   INCLUDE_WALLPAPERS="no" ;;
        --force)           FORCE_RECLONE=1 ;;
        --dry-run)         DRY_RUN=1 ;;
        --branch)          BRANCH="$2"; shift ;;
        *) die "Unknown argument: $1" ;;
    esac
    shift
done

# ── Execution ───────────────────────────────────────────────────────────────
require_cmd curl
require_cmd sudo

check_network
prompt_wallpapers
clone_repo
run_installer

ok "Bootstrap completed successfully."
