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

SCAN_PATHS=(
  "$TARGET_DIR/configuration.nix"
  "$TARGET_DIR/modules"
  "$TARGET_DIR/packages"
)

COMMENT_LOG="$TARGET_DIR/.auto-commented-packages.log"
touch "$COMMENT_LOG"

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
        grep -oP 'users\.users\.\K[a-z_][a-z0-9_-]+' \
        "${TARGET_DIR}/configuration.nix" 2>/dev/null | head -1 || true
    )"
fi

[[ -z "$INSTALL_USER" ]] && die "Could not auto-detect username."

INSTALL_HOST="$(hostname -s 2>/dev/null || hostname)"

REPO_VERSION="$(
    grep -oP 'stateVersion\s*=\s*"\K[^"]+' \
    "${PROJECT_DIR}/configuration.nix" | head -1
)"

printf "Detected settings:\n\n"
printf "  Username : %s\n" "$INSTALL_USER"
printf "  Hostname : %s\n" "$INSTALL_HOST"
printf "  NixOS    : %s\n\n" "$REPO_VERSION"

read -rp "Proceed? [Y/n] " _confirm
[[ "${_confirm,,}" == "n" ]] && die "Aborted."

step "Phase 1: Channel upgrade"

nix-channel --add "https://nixos.org/channels/nixos-${REPO_VERSION}" nixos
nix-channel --add \
  "https://github.com/nix-community/home-manager/archive/release-${REPO_VERSION}.tar.gz" \
  home-manager
nix-channel --update

if ! nixos-rebuild build; then
    warn "Initial build failed — expected on fresh systems."
fi
ok "Phase 1 complete"

step "Phase 2: Deploy Tak_OS"

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
  "${PROJECT_DIR}/modules/networking.nix"

sed -i \
  -e "s/\"tak_1\"/\"${INSTALL_USER}\"/g" \
  -e 's/kernelParams = "thinkpad"/kernelParams = "generic"/' \
  "${PROJECT_DIR}/configuration.nix"

ok "Project files patched."

_tmpdir="$(mktemp -d)"
trap 'rm -rf "$_tmpdir"' EXIT

[[ -f "${TARGET_DIR}/hardware-configuration.nix" ]] && \
  cp "${TARGET_DIR}/hardware-configuration.nix" "$_tmpdir/"

rsync -a --delete "${PROJECT_DIR}/" "${TARGET_DIR}/"

[[ -f "$_tmpdir/hardware-configuration.nix" ]] && \
  cp "$_tmpdir/hardware-configuration.nix" "${TARGET_DIR}/"

ok "Deployment complete."

# ===========================
# 🔧 AUTO-FIX ENGINE (FIXED)
# ===========================
auto_fix() {
  local attempt=1
  local max=10

  while (( attempt <= max )); do
    info "Build attempt $attempt..."

    set +e
    LOG_FILE="$TARGET_DIR/build-attempt-${attempt}.log"

    nixos-rebuild build 2>&1 | tee "$LOG_FILE"
    RESULT=${PIPESTATUS[0]}
    RESULT=$?
    set -e

    if [[ $RESULT -eq 0 ]]; then
      ok "Build succeeded"
      return 0
    fi

    var=$(grep -oP "undefined variable '\K[^']+" build.log | head -1 || true)

    if [[ -z "$var" ]]; then
      warn "Unhandled error:"
      cat build.log
      return 1
    fi

    warn "Disabling package: $var"

    matches=$(grep -R --include="*.nix" -n "\b${var}\b" "${SCAN_PATHS[@]}" || true)

    if [[ -z "$matches" ]]; then
      warn "Could not locate '$var'"
      return 1
    fi

    echo "$matches"

    while IFS= read -r line; do
      file=$(cut -d: -f1 <<< "$line")
      lineno=$(cut -d: -f2 <<< "$line")

      if [[ -f "$file" ]] && \
         ! sed -n "${lineno}p" "$file" | grep -q "AUTO-COMMENTED"; then

        sed -i "${lineno}s/^/# AUTO-COMMENTED (${var}): /" "$file"
        echo "${file}:${lineno}:${var}" >> "$COMMENT_LOG"
      fi
    done <<< "$matches"

    ok "Disabled '$var'. Retrying..."

    ((attempt++))
  done

  return 1
}

# ===========================
# 🚀 FINAL BUILD
# ===========================
step "Final adaptive build"

if ! auto_fix; then
  die "Build failed even after auto-fix."
fi

nixos-rebuild switch
ok "Tak_OS installation complete"

# ===========================
# 🔄 RESTORE SCRIPT
# ===========================
RESTORE_SCRIPT="$TARGET_DIR/scripts/restore-commented.sh"

mkdir -p "$TARGET_DIR/scripts"

cat > "$RESTORE_SCRIPT" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG="/etc/nixos/.auto-commented-packages.log"

[[ ! -f "$LOG" ]] && { echo "No log."; exit 0; }

while IFS=: read -r file line var; do
  if [[ -f "$file" ]]; then
    sed -i "${line}s/^# AUTO-COMMENTED (${var}): //" "$file"
  fi
done < "$LOG"

rm -f "$LOG"

echo "Restored. Run nixos-rebuild switch."
EOF

chmod +x "$RESTORE_SCRIPT"

# ===========================
# 🔄 PROMPT RESTORE
# ===========================
printf "\nUncomment disabled packages now? [y/N] "
read -r restore_now

if [[ "${restore_now,,}" == "y" ]]; then
  "$RESTORE_SCRIPT"
  info "Rebuilding after restore..."
  nixos-rebuild switch
fi
