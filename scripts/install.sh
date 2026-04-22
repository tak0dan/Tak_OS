#!/usr/bin/env bash
# Tak_OS · install.sh v4 — declarative installer with discovered-user export
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Phases:
#   1  Channel upgrade
#   2  TUI host / GPU review + discovered-user export preview
#   3  Generate per-user .nix files + user-list.nix + users hub + patch imports + hostname + GPU
#   4  Deploy PROJECT_DIR → /etc/nixos
#   5  Adaptive build
#   6  Switch
#   7  Optional restore of auto-commented packages
#
# Usage:  sudo bash /path/to/Tak_OS/scripts/install.sh [--fallback]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="/etc/nixos"
USERS_DIR="${TARGET_DIR}/users-declared"
DISCOVER_USERS_SCRIPT="${PROJECT_DIR}/scripts/discover-users.sh"

SCAN_PATHS=("$TARGET_DIR/configuration.nix" "$TARGET_DIR/modules" "$TARGET_DIR/packages")
COMMENT_LOG="$TARGET_DIR/.auto-commented-packages.log"
touch "$COMMENT_LOG" 2>/dev/null || true

FALLBACK_MODE="false"
[[ "${1:-}" == "--fallback" ]] && FALLBACK_MODE="true"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()  { printf "${CYAN}[*]${RESET} %s\n"  "$*"; }
ok()    { printf "${GREEN}[✓]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
die()   { printf "${RED}[✗]${RESET} %s\n"   "$*" >&2; exit 1; }
step()  { printf "\n${BOLD}${CYAN}──── %s ────${RESET}\n" "$*"; }

[[ "${EUID}" -ne 0 ]] && die "Run as root: sudo $0"

if   command -v whiptail &>/dev/null; then TUI="whiptail"
elif command -v dialog   &>/dev/null; then TUI="dialog"
else                                       TUI="plain"
fi
_tui() { "$TUI" "$@" 3>&1 1>&2 2>&3; }

tui_msg() {
  local title="$1" msg="$2"
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --msgbox "$msg" 18 90
  else printf "\n=== %s ===\n%s\n" "$title" "$msg" >&2
       read -rp "[Enter to continue] " _r < /dev/tty; fi
}
tui_input() {
  local title="$1" prompt="$2" default="$3"
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --inputbox "$prompt" 10 65 "$default"
  else printf "\n=== %s ===\n" "$title" >&2
       read -rp "$prompt [$default]: " _r < /dev/tty; echo "${_r:-$default}"; fi
}
tui_yesno() {
  local title="$1" prompt="$2"
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --yesno "$prompt" 10 72; return $?
  else printf "\n=== %s ===\n%s\n" "$title" "$prompt" >&2
       read -rp "[y/N]: " _r < /dev/tty; [[ "${_r,,}" == "y" ]]; return $?; fi
}
tui_radio() {
  local title="$1" prompt="$2"; shift 2
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --radiolist "$prompt" 15 65 8 "$@"
  else
    local default="" i=1; local -a tags=() args=("$@")
    printf "\n=== %s ===\n%s\n" "$title" "$prompt" >&2
    while [[ ${#args[@]} -gt 0 ]]; do
      printf "  %d) %s  (%s)\n" "$i" "${args[0]}" "${args[1]}" >&2
      tags+=("${args[0]}"); [[ "${args[2]}" == "ON" ]] && default="$i"
      args=("${args[@]:3}"); ((i++))
    done
    while true; do
      read -rp "Select [${tags[$((default-1))]}]: " _r < /dev/tty
      _r="${_r:-$default}"
      if [[ "$_r" =~ ^[0-9]+$ ]] && (( _r >= 1 && _r < i )); then
        echo "${tags[$((_r-1))]}"; return; fi
      printf "  Invalid selection.\n" >&2
    done; fi
}
tui_menu() {
  local title="$1" prompt="$2"; shift 2
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --menu "$prompt" 20 78 12 "$@"
  else
    local i=1; local -a tags=() args=("$@")
    printf "\n=== %s ===\n%s\n" "$title" "$prompt" >&2
    while [[ ${#args[@]} -gt 0 ]]; do
      printf "  %d) %-24s %s\n" "$i" "${args[0]}" "${args[1]}" >&2
      tags+=("${args[0]}"); args=("${args[@]:2}"); ((i++))
    done
    while true; do
      read -rp "Select [1]: " _r < /dev/tty; _r="${_r:-1}"
      if [[ "$_r" =~ ^[0-9]+$ ]] && (( _r >= 1 && _r < i )); then
        echo "${tags[$((_r-1))]}"; return; fi
      printf "  Invalid selection.\n" >&2
    done; fi
}

REPO_VERSION="$(grep -oP 'stateVersion\s*=\s*"\K[^"]+' "${PROJECT_DIR}/configuration.nix" | head -1)"
[[ -x "$DISCOVER_USERS_SCRIPT" ]] || chmod +x "$DISCOVER_USERS_SCRIPT" 2>/dev/null || true

FEATURE_DEFAULTS=(
  "KDE=true"
  "STEAM=false"
  "VIRTUALISATION=false"
  "FLATPAK=true"
  "NIXORCIST=false"
  "COPILOT=false"
  "GAMEON_STREAMING=false"
)

feature_value() {
  local key="$1" kv
  for kv in "${FEATURE_DEFAULTS[@]}"; do
    [[ "${kv%%=*}" == "$key" ]] && { echo "${kv#*=}"; return 0; }
  done
  return 1
}

apply_feature_markers() {
  local cfg="$1"
  python3 - "$cfg" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
replacements = {
    'KDE': 'kde = true;',
    'STEAM': 'steam = false;',
    'VIRTUALISATION': 'virtualisation = false;',
    'FLATPAK': 'flatpak = true;',
    'NIXORCIST': 'nixorcist = false;',
    'COPILOT': 'copilot = false;',
    'GAMEON_STREAMING': 'streaming = false;'
}
for key, decl in replacements.items():
    start = f'# __TAKOS_FEATURE_{key}_START__'
    end = f'# __TAKOS_FEATURE_{key}_END__'
    pattern = re.compile(re.escape(start) + r'\n.*?\n\s*' + re.escape(end), re.S)
    repl = f'{start}\n    {decl}\n    {end}' if key not in ('GAMEON_STREAMING',) else f'{start}\n        {decl}\n        {end}'
    text, n = pattern.subn(repl, text, count=1)
    if n != 1:
        raise SystemExit(f'Missing or invalid marker block for {key}')
open(path, 'w').write(text)
PY
}

apply_feature_markers "${PROJECT_DIR}/configuration.nix"
VIRT_FEATURE="$(feature_value VIRTUALISATION)"

load_discovered_users() {
  DISCOVERED_USERS=()
  declare -gA DISC_DESC=() DISC_SHELL=() DISC_ADMIN=() DISC_NET=() DISC_VIRT=() DISC_AUDIO=() DISC_VIDEO=() DISC_INPUT=() DISC_PLUGDEV=()
  while IFS=$'\t' read -r name desc shell is_admin net virt audio video input plugdev; do
    [[ -n "${name:-}" ]] || continue
    DISCOVERED_USERS+=("$name")
    DISC_DESC["$name"]="$desc"
    DISC_SHELL["$name"]="$shell"
    DISC_ADMIN["$name"]="$is_admin"
    DISC_NET["$name"]="$net"
    DISC_VIRT["$name"]="$virt"
    DISC_AUDIO["$name"]="$audio"
    DISC_VIDEO["$name"]="$video"
    DISC_INPUT["$name"]="$input"
    DISC_PLUGDEV["$name"]="$plugdev"
  done < <("$DISCOVER_USERS_SCRIPT")
}

load_discovered_users

printf "\n${BOLD}${CYAN}"
cat << 'BANNER'
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗█████╗╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═══╝ ╚═════╝ ╚══════╝
      Installer v4 — declarative user discovery
           Declarative. Modular. Yours.
BANNER
printf "${RESET}\n  NixOS version  : %s\n\n" "$REPO_VERSION"

step "Phase 1: Channel upgrade"
nix-channel --add "https://nixos.org/channels/nixos-${REPO_VERSION}" nixos
nix-channel --add \
  "https://github.com/nix-community/home-manager/archive/release-${REPO_VERSION}.tar.gz" \
  home-manager
nix-channel --update
nixos-rebuild build 2>/dev/null && ok "Baseline build OK." \
  || warn "Baseline build failed — continuing (expected on fresh systems)."
ok "Phase 1 complete."

step "Phase 2: Install review (TUI)"
INSTALL_HOST="$(hostname -s 2>/dev/null || hostname)"
GPU_KERNEL="generic"; GPU_DRIVER="none"
EXTRA_ENABLE="false"

_lhost()  { echo "$INSTALL_HOST"; }
_lgpu()   { echo "${GPU_KERNEL}/${GPU_DRIVER}"; }
_lusers() { [[ ${#DISCOVERED_USERS[@]} -eq 0 ]] && echo "(none)" || echo "${DISCOVERED_USERS[*]}"; }
_lextra() { echo "$EXTRA_ENABLE"; }

scr_hostname() {
  local h; while true; do
    h="$(tui_input "Hostname" "System hostname:" "$INSTALL_HOST")"
    [[ "$h" =~ ^[a-zA-Z0-9._-]+$ ]] && { INSTALL_HOST="$h"; return; }
    tui_msg "Error" "Invalid hostname — letters, digits, dots, hyphens only."
  done
}

scr_gpu() {
  GPU_KERNEL="$(tui_radio "GPU — Kernel Profile" "Kernel parameter profile:" \
    "generic"  "Safe default — any hardware (recommended)" "$([[ $GPU_KERNEL == generic  ]] && echo ON || echo OFF)" \
    "thinkpad" "ThinkPad T480 — i915 GuC/HuC + Intel microcode" "$([[ $GPU_KERNEL == thinkpad ]] && echo ON || echo OFF)" \
    "amd"      "AMD — amd_iommu + ppfeaturemask + AMD microcode" "$([[ $GPU_KERNEL == amd     ]] && echo ON || echo OFF)" \
    "nvidia"   "Nvidia — DRM modesetting + nvidia initrd" "$([[ $GPU_KERNEL == nvidia  ]] && echo ON || echo OFF)")"
  GPU_DRIVER="$(tui_radio "GPU — Driver" "GPU driver to load:" \
    "none"         "No driver (VM / headless / Intel built-in)" "$([[ $GPU_DRIVER == none         ]] && echo ON || echo OFF)" \
    "intel"        "Intel integrated" "$([[ $GPU_DRIVER == intel        ]] && echo ON || echo OFF)" \
    "amd"          "AMD" "$([[ $GPU_DRIVER == amd          ]] && echo ON || echo OFF)" \
    "nvidia"       "Nvidia discrete" "$([[ $GPU_DRIVER == nvidia       ]] && echo ON || echo OFF)" \
    "nvidia-prime" "Nvidia + Intel PRIME hybrid" "$([[ $GPU_DRIVER == nvidia-prime ]] && echo ON || echo OFF)")"
}

scr_users() {
  load_discovered_users
  local preview="" u role
  for u in "${DISCOVERED_USERS[@]}"; do
    role="user"
    [[ "${DISC_ADMIN[$u]:-false}" == "true" ]] && role="admin"
    preview+="- ${u} (${DISC_DESC[$u]:-$u}) :: shell=${DISC_SHELL[$u]:-bash} role=${role} net=${DISC_NET[$u]:-false} virt=${DISC_VIRT[$u]:-false} audio=${DISC_AUDIO[$u]:-false} video=${DISC_VIDEO[$u]:-false} input=${DISC_INPUT[$u]:-false} plugdev=${DISC_PLUGDEV[$u]:-false}"$'\n'
  done
  tui_msg "Discovered Users" "Tak_OS now uses discovered existing users instead of manual user creation.\n\nCurrent discovered users:\n${preview}"
}

scr_extra() {
  if tui_yesno "Extra Users" \
"Enable extra-users.nix?
Creates ${USERS_DIR}/extra-users.nix — edit for full users.users.<name> control.
Current: $(_lextra)"; then
    EXTRA_ENABLE="true"
  else
    EXTRA_ENABLE="false"
  fi
}

scr_review() {
  local _users="${DISCOVERED_USERS[*]:-—}"
  tui_msg "Review" \
"Hostname       : ${INSTALL_HOST}

GPU            : kernelParams=${GPU_KERNEL}  driver=${GPU_DRIVER}
NixOS          : ${REPO_VERSION}
Virtualisation : ${VIRT_FEATURE}

Discovered users: ${_users}
Extra nix      : ${EXTRA_ENABLE}

Manual user creation has been removed from the installer.
Existing users will be exported into separate declarations and linked through the users hub."
}

_APPLIED="false"
while true; do
  _choice="$(tui_menu "Tak_OS Installer v4" \
    "Review detected system state. Select 'Apply' when ready." \
    "hostname" "Hostname         [$(_lhost)]"   \
    "gpu"      "GPU / Kernel     [$(_lgpu)]"    \
    "users"    "Detected Users   [$(_lusers)]"  \
    "extra"    "Extra users.nix  [$(_lextra)]"  \
    "review"   "Review summary"                 \
    "apply"    "Apply & Install"                \
    "quit"     "Quit / Abort")"
  case "$_choice" in
    hostname) scr_hostname ;;
    gpu)      scr_gpu ;;
    users)    scr_users ;;
    extra)    scr_extra ;;
    review)   scr_review ;;
    apply)
      [[ ${#DISCOVERED_USERS[@]} -eq 0 ]] && {
        tui_msg "Error" "No existing users were discovered. Create a real user first or fix discovery logic."; continue; }
      scr_review
      tui_yesno "Confirm" "Proceed with installation?" || continue
      _APPLIED="true"; break ;;
    quit) die "Aborted by user." ;;
  esac
done
[[ "$_APPLIED" != "true" ]] && die "Nothing applied."

step "Phase 3: Generating configuration"
mkdir -p "$USERS_DIR"

build_groups() {
  local is_admin="$1" net="$2" virt="$3" audio="$4" video="$5" input="$6" plugdev="$7"
  local -a g=()
  [[ "$is_admin" == "true" ]] && g+=("\"wheel\"")
  [[ "$net"      == "true" ]] && g+=("\"networkmanager\"")
  if [[ "$virt" == "true" ]]; then
    if [[ "$VIRT_FEATURE" == "true" ]]; then g+=("\"vboxusers\"" "\"docker\"")
    else warn "User wants virtualisation groups but features.virtualisation=false — skipping vboxusers/docker"; fi
  fi
  [[ "$audio"   == "true" ]] && g+=("\"audio\"")
  [[ "$video"   == "true" ]] && g+=("\"video\"")
  [[ "$input"   == "true" ]] && g+=("\"input\"")
  [[ "$plugdev" == "true" ]] && g+=("\"plugdev\"")
  printf '%s\n' "${g[@]}"
}

write_user_file() {
  local name="$1" desc="$2" shell="$3" is_admin="$4"
  local net="$5" virt="$6" audio="$7" video="$8" input="$9" plugdev="${10}"
  local -a grp_lines=()
  while IFS= read -r g; do [[ -n "$g" ]] && grp_lines+=("      $g"); done \
    < <(build_groups "$is_admin" "$net" "$virt" "$audio" "$video" "$input" "$plugdev")
  local gnix
  if [[ ${#grp_lines[@]} -eq 0 ]]; then gnix="[]"
  else gnix=$'[\n'; for g in "${grp_lines[@]}"; do gnix+="$g"$'\n'; done; gnix+="    ]"; fi
  cat > "${USERS_DIR}/${name}.nix" << NIX
# ===========================================================
#  Tak_OS — system user: ${name}
#  Generated by the Tak_OS installer. Safe to edit.
# ===========================================================
{ pkgs, lib, ... }:
{
  users.users.${name} = {
    isNormalUser = true;
    description  = "${desc}";
    shell        = pkgs.${shell};
    extraGroups  = ${gnix};
    packages = [
      # pkgs.kate
    ];
  };
}
NIX
  info "Wrote ${USERS_DIR}/${name}.nix"
}

for u in "${DISCOVERED_USERS[@]}"; do
  write_user_file "$u" \
    "${DISC_DESC[$u]:-$u}" \
    "${DISC_SHELL[$u]:-bash}" \
    "${DISC_ADMIN[$u]:-false}" \
    "${DISC_NET[$u]:-true}" \
    "${DISC_VIRT[$u]:-false}" \
    "${DISC_AUDIO[$u]:-false}" \
    "${DISC_VIDEO[$u]:-false}" \
    "${DISC_INPUT[$u]:-false}" \
    "${DISC_PLUGDEV[$u]:-false}"
done

if [[ "$EXTRA_ENABLE" == "true" ]]; then
  _extra="${USERS_DIR}/extra-users.nix"
  [[ ! -f "$_extra" ]] || [[ ! -s "$_extra" ]] && cat > "$_extra" << 'NIX'
# ===========================================================
#  Tak_OS — extra (fully manual) user declarations
# ===========================================================
{ pkgs, lib, ... }:
{
  # users.users.guest = { ... };
}
NIX
  info "Extra-users.nix ready at ${USERS_DIR}/extra-users.nix"
fi

{
  printf '# Generated by Tak_OS installer\n[ '
  for u in "${DISCOVERED_USERS[@]}"; do printf '"%s" ' "$u"; done
  printf ']\n'
} > "${USERS_DIR}/user-list.nix"
info "Wrote ${USERS_DIR}/user-list.nix"

cat > "${USERS_DIR}/default.nix" << 'NIX'
# Generated by Tak_OS installer — users hub
{ ... }:
{
  imports = [
    ./user-modules.nix
  ];
}
NIX

{
  printf '# Generated by Tak_OS installer — aggregated imports\n{ ... }:\n{\n  imports = [\n'
  for u in "${DISCOVERED_USERS[@]}"; do printf '    ./%s.nix\n' "$u"; done
  [[ "$EXTRA_ENABLE" == "true" ]] && printf '    ./extra-users.nix\n'
  printf '  ];\n}\n'
} > "${USERS_DIR}/user-modules.nix"
info "Wrote ${USERS_DIR}/default.nix and ${USERS_DIR}/user-modules.nix"

python3 - "${PROJECT_DIR}/configuration.nix" << 'PYEOF'
import sys
cfg = sys.argv[1]
start = '# __NIXOS_USERS_IMPORTS_START__'
end = '# __NIXOS_USERS_IMPORTS_END__'
content = open(cfg).read()
si = content.find(start); ei = content.find(end)
if si == -1 or ei == -1 or si >= ei:
    raise SystemExit('ERROR: user import markers not found or invalid')
ls = content.rfind('\n', 0, si) + 1
le = content.find('\n', ei); le = len(content) if le == -1 else le + 1
block = '     ' + start + '\n' + '     ./users-declared/default.nix\n' + '     ' + end + '\n'
open(cfg, 'w').write(content[:ls] + block + content[le:])
PYEOF

apply_feature_markers "${PROJECT_DIR}/configuration.nix"
sed -i "s/networking\.hostName = \"[^\"]*\"/networking.hostName = \"${INSTALL_HOST}\"/" \
  "${PROJECT_DIR}/modules/networking.nix"
sed -i "s/kernelParams\s*=\s*\"[^\"]*\"/kernelParams = \"${GPU_KERNEL}\"/" \
  "${PROJECT_DIR}/configuration.nix"
sed -i "s/^\(\s*gpu\s*=\s*\)\"[^\"]*\"/\1\"${GPU_DRIVER}\"/" \
  "${PROJECT_DIR}/configuration.nix"
VIRT_FEATURE="$(feature_value VIRTUALISATION)"
info "Hostname=${INSTALL_HOST}  GPU=${GPU_KERNEL}/${GPU_DRIVER}"
info "Feature defaults applied via marker blocks (heavy modules disabled by default)."
ok "Configuration generated."

step "Phase 4: Deploying to ${TARGET_DIR}"
_tmpdir="$(mktemp -d)"; trap 'rm -rf "$_tmpdir"' EXIT
[[ -f "${TARGET_DIR}/hardware-configuration.nix" ]] && cp "${TARGET_DIR}/hardware-configuration.nix" "$_tmpdir/"
rsync -a --delete "${PROJECT_DIR}/" "${TARGET_DIR}/"
[[ -f "$_tmpdir/hardware-configuration.nix" ]] && cp "$_tmpdir/hardware-configuration.nix" "${TARGET_DIR}/"
mkdir -p "${TARGET_DIR}/users-declared"
cp "${USERS_DIR}"/*.nix "${TARGET_DIR}/users-declared/" 2>/dev/null || true
ok "Deployment complete."

step "Phase 5: Adaptive build"
auto_fix() {
  local attempt=1 max=25
  while (( attempt <= max )); do
    info "Build attempt $attempt / $max …"
    local LOG="${TARGET_DIR}/build-attempt-${attempt}.log"
    set +e; nixos-rebuild build 2>&1 | tee "$LOG"; local rc=${PIPESTATUS[0]}; set -e
    [[ $rc -eq 0 ]] && { ok "Build succeeded on attempt $attempt."; return 0; }
    local var; var="$(grep -oP "undefined variable ['\`]\K[^'\`]+" "$LOG" | head -1 || true)"
    if [[ -z "$var" ]]; then
      warn "Unhandled error. Check $LOG."
      [[ "$FALLBACK_MODE" == "true" ]] && {
        local fa="${DISCOVERED_USERS[0]:-tak_1}"
        warn "Fallback: sed-replacing 'tak_1' → '$fa'..."
        grep -rl "tak_1" "${TARGET_DIR}/configuration.nix" "${TARGET_DIR}/modules/" --include="*.nix" 2>/dev/null \
          | while read -r f; do sed -i "s/\btak_1\b/${fa}/g" "$f"; warn "  patched: $f"; done
        nixos-rebuild build 2>&1 | tail -3; return 0
      }
      return 1
    fi
    warn "Auto-commenting: '$var'"
    local matches; matches="$(grep -R --include="*.nix" -n "\b${var}\b" "${SCAN_PATHS[@]}" || true)"
    [[ -z "$matches" ]] && { warn "Cannot locate '$var'."; return 1; }
    while IFS= read -r m; do
      local f l; f="$(cut -d: -f1 <<< "$m")"; l="$(cut -d: -f2 <<< "$m")"
      [[ -f "$f" ]] && ! sed -n "${l}p" "$f" | grep -q "AUTO-COMMENTED" && \
        { sed -i "${l}s/^/# AUTO-COMMENTED (${var}): /" "$f"; echo "${f}:${l}:${var}" >> "$COMMENT_LOG"; }
    done <<< "$matches"
    ok "Disabled '$var'. Retrying…"; ((attempt++))
  done; return 1
}
auto_fix || die "Build failed. Check logs in ${TARGET_DIR}/."

step "Phase 6: Switch"
info "Switching to Tak_OS…"
nixos-rebuild switch
ok "Switch complete."

step "Phase 7: Restore auto-commented packages (optional)"
RESTORE="${TARGET_DIR}/scripts/restore-commented.sh"
cat > "$RESTORE" << 'RS'
#!/usr/bin/env bash
set -euo pipefail
LOG="/etc/nixos/.auto-commented-packages.log"
[[ ! -f "$LOG" ]] && { echo "Nothing to restore."; exit 0; }
while IFS=: read -r file line var; do
  [[ -f "$file" ]] && sed -i "${line}s/^# AUTO-COMMENTED (${var}): //" "$file"
done < "$LOG"; rm -f "$LOG"; echo "Restored. Run: nixos-rebuild switch"
RS
chmod +x "$RESTORE"
[[ -s "$COMMENT_LOG" ]] && {
  tui_yesno "Restore" "Restore auto-commented packages and rebuild?" \
    && { "$RESTORE"; info "Rebuilding…"; nixos-rebuild switch; } || true; }

printf "\n${GREEN}${BOLD}  Tak_OS installation complete.${RESET}\n\n"
printf "  Per-user files : ${USERS_DIR}/<name>.nix\n"
printf "  Users hub      : ${USERS_DIR}/default.nix\n"
printf "  Home Manager   : ~/.hm-local/home.nix  (per user)\n"
printf "  GPU            : kernelParams=%s  driver=%s\n" "$GPU_KERNEL" "$GPU_DRIVER"
[[ -s "$COMMENT_LOG" ]] && printf "  Restore pkgs   : sudo %s\n" "$RESTORE"
printf "\n"
