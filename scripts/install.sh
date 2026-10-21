#!/usr/bin/env bash
# Tak_OS · install.sh v5 — automatic installer with optional interactive edit
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Default (automatic, no prompts): detects hardware (CPU, GPU, VM guest),
# virtualisation support and existing users, then stages and installs.
# GPU/kernel values are written as "auto", so the build resolves them through
# modules/hardware-detect.nix from the detection made on this machine.
#
# --edit   Review the detected values in the TUI first and change any of them.
# --dry-run Stage the configuration and stop before deploy/build/switch.
#           Needs no root; the staged copy is kept and its path is printed.
#
# Phases:
#   1  Channel upgrade                          (skipped in --dry-run)
#   2  Detection (auto) or review TUI (--edit)
#   3  Stage repo copy + remap users + detected hardware + features
#   4  Deploy staged copy → /etc/nixos         (skipped in --dry-run)
#   5  Adaptive build                           (skipped in --dry-run)
#   6  Switch                                   (skipped in --dry-run)
#   7  Restore auto-commented packages          (--edit asks; auto prints a hint)
#
# Usage:
#   sudo bash /path/to/Tak_OS/scripts/install.sh            # automatic
#   sudo bash /path/to/Tak_OS/scripts/install.sh --edit     # review first
#        bash /path/to/Tak_OS/scripts/install.sh --dry-run  # stage only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="/etc/nixos"
TARGET_USERS_DIR="${TARGET_DIR}/users-declared"
USERS_DIR="${PROJECT_DIR}/users-declared"
DISCOVER_USERS_SCRIPT="${PROJECT_DIR}/scripts/discover-users.sh"
DETECT_HARDWARE_SCRIPT="${PROJECT_DIR}/scripts/detect-hardware.sh"
STAGE_DIR=""
TEMP_ROOT=""

SCAN_PATHS=("$TARGET_DIR/configuration.nix" "$TARGET_DIR/modules" "$TARGET_DIR/packages")
COMMENT_LOG="$TARGET_DIR/.auto-commented-packages.log"
touch "$COMMENT_LOG" 2>/dev/null || true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()  { printf "${CYAN}[*]${RESET} %s\n"  "$*"; }
ok()    { printf "${GREEN}[✓]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
die()   { printf "${RED}[✗]${RESET} %s\n"   "$*" >&2; exit 1; }
step()  { printf "\n${BOLD}${CYAN}──── %s ────${RESET}\n" "$*"; }
cleanup() {
  # A dry run keeps the staged copy so it can be inspected.
  [[ "${DRY_RUN}" == "true" ]] && return 0
  [[ -n "${TEMP_ROOT:-}" && -d "${TEMP_ROOT}" ]] && rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

# ── Arguments ────────────────────────────────────────────────────────────────
MODE="auto"
DRY_RUN="false"
for arg in "$@"; do
  case "$arg" in
    --edit)     MODE="edit" ;;
    --auto)     MODE="auto" ;;
    --dry-run)  DRY_RUN="true" ;;
    -h|--help)  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "Unknown option: $arg (see --help)" ;;
  esac
done

if [[ "$DRY_RUN" != "true" && "${EUID}" -ne 0 ]]; then
  die "Run as root: sudo $0  (or add --dry-run to stage without deploying)"
fi

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
[[ -x "$DETECT_HARDWARE_SCRIPT" ]] || chmod +x "$DETECT_HARDWARE_SCRIPT" 2>/dev/null || true

# ── Feature flags ────────────────────────────────────────────────────────────
# Keys are the marker names in configuration.nix (# __TAKOS_FEATURE_<KEY>_START__);
# each key is also the lowercase attribute name under `features`.
FEATURE_ORDER=(KDE STEAM VIRTUALISATION FLATPAK NIXORCIST COPILOT)
declare -A FEATURES=(
  [KDE]=true
  [STEAM]=false
  [VIRTUALISATION]=false     # auto mode replaces this with hardware support
  [FLATPAK]=true
  [NIXORCIST]=false
  [COPILOT]=false
)

# Writes `features.<name> = <value>;` into each marker block.
apply_feature_markers() {
  local cfg="$1"; shift
  python3 - "$cfg" "$@" <<'PY'
import re
import sys

path, pairs = sys.argv[1], sys.argv[2:]
text = open(path, encoding="utf-8").read()
for pair in pairs:
    key, value = pair.split("=", 1)
    start = f"# __TAKOS_FEATURE_{key}_START__"
    end = f"# __TAKOS_FEATURE_{key}_END__"
    pattern = re.compile(re.escape(start) + r"\n.*?\n\s*" + re.escape(end), re.S)
    replacement = f"{start}\n    {key.lower()} = {value};\n    {end}"
    text, n = pattern.subn(lambda _m: replacement, text, count=1)
    if n != 1:
        raise SystemExit(f"Missing or invalid marker block for {key}")
open(path, "w", encoding="utf-8").write(text)
PY
}

