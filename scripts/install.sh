#!/usr/bin/env bash
# Tak_OS · install.sh v3 — nmtui-style installer with per-user .nix generation
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Phases:
#   1  Channel upgrade
#   2  TUI user setup — navigable menu (hostname · GPU · users · extra)
#   3  Generate per-user .nix files + user-list.nix + patch imports + hostname + GPU
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
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --msgbox "$msg" 14 72
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
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --yesno "$prompt" 9 65; return $?
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
      local _first="${_r:0:1}" _t
      for _t in "${tags[@]}"; do
        [[ "${_t:0:1}" == "${_first,,}" ]] && { echo "$_t"; return; }; done
      printf "  No match — number 1-%d or first letter.\n" "$(( i-1 ))" >&2
    done; fi
}
tui_menu() {
  local title="$1" prompt="$2"; shift 2
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --menu "$prompt" 20 72 12 "$@"
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
      local _first="${_r:0:1}" _t
      for _t in "${tags[@]}"; do
        [[ "${_t:0:1}" == "${_first,,}" ]] && { echo "$_t"; return; }; done
      printf "  Invalid — number 1-%d or first letter.\n" "$(( i-1 ))" >&2
    done; fi
}
tui_check() {
  local title="$1" prompt="$2"; shift 2
  if [[ "$TUI" != "plain" ]]; then _tui --title "$title" --checklist "$prompt" 20 72 10 "$@"
  else
    local -a sel=() args=("$@")
    printf "\n=== %s ===\n%s\n" "$title" "$prompt" >&2
    while [[ ${#args[@]} -gt 0 ]]; do
      local tag="${args[0]}" desc="${args[1]}" on="${args[2]}"; args=("${args[@]:3}")
      if [[ "$on" == "ON" ]]; then
        read -rp "  Enable $tag ($desc)? [Y/n]: " _r < /dev/tty
        [[ "${_r,,}" != "n" ]] && sel+=("\"$tag\"")
      else
        read -rp "  Enable $tag ($desc)? [y/N]: " _r < /dev/tty
        [[ "${_r,,}" == "y" ]] && sel+=("\"$tag\"")
      fi
    done
    [[ ${#sel[@]} -gt 0 ]] && printf '%s ' "${sel[@]}" || true; fi
}

REPO_VERSION="$(grep -oP 'stateVersion\s*=\s*"\K[^"]+' "${PROJECT_DIR}/configuration.nix" | head -1)"
VIRT_FEATURE="false"
grep -qP 'virtualisation\s*=\s*true' "${PROJECT_DIR}/configuration.nix" && VIRT_FEATURE="true" || true

printf "\n${BOLD}${CYAN}"
cat << 'BANNER'
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗█████╗╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═══╝ ╚═════╝ ╚══════╝
           Installer v3 — nmtui-style setup
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

step "Phase 2: User setup (TUI)"

INSTALL_HOST="$(hostname -s 2>/dev/null || hostname)"
GPU_KERNEL="generic"; GPU_DRIVER="none"
declare -a  ADMIN_USERS=(); declare -A  ADMIN_DESC=(); declare -A  ADMIN_SHELL_OVR=()
ADMIN_SHELL="zsh"
ADMIN_NET="true"; ADMIN_VIRT="true"; ADMIN_AUDIO="false"
ADMIN_VIDEO="false"; ADMIN_INPUT="false"; ADMIN_PLUGDEV="false"
declare -a  NORMAL_USERS=(); declare -A  NORMAL_DESC=(); declare -A  NORMAL_SHELL_OVR=()
NORMAL_ENABLE="false"; NORMAL_SHELL="bash"
NORMAL_NET="true"; NORMAL_VIRT="false"; NORMAL_AUDIO="false"
NORMAL_VIDEO="false"; NORMAL_INPUT="false"; NORMAL_PLUGDEV="false"
EXTRA_ENABLE="false"

_lhost()  { echo "$INSTALL_HOST"; }
_lgpu()   { echo "${GPU_KERNEL}/${GPU_DRIVER}"; }
_ladm()   { [[ ${#ADMIN_USERS[@]} -eq 0 ]] && echo "(none)" || echo "${ADMIN_USERS[*]}"; }
_lnorm()  { [[ "$NORMAL_ENABLE" == "false" ]] && echo "disabled" \
              || { [[ ${#NORMAL_USERS[@]} -eq 0 ]] && echo "enabled/(none)" \
                   || echo "${NORMAL_USERS[*]}"; }; }
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
    "generic"  "Safe default — any hardware (recommended)" \
      "$([[ $GPU_KERNEL == generic  ]] && echo ON || echo OFF)" \
    "thinkpad" "ThinkPad T480 — i915 GuC/HuC + Intel microcode" \
      "$([[ $GPU_KERNEL == thinkpad ]] && echo ON || echo OFF)" \
    "amd"      "AMD — amd_iommu + ppfeaturemask + AMD microcode" \
      "$([[ $GPU_KERNEL == amd     ]] && echo ON || echo OFF)" \
    "nvidia"   "Nvidia — DRM modesetting + nvidia initrd" \
      "$([[ $GPU_KERNEL == nvidia  ]] && echo ON || echo OFF)")"
  GPU_DRIVER="$(tui_radio "GPU — Driver" "GPU driver to load:" \
    "none"         "No driver (VM / headless / Intel built-in)" \
      "$([[ $GPU_DRIVER == none         ]] && echo ON || echo OFF)" \
    "intel"        "Intel integrated (intel-media-driver + VA-API)" \
      "$([[ $GPU_DRIVER == intel        ]] && echo ON || echo OFF)" \
    "amd"          "AMD (amdgpu + VA-API)" \
      "$([[ $GPU_DRIVER == amd          ]] && echo ON || echo OFF)" \
    "nvidia"       "Nvidia discrete" \
      "$([[ $GPU_DRIVER == nvidia       ]] && echo ON || echo OFF)" \
    "nvidia-prime" "Nvidia + Intel PRIME hybrid" \
      "$([[ $GPU_DRIVER == nvidia-prime ]] && echo ON || echo OFF)")"
}

scr_admins() {
  tui_msg "Admin Users" "Admin users get 'wheel' + shared group toggles.
At least one required.  Current: $(_ladm)"
  if tui_yesno "Admin Users" "Clear current list and start fresh?"; then
    ADMIN_USERS=(); ADMIN_DESC=(); ADMIN_SHELL_OVR=()
  fi
  while true; do
    local _n; while true; do
      _n="$(tui_input "Add Admin" "Username (a-z, 0-9, _, -):" "")"
      [[ "$_n" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
      tui_msg "Error" "Invalid username '$_n'."
    done
    local _d; _d="$(tui_input "Add Admin" "Description for '$_n':" "$_n")"
    ADMIN_USERS+=("$_n"); ADMIN_DESC["$_n"]="$_d"
    tui_yesno "Admin Users" "Add another admin?" || break
  done
  ADMIN_SHELL="$(tui_radio "Admin Shell" "Default shell for all admins:" \
    "zsh"  "Z Shell (recommended)" "$([[ $ADMIN_SHELL == zsh  ]] && echo ON || echo OFF)" \
    "bash" "Bash"                  "$([[ $ADMIN_SHELL == bash ]] && echo ON || echo OFF)" \
    "fish" "Fish Shell"            "$([[ $ADMIN_SHELL == fish ]] && echo ON || echo OFF)")"
  if (( ${#ADMIN_USERS[@]} > 1 )); then
    for _u in "${ADMIN_USERS[@]}"; do
      local _s; _s="$(tui_radio "Shell: $_u" "Shell for '$_u' (tier: $ADMIN_SHELL):" \
        "zsh"  "Z Shell" "$([[ $ADMIN_SHELL == zsh  ]] && echo ON || echo OFF)" \
        "bash" "Bash"    "$([[ $ADMIN_SHELL == bash ]] && echo ON || echo OFF)" \
        "fish" "Fish"    "$([[ $ADMIN_SHELL == fish ]] && echo ON || echo OFF)")"
      [[ "$_s" != "$ADMIN_SHELL" ]] && ADMIN_SHELL_OVR["$_u"]="$_s" \
        || unset 'ADMIN_SHELL_OVR[$_u]'
    done
  fi
  local _ag; _ag="$(tui_check "Admin Groups" "Groups for all admins:" \
    "networking"     "networkmanager (WiFi/VPN)" \
      "$([[ $ADMIN_NET    == true ]] && echo ON || echo OFF)" \
    "virtualisation" "vboxusers + docker" \
      "$([[ $ADMIN_VIRT   == true ]] && echo ON || echo OFF)" \
    "audio"   "audio"   "$([[ $ADMIN_AUDIO   == true ]] && echo ON || echo OFF)" \
    "video"   "video"   "$([[ $ADMIN_VIDEO   == true ]] && echo ON || echo OFF)" \
    "input"   "input"   "$([[ $ADMIN_INPUT   == true ]] && echo ON || echo OFF)" \
    "plugdev" "plugdev (USB)" "$([[ $ADMIN_PLUGDEV == true ]] && echo ON || echo OFF)")"
  ADMIN_NET="false"; ADMIN_VIRT="false"; ADMIN_AUDIO="false"
  ADMIN_VIDEO="false"; ADMIN_INPUT="false"; ADMIN_PLUGDEV="false"
  [[ "$_ag" == *'"networking"'*     ]] && ADMIN_NET="true"
  [[ "$_ag" == *'"virtualisation"'* ]] && ADMIN_VIRT="true"
  [[ "$_ag" == *'"audio"'*          ]] && ADMIN_AUDIO="true"
  [[ "$_ag" == *'"video"'*          ]] && ADMIN_VIDEO="true"
  [[ "$_ag" == *'"input"'*          ]] && ADMIN_INPUT="true"
  [[ "$_ag" == *'"plugdev"'*        ]] && ADMIN_PLUGDEV="true"
}

scr_normal() {
  if tui_yesno "Normal Users" \
    "Enable normal-user tier (no wheel)?  Current: $(_lnorm)"; then
    NORMAL_ENABLE="true"
    if tui_yesno "Normal Users" "Clear current list and start fresh?"; then
      NORMAL_USERS=(); NORMAL_DESC=(); NORMAL_SHELL_OVR=()
    fi
    while true; do
      local _n; while true; do
        _n="$(tui_input "Add Normal User" "Username (a-z, 0-9, _, -):" "")"
        [[ "$_n" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
        tui_msg "Error" "Invalid username '$_n'."
      done
      local _d; _d="$(tui_input "Add Normal User" "Description for '$_n':" "$_n")"
      NORMAL_USERS+=("$_n"); NORMAL_DESC["$_n"]="$_d"
      tui_yesno "Normal Users" "Add another?" || break
    done
    NORMAL_SHELL="$(tui_radio "Normal Shell" "Default shell for all normal users:" \
      "bash" "Bash (recommended)" "$([[ $NORMAL_SHELL == bash ]] && echo ON || echo OFF)" \
      "zsh"  "Z Shell"            "$([[ $NORMAL_SHELL == zsh  ]] && echo ON || echo OFF)" \
      "fish" "Fish"               "$([[ $NORMAL_SHELL == fish ]] && echo ON || echo OFF)")"
    if (( ${#NORMAL_USERS[@]} > 1 )); then
      for _u in "${NORMAL_USERS[@]}"; do
        local _s; _s="$(tui_radio "Shell: $_u" "Shell for '$_u' (tier: $NORMAL_SHELL):" \
          "bash" "Bash" "$([[ $NORMAL_SHELL == bash ]] && echo ON || echo OFF)" \
          "zsh"  "Z Shell" "$([[ $NORMAL_SHELL == zsh ]] && echo ON || echo OFF)" \
          "fish" "Fish"    "$([[ $NORMAL_SHELL == fish ]] && echo ON || echo OFF)")"
        [[ "$_s" != "$NORMAL_SHELL" ]] && NORMAL_SHELL_OVR["$_u"]="$_s" \
          || unset 'NORMAL_SHELL_OVR[$_u]'
      done
    fi
    local _ng; _ng="$(tui_check "Normal Groups" "Groups for all normal users:" \
      "networking"     "networkmanager" "$([[ $NORMAL_NET    == true ]] && echo ON || echo OFF)" \
      "virtualisation" "vboxusers+docker" "$([[ $NORMAL_VIRT  == true ]] && echo ON || echo OFF)" \
      "audio"   "audio"   "$([[ $NORMAL_AUDIO   == true ]] && echo ON || echo OFF)" \
      "video"   "video"   "$([[ $NORMAL_VIDEO   == true ]] && echo ON || echo OFF)" \
      "input"   "input"   "$([[ $NORMAL_INPUT   == true ]] && echo ON || echo OFF)" \
      "plugdev" "plugdev" "$([[ $NORMAL_PLUGDEV == true ]] && echo ON || echo OFF)")"
    NORMAL_NET="false"; NORMAL_VIRT="false"; NORMAL_AUDIO="false"
    NORMAL_VIDEO="false"; NORMAL_INPUT="false"; NORMAL_PLUGDEV="false"
    [[ "$_ng" == *'"networking"'*     ]] && NORMAL_NET="true"
    [[ "$_ng" == *'"virtualisation"'* ]] && NORMAL_VIRT="true"
    [[ "$_ng" == *'"audio"'*          ]] && NORMAL_AUDIO="true"
    [[ "$_ng" == *'"video"'*          ]] && NORMAL_VIDEO="true"
    [[ "$_ng" == *'"input"'*          ]] && NORMAL_INPUT="true"
    [[ "$_ng" == *'"plugdev"'*        ]] && NORMAL_PLUGDEV="true"
  else
    NORMAL_ENABLE="false"; NORMAL_USERS=()
  fi
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
  local _adm="${ADMIN_USERS[*]:-—}"
  local _nor; [[ "$NORMAL_ENABLE" == "false" ]] && _nor="disabled" \
    || _nor="${NORMAL_USERS[*]:-—}"
  tui_msg "Review" \
"Hostname     : ${INSTALL_HOST}
GPU          : kernelParams=${GPU_KERNEL}  driver=${GPU_DRIVER}
NixOS        : ${REPO_VERSION}

Admin users  : ${_adm}
Admin shell  : ${ADMIN_SHELL}
Admin groups : net=${ADMIN_NET} virt=${ADMIN_VIRT} audio=${ADMIN_AUDIO} video=${ADMIN_VIDEO} input=${ADMIN_INPUT} plugdev=${ADMIN_PLUGDEV}

Normal users : ${_nor}
Normal shell : ${NORMAL_SHELL}
Normal groups: net=${NORMAL_NET} virt=${NORMAL_VIRT} audio=${NORMAL_AUDIO} video=${NORMAL_VIDEO} input=${NORMAL_INPUT} plugdev=${NORMAL_PLUGDEV}

Extra nix    : ${EXTRA_ENABLE}"
}

_APPLIED="false"
while true; do
  _choice="$(tui_menu "Tak_OS Installer v3" \
    "Navigate freely. Select 'Apply' when ready." \
    "hostname" "Hostname        [$(_lhost)]"   \
    "gpu"      "GPU / Kernel    [$(_lgpu)]"    \
    "admins"   "Admin Users     [$(_ladm)]"    \
    "normal"   "Normal Users    [$(_lnorm)]"   \
    "extra"    "Extra users.nix [$(_lextra)]"  \
    "review"   "Review summary"                 \
    "apply"    "Apply & Install"                \
    "quit"     "Quit / Abort")"
  case "$_choice" in
    hostname) scr_hostname ;;
    gpu)      scr_gpu ;;
    admins)   scr_admins ;;
    normal)   scr_normal ;;
    extra)    scr_extra ;;
    review)   scr_review ;;
    apply)
      [[ ${#ADMIN_USERS[@]} -eq 0 ]] && {
        tui_msg "Error" "Configure at least one admin user first."; continue; }
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
    else warn "virtualisation=true but features.virtualisation=false — skipping vboxusers/docker"; fi
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
#  Re-run: sudo /etc/nixos/scripts/install.sh  to regenerate.
#  Then:   sudo nixos-rebuild switch
#
#  Add per-user packages to the packages list below.
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

for u in "${ADMIN_USERS[@]}"; do
  _sh="${ADMIN_SHELL_OVR[$u]:-$ADMIN_SHELL}"
  write_user_file "$u" "${ADMIN_DESC[$u]:-$u}" "$_sh" "true" \
    "$ADMIN_NET" "$ADMIN_VIRT" "$ADMIN_AUDIO" "$ADMIN_VIDEO" "$ADMIN_INPUT" "$ADMIN_PLUGDEV"
done

if [[ "$NORMAL_ENABLE" == "true" ]]; then
  for u in "${NORMAL_USERS[@]}"; do
    _sh="${NORMAL_SHELL_OVR[$u]:-$NORMAL_SHELL}"
    write_user_file "$u" "${NORMAL_DESC[$u]:-$u}" "$_sh" "false" \
      "$NORMAL_NET" "$NORMAL_VIRT" "$NORMAL_AUDIO" "$NORMAL_VIDEO" "$NORMAL_INPUT" "$NORMAL_PLUGDEV"
  done
fi

if [[ "$EXTRA_ENABLE" == "true" ]]; then
  _extra="${USERS_DIR}/extra-users.nix"
  [[ ! -f "$_extra" ]] || [[ ! -s "$_extra" ]] && cat > "$_extra" << 'NIX'
# ===========================================================
#  Tak_OS — extra (fully manual) user declarations
#  Auto-created — safe to edit. Loaded when present in imports.
#
#  Example:
#    users.users.guest = {
#      isNormalUser = true; description = "Guest";
#      shell = pkgs.bash; extraGroups = []; packages = [];
#    };
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
  for u in "${ADMIN_USERS[@]}"; do printf '"%s" ' "$u"; done
  [[ "$NORMAL_ENABLE" == "true" ]] && \
    for u in "${NORMAL_USERS[@]}"; do printf '"%s" ' "$u"; done
  printf ']\n'
} > "${USERS_DIR}/user-list.nix"
info "Wrote ${USERS_DIR}/user-list.nix"

_import_lines=""
for u in "${ADMIN_USERS[@]}"; do _import_lines+="     ./users-declared/${u}.nix"$'\n'; done
[[ "$NORMAL_ENABLE" == "true" ]] && \
  for u in "${NORMAL_USERS[@]}"; do _import_lines+="     ./users-declared/${u}.nix"$'\n'; done
[[ "$EXTRA_ENABLE"  == "true" ]] && \
  _import_lines+="     ./users-declared/extra-users.nix"$'\n'

python3 - "${PROJECT_DIR}/configuration.nix" "$_import_lines" << 'PYEOF'
import sys
START = '# __NIXOS_USERS_IMPORTS_START__'
END   = '# __NIXOS_USERS_IMPORTS_END__'
cfg   = sys.argv[1]
lines = sys.argv[2]
content = open(cfg).read()
si = content.find(START); ei = content.find(END)
if si == -1: sys.exit(f'ERROR: {START!r} not found')
if ei == -1: sys.exit(f'ERROR: {END!r} not found')
if si >= ei: sys.exit('ERROR: START after END')
ls = content.rfind('\n', 0, si) + 1
le = content.find('\n', ei); le = len(content) if le == -1 else le + 1
nb = f'     {START}\n{lines}     {END}\n'
open(cfg, 'w').write(content[:ls] + nb + content[le:])
print(f'  Imports block patched ({le-ls} -> {len(nb)} chars)')
PYEOF

sed -i "s/networking\.hostName = \"[^\"]*\"/networking.hostName = \"${INSTALL_HOST}\"/" \
  "${PROJECT_DIR}/modules/networking.nix"
sed -i "s/kernelParams\s*=\s*\"[^\"]*\"/kernelParams = \"${GPU_KERNEL}\"/" \
  "${PROJECT_DIR}/configuration.nix"
sed -i "s/^\(\s*gpu\s*=\s*\)\"[^\"]*\"/\1\"${GPU_DRIVER}\"/" \
  "${PROJECT_DIR}/configuration.nix"
info "Hostname=${INSTALL_HOST}  GPU=${GPU_KERNEL}/${GPU_DRIVER}"
ok "Configuration generated."

step "Phase 4: Deploying to ${TARGET_DIR}"
_tmpdir="$(mktemp -d)"; trap 'rm -rf "$_tmpdir"' EXIT
[[ -f "${TARGET_DIR}/hardware-configuration.nix" ]] && \
  cp "${TARGET_DIR}/hardware-configuration.nix" "$_tmpdir/"
rsync -a --delete "${PROJECT_DIR}/" "${TARGET_DIR}/"
[[ -f "$_tmpdir/hardware-configuration.nix" ]] && \
  cp "$_tmpdir/hardware-configuration.nix" "${TARGET_DIR}/"
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
        local fa="${ADMIN_USERS[0]:-tak_1}"
        warn "Fallback: sed-replacing 'tak_1' → '$fa'..."
        grep -rl "tak_1" "${TARGET_DIR}/configuration.nix" "${TARGET_DIR}/modules/" \
          --include="*.nix" 2>/dev/null \
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
printf "  Home Manager   : ~/.hm-local/home.nix  (per user)\n"
printf "  GPU            : kernelParams=%s  driver=%s\n" "$GPU_KERNEL" "$GPU_DRIVER"
[[ -s "$COMMENT_LOG" ]] && printf "  Restore pkgs   : sudo %s\n" "$RESTORE"
printf "\n"