# ── Hardware detection ───────────────────────────────────────────────────────
# Reads one `key = "value";` line from a generated hardware-detected.nix.
detected_value() {
  sed -n "s/^  $2 = \"\(.*\)\";/\1/p" "$1" | head -1
}

# Runs scripts/detect-hardware.sh into $1 and loads the DET_* variables.
run_detection() {
  local out="$1"
  "$DETECT_HARDWARE_SCRIPT" "$out" >/dev/null || die "Hardware detection failed."
  DET_CPU="$(detected_value "$out" cpu)"
  DET_GUEST="$(detected_value "$out" guest)"
  DET_KERNEL="$(detected_value "$out" kernelParams)"
  DET_DRIVER="$(detected_value "$out" driver)"
  DET_GPUS="$(sed -n 's/^  gpus = \[ \(.*\) \];/\1/p' "$out" | tr -d '"')"
  DET_VIRT_CAPABLE="false"
  if grep -q '^  kernelModules = \[ "kvm-' "$out"; then DET_VIRT_CAPABLE="true"; fi
}

describe_detection() {
  info "CPU        : ${DET_CPU}"
  info "GPU        : ${DET_GPUS:-none}"
  info "VM guest   : ${DET_GUEST}"
  info "Profile    : kernelParams=${DET_KERNEL}  driver=${DET_DRIVER}"
  info "Virt host  : ${DET_VIRT_CAPABLE} (CPU virtualisation extensions on bare metal)"
}

# ── Users ────────────────────────────────────────────────────────────────────
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

load_repo_users() {
  local base_dir="${1:-$PROJECT_DIR}"
  local repo_users_dir="${base_dir}/users-declared"
  local list_file="${repo_users_dir}/user-list.nix"
  REPO_USERS=()

  if [[ -f "$list_file" ]]; then
    mapfile -t REPO_USERS < <(python3 - "$list_file" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for name in re.findall(r'"([^"]+)"', text):
    print(name)
PY
)
  fi

  if [[ ${#REPO_USERS[@]} -eq 0 && -d "$repo_users_dir" ]]; then
    mapfile -t REPO_USERS < <(
      find "$repo_users_dir" -maxdepth 1 -type f -name '*.nix' \
        ! -name 'default.nix' ! -name 'user-modules.nix' ! -name 'user-list.nix' ! -name 'extra-users.nix' \
        -printf '%f\n' | sed 's/\.nix$//' | sort
    )
  fi
}

build_user_mapping() {
  declare -gA USER_MAP=()
  local primary="${DISCOVERED_USERS[0]:-}" idx repo_user mapped
  for idx in "${!REPO_USERS[@]}"; do
    repo_user="${REPO_USERS[$idx]}"
    mapped="${DISCOVERED_USERS[$idx]:-$primary}"
    [[ -n "$repo_user" && -n "$mapped" ]] || continue
    USER_MAP["$repo_user"]="$mapped"
  done
}

user_mapping_summary() {
  local repo_user out=""
  for repo_user in "${REPO_USERS[@]}"; do
    [[ -n "${USER_MAP[$repo_user]:-}" ]] || continue
    out+="${repo_user} -> ${USER_MAP[$repo_user]}"$'\n'
  done
  printf '%s' "${out:-"(none)"}"
}

# ── Staging ──────────────────────────────────────────────────────────────────
stage_project_copy() {
  [[ -n "$TEMP_ROOT" ]] || TEMP_ROOT="$(mktemp -d)"
  STAGE_DIR="${TEMP_ROOT}/nixos-stage"
  rsync -a --delete "${PROJECT_DIR}/" "${STAGE_DIR}/"
  USERS_DIR="${STAGE_DIR}/users-declared"
  mkdir -p "$USERS_DIR"
}

rewrite_repo_user_data() {
  local base_dir="$1" args=() repo_user
  for repo_user in "${REPO_USERS[@]}"; do
    [[ -n "${USER_MAP[$repo_user]:-}" ]] || continue
    [[ "$repo_user" == "${USER_MAP[$repo_user]}" ]] && continue
    args+=("${repo_user}=${USER_MAP[$repo_user]}")
  done
  [[ ${#args[@]} -eq 0 ]] && return 0

  python3 - "$base_dir" "${args[@]}" <<'PY'
import os
import re
import sys

base_dir = sys.argv[1]
pairs = [arg.split("=", 1) for arg in sys.argv[2:]]
patterns = [(re.compile(rf"\b{re.escape(old)}\b"), new) for old, new in pairs if old and new and old != new]
suffixes = {
    ".nix", ".sh", ".md", ".conf", ".toml", ".json", ".yaml", ".yml", ".ini", ".txt"
}

changed = 0
for root, dirs, files in os.walk(base_dir):
    dirs[:] = [d for d in dirs if d not in {".git", "result"}]
    for file_name in files:
        if os.path.splitext(file_name)[1] not in suffixes:
            continue
        path = os.path.join(root, file_name)
        try:
            text = open(path, encoding="utf-8").read()
        except Exception:
            continue
        new_text = text
        for pattern, replacement in patterns:
            new_text = pattern.sub(replacement, new_text)
        if new_text != text:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new_text)
            changed += 1

print(changed)
PY
}

write_user_file() {
  local name="$1" desc="$2" shell="$3" is_admin="$4"
  local net="$5" virt="$6" audio="$7" video="$8" input="$9" plugdev="${10}"
  cat > "${USERS_DIR}/${name}.nix" << NIX
# ===========================================================
#  Tak_OS — system user: ${name}
#  Generated by the Tak_OS installer. Safe to edit.
# ===========================================================
{ pkgs, lib, features, ... }:
let
  extraGroups =
    [ ]
    ++ lib.optionals ${is_admin} [ "wheel" ]
    ++ lib.optionals ${net} [ "networkmanager" ]
    ++ lib.optionals (${virt} && features.virtualisation) [ "vboxusers" "docker" ]
    ++ lib.optionals ${audio} [ "audio" ]
    ++ lib.optionals ${video} [ "video" ]
    ++ lib.optionals ${input} [ "input" ]
    ++ lib.optionals ${plugdev} [ "plugdev" ];
in
{
  users.users.${name} = {
    isNormalUser = true;
    description  = "${desc}";
    shell        = pkgs.${shell};
    extraGroups  = extraGroups;
    packages = [
      # pkgs.kate
    ];
  };
}
NIX
  info "Wrote staged ${USERS_DIR}/${name}.nix"
}

write_user_files() {
  local u
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

  {
    printf '# Generated by Tak_OS installer/helper\n[ '
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
    printf '  ];\n}\n'
  } > "${USERS_DIR}/user-modules.nix"
  info "Wrote ${USERS_DIR}/default.nix and ${USERS_DIR}/user-modules.nix"
}

# ── Banner ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}"
cat << 'BANNER'
 ████████╗ █████╗ ██╗  ██╗       ██████╗ ███████╗
    ██╔══╝██╔══██╗██║ ██╔╝      ██╔═══██╗██╔════╝
    ██║   ███████║█████╔╝       ██║   ██║███████╗
    ██║   ██╔══██║██╔═██╗       ██║   ██║╚════██║
    ██║   ██║  ██║██║  ██╗█████╗╚██████╔╝███████║
    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═══╝ ╚═════╝ ╚══════╝
      Installer v5 — automatic, detection-driven
           Declarative. Modular. Yours.
BANNER
printf "${RESET}\n  NixOS version  : %s\n  Mode           : %s%s\n\n" \
  "$REPO_VERSION" "$MODE" "$([[ $DRY_RUN == true ]] && echo ' (dry run)')"

# Discovery and mapping run before any prompt or staging.
load_discovered_users
load_repo_users
build_user_mapping

# ── Phase 1 ──────────────────────────────────────────────────────────────────
TEMP_ROOT="$(mktemp -d)"
step "Phase 1: Channel upgrade"
if [[ "$DRY_RUN" == "true" ]]; then
  info "Skipped in dry run."
else
  nix-channel --add "https://nixos.org/channels/nixos-${REPO_VERSION}" nixos
  nix-channel --add \
    "https://github.com/nix-community/home-manager/archive/release-${REPO_VERSION}.tar.gz" \
    home-manager
  nix-channel --update
  nixos-rebuild build 2>/dev/null && ok "Baseline build OK." \
    || warn "Baseline build failed — continuing (expected on fresh systems)."
fi
ok "Phase 1 complete."

# ── Phase 2 ──────────────────────────────────────────────────────────────────
step "Phase 2: Detection"
INSTALL_HOST="$(hostname -s 2>/dev/null || hostname)"
DETECTED_FILE="${TEMP_ROOT}/hardware-detected.nix"
run_detection "$DETECTED_FILE"
describe_detection

GPU_KERNEL="$DET_KERNEL"
GPU_DRIVER="$DET_DRIVER"
FEATURES[VIRTUALISATION]="$([[ "$DET_VIRT_CAPABLE" == "true" ]] && echo true || echo false)"

[[ ${#DISCOVERED_USERS[@]} -eq 0 ]] && \
  die "No existing users were discovered. Create a real user first, then run the installer again."
ok "Detected ${#DISCOVERED_USERS[@]} user(s): ${DISCOVERED_USERS[*]}"

# ── Edit mode (TUI) ──────────────────────────────────────────────────────────
_lhost()  { echo "$INSTALL_HOST"; }
_lgpu()   { echo "${GPU_KERNEL}/${GPU_DRIVER}"; }
_lusers() { echo "${DISCOVERED_USERS[*]}"; }
_lvirt()  { echo "${FEATURES[VIRTUALISATION]}"; }

scr_hostname() {
  local h; while true; do
    h="$(tui_input "Hostname" "System hostname:" "$INSTALL_HOST")"
    [[ "$h" =~ ^[a-zA-Z0-9._-]+$ ]] && { INSTALL_HOST="$h"; return; }
    tui_msg "Error" "Invalid hostname — letters, digits, dots, hyphens only."
  done
}

scr_gpu() {
  GPU_KERNEL="$(tui_radio "GPU — Kernel Profile" "Kernel parameter profile:" \
    "generic"  "Safe default — any hardware" "$([[ $GPU_KERNEL == generic  ]] && echo ON || echo OFF)" \
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

scr_virt() {
  if tui_yesno "Virtualisation" \
"Enable the virtualisation feature (VirtualBox, Docker, libvirt groups)?
Detected CPU support: ${DET_VIRT_CAPABLE}
Current: ${FEATURES[VIRTUALISATION]}"; then
    FEATURES[VIRTUALISATION]="true"
  else
    FEATURES[VIRTUALISATION]="false"
  fi
}

scr_users() {
  local preview="" u role
  for u in "${DISCOVERED_USERS[@]}"; do
    role="user"
    [[ "${DISC_ADMIN[$u]:-false}" == "true" ]] && role="admin"
    preview+="- ${u} (${DISC_DESC[$u]:-$u}) :: shell=${DISC_SHELL[$u]:-bash} role=${role} net=${DISC_NET[$u]:-false} virt=${DISC_VIRT[$u]:-false} audio=${DISC_AUDIO[$u]:-false} video=${DISC_VIDEO[$u]:-false} input=${DISC_INPUT[$u]:-false} plugdev=${DISC_PLUGDEV[$u]:-false}"$'\n'
  done
  tui_msg "Discovered Users" "Tak_OS uses the existing users instead of creating new ones.\n\nCurrent discovered users:\n${preview}"
}

scr_review() {
  local _repo_users="${REPO_USERS[*]:-(none detected)}"
  local _mapping; _mapping="$(user_mapping_summary)"
  tui_msg "Review" \
"Hostname       : ${INSTALL_HOST}

GPU            : kernelParams=${GPU_KERNEL}  driver=${GPU_DRIVER}
Detected GPU   : ${DET_GPUS:-none} (VM guest: ${DET_GUEST})
NixOS          : ${REPO_VERSION}
Virtualisation : ${FEATURES[VIRTUALISATION]}

Repo users     : ${_repo_users}
Discovered     : ${DISCOVERED_USERS[*]}
User remap     :
${_mapping}

Your repository working tree is left untouched; replacements happen only in the staged install copy."
}

if [[ "$MODE" == "edit" ]]; then
  _APPLIED="false"
  while true; do
    _choice="$(tui_menu "Tak_OS Installer v5 — edit" \
      "Detected values are pre-filled. Change what you need, then Apply." \
      "hostname" "Hostname         [$(_lhost)]"   \
      "gpu"      "GPU / Kernel     [$(_lgpu)]"    \
      "virt"     "Virtualisation   [$(_lvirt)]"   \
      "users"    "Discovered users [$(_lusers)]"  \
      "review"   "Review summary"                 \
      "apply"    "Apply & Install"                \
      "quit"     "Quit / Abort")"
    case "$_choice" in
      hostname) scr_hostname ;;
      gpu)      scr_gpu ;;
      virt)     scr_virt ;;
      users)    scr_users ;;
      review)   scr_review ;;
      apply)
        scr_review
        tui_yesno "Confirm" "Proceed with installation?" || continue
        _APPLIED="true"; break ;;
      quit) die "Aborted by user." ;;
    esac
  done
  [[ "$_APPLIED" != "true" ]] && die "Nothing applied."
else
  info "Automatic mode: installing with the detected values (use --edit to change them)."
fi

# ── Phase 3 ──────────────────────────────────────────────────────────────────
step "Phase 3: Generating configuration"
stage_project_copy
rewrite_repo_user_data "${STAGE_DIR}" >/dev/null

# Automatic mode leaves the GPU/kernel choice to hardware-detect.nix, which
# resolves "auto" from the hardware-detected.nix copied below.
if [[ "$MODE" == "auto" ]]; then
  KERNEL_VALUE="auto"; DRIVER_VALUE="auto"
else
  KERNEL_VALUE="$GPU_KERNEL"; DRIVER_VALUE="$GPU_DRIVER"
fi
cp "$DETECTED_FILE" "${STAGE_DIR}/hardware-detected.nix"
sed -i "s/^\(\s*kernelParams\s*=\s*\)\"[^\"]*\";/\1\"${KERNEL_VALUE}\";/" "${STAGE_DIR}/configuration.nix"
sed -i "s/^\(\s*gpu\s*=\s*\)\"[^\"]*\";/\1\"${DRIVER_VALUE}\";/" "${STAGE_DIR}/configuration.nix"

FEATURE_ARGS=()
for key in "${FEATURE_ORDER[@]}"; do FEATURE_ARGS+=("${key}=${FEATURES[$key]}"); done
apply_feature_markers "${STAGE_DIR}/configuration.nix" "${FEATURE_ARGS[@]}"

sed -i "s/networking\.hostName = \"[^\"]*\"/networking.hostName = \"${INSTALL_HOST}\"/" \
  "${STAGE_DIR}/modules/networking.nix"

write_user_files
info "Hostname=${INSTALL_HOST}  GPU=${KERNEL_VALUE}/${DRIVER_VALUE}  Virtualisation=${FEATURES[VIRTUALISATION]}"
info "Repo user data was remapped only inside the staged install copy."
ok "Configuration generated at ${STAGE_DIR}."

if [[ "$DRY_RUN" == "true" ]]; then
  step "Dry run finished"
  ok "Nothing was deployed or built. Staged copy kept at: ${STAGE_DIR}"
  exit 0
fi

# ── Phase 4 ──────────────────────────────────────────────────────────────────
step "Phase 4: Deploying to ${TARGET_DIR}"
[[ -f "${TARGET_DIR}/hardware-configuration.nix" ]] && cp "${TARGET_DIR}/hardware-configuration.nix" "${TEMP_ROOT}/hardware-configuration.nix"
rsync -a --delete "${STAGE_DIR}/" "${TARGET_DIR}/"
[[ -f "${TEMP_ROOT}/hardware-configuration.nix" ]] && cp "${TEMP_ROOT}/hardware-configuration.nix" "${TARGET_DIR}/"
ok "Deployment complete."

# ── Phase 5 ──────────────────────────────────────────────────────────────────
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

# ── Phase 6 ──────────────────────────────────────────────────────────────────
step "Phase 6: Switch"
info "Switching to Tak_OS…"
nixos-rebuild switch
ok "Switch complete."

# ── Phase 7 ──────────────────────────────────────────────────────────────────
step "Phase 7: Restore auto-commented packages"
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
if [[ -s "$COMMENT_LOG" ]]; then
  if [[ "$MODE" == "edit" ]]; then
    if tui_yesno "Restore" "Restore auto-commented packages and rebuild?"; then
      "$RESTORE"; info "Rebuilding…"; nixos-rebuild switch
    fi
  else
    warn "Some packages were auto-commented because they failed to build."
    info "Review them, then restore with: sudo ${RESTORE}"
  fi
fi

printf "\n${GREEN}${BOLD}  Tak_OS installation complete.${RESET}\n\n"
printf "  Per-user files : ${TARGET_USERS_DIR}/<name>.nix\n"
printf "  Users hub      : ${TARGET_USERS_DIR}/default.nix\n"
printf "  Home Manager   : ~/.hm-local/home.nix  (per user)\n"
printf "  GPU            : kernelParams=%s  driver=%s\n" "$GPU_KERNEL" "$GPU_DRIVER"
printf "  Hardware       : %s\n" "${DET_GPUS:-no GPU}, guest=${DET_GUEST}"
[[ -s "$COMMENT_LOG" ]] && printf "  Restore pkgs   : sudo %s\n" "$RESTORE"
printf "\n"
