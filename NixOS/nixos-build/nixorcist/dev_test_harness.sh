#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$REPO_ROOT/DEVELOPMENT_LOGS.txt"
COUNTER="${1:-0}"

log() {
  local phase="$1"
  local msg="$2"
  printf '%s | %s | %s | Counter=%s\n' "$(date '+%F %T')" "$phase" "$msg" "$COUNTER" >> "$LOG_FILE"
}

sandbox="$(mktemp -d /tmp/nixorcist-harness-XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT
FZF_CALL_FILE="$sandbox/fzf-call-count"
printf '0\n' > "$FZF_CALL_FILE"

ROOT="$REPO_ROOT"
export ROOT
LOCK_FILE="$sandbox/.lock"
MODULES_DIR="$sandbox/.modules"
mkdir -p "$MODULES_DIR" "$ROOT/cache"
export LOCK_FILE MODULES_DIR

cat > "$ROOT/cache/nixpkgs-index.txt" <<'IDX'
eclipses|
eclipses.eclipse-java|Eclipse Java IDE
eclipses.eclipse-cpp|Eclipse C++ IDE
swaync.package|Sway notification center package
swaync.package.service|Sway notification center service
waybar.modules|Waybar module owner
waybar.modules.cpu|Waybar CPU module
nano|Nano editor
IDX
printf '3\n' > "$ROOT/cache/nixpkgs-index.version"

# shellcheck disable=SC1091
source "$ROOT/lib/cli.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/index.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/utils.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/lock.sh"

# Stubs to avoid noise during tests.
show_logo() { :; }
show_section_header() { :; }
show_section() { :; }
show_warning() { printf 'WARN: %s\n' "$1" >&2; }
show_error() { printf 'ERR: %s\n' "$1" >&2; }
show_item() { printf 'ITEM: %s %s\n' "$1" "$2" >&2; }
show_success() { :; }
show_info() { :; }
nixorcist_trace() { :; }
nixorcist_trace_selection() { :; }

# Keep utils lookups deterministic for tests.
_flake_attr_kind() {
  case "$1" in
    eclipses) echo attrset ;;
    eclipses.eclipse-java|eclipses.eclipse-cpp|nano|swaync.package) echo derivation ;;
    *) echo missing ;;
  esac
}
_flake_attr_children() {
  case "$1" in
    eclipses)
      printf '%s\n' eclipse-java eclipse-cpp
      ;;
    *)
      return 0
      ;;
  esac
}
_flake_attr_description() {
  case "$1" in
    eclipses.eclipse-java) echo "Eclipse Java IDE" ;;
    eclipses.eclipse-cpp) echo "Eclipse C++ IDE" ;;
    swaync.package) echo "SwayNC package" ;;
    nano) echo "Nano editor" ;;
    eclipses) echo "Attribute set" ;;
    *) echo "No description" ;;
  esac
}
_flake_attr_long_description() {
  case "$1" in
    nano) echo "Small and friendly text editor." ;;
    *) echo "" ;;
  esac
}

# 1) Attrset decision menu test (eclipses + W)
log "TEST-BEFORE" "Goal=Attrset decision menu for eclipses using W select-all"
TX_QUERY_ADD=()
printf 'w\n' | {
  declare -A tmp=()
  transaction_resolve_token_for_query "eclipses" tmp
  [[ -n "${tmp[eclipses.eclipse-java]:-}" ]]
  [[ -n "${tmp[eclipses.eclipse-cpp]:-}" ]]
}
log "TEST-AFTER" "Result=PASS attrset decision selected expected children"

log "TEST-BEFORE" "Goal=True repeated owner-search menu-A->menu-B flow with persistent owner annotations"
fzf() {
  local current_call=0
  cat >/dev/null || true
  current_call="$(cat "$FZF_CALL_FILE")"
  current_call=$((current_call + 1))
  printf '%s\n' "$current_call" > "$FZF_CALL_FILE"
  case "$current_call" in
    # Menu A: owner action from query swaync
    1)
      printf 'enter\n'
      printf 'swaync\n'
      printf '__OWNER_SEARCH__\tOWNER SEARCH FROM CURRENT QUERY\n'
      ;;
    # Menu B: choose owner candidate swaync.package
    2)
      printf 'enter\n'
      printf 'swaync.package\n'
      ;;
    # Approval menu: choose Yes
    3)
      printf 'enter\n'
      printf 'Yes - add owner package\n'
      ;;
    # Menu A again: owner action from query cpu
    4)
      printf 'enter\n'
      printf 'cpu\n'
      printf '__OWNER_SEARCH__\tOWNER SEARCH FROM CURRENT QUERY\n'
      ;;
    # Menu B: choose second owner candidate waybar.modules
    5)
      printf 'enter\n'
      printf 'waybar.modules\n'
      ;;
    # Approval menu: choose Yes
    6)
      printf 'enter\n'
      printf 'Yes - add owner package\n'
      ;;
    # Menu A again: finalize by selecting nano
    7)
      printf 'enter\n'
      printf 'nano\n'
      printf 'nano\tnano\n'
      ;;
    *)
      return 1
      ;;
  esac
}
selected="$(transaction_pick_from_index)"
[[ "$(printf '%s\n' "$selected" | sort -u | tr '\n' ' ')" == *"nano"* ]]
[[ "$(printf '%s\n' "$selected" | sort -u | tr '\n' ' ')" == *"swaync.package"* ]]
[[ "$(printf '%s\n' "$selected" | sort -u | tr '\n' ' ')" == *"waybar.modules"* ]]
[[ "$(cat "$FZF_CALL_FILE")" == "7" ]]
log "TEST-AFTER" "Result=PASS repeated owner-search stayed in menu A, invoked menu B twice, and returned combined selections"

# 3) Edge test: empty/invalid token sanitize path
log "TEST-BEFORE" "Goal=Edge token validation"
transaction_add_to_query add "   " >/dev/null
if transaction_add_to_query add "bad token" >/dev/null 2>&1; then
  echo "expected invalid token failure" >&2
  exit 1
fi
log "TEST-AFTER" "Result=PASS invalid token rejected"

# 4) Description cache test in-session
log "TEST-BEFORE" "Goal=Description cache reuse"
export NIXORCIST_DESC_CACHE_DIR="$sandbox/desc-cache"
mkdir -p "$NIXORCIST_DESC_CACHE_DIR"
get_pkg_preview_text "nano" >/dev/null
get_pkg_preview_text "nano" >/dev/null
[[ -f "$NIXORCIST_DESC_CACHE_DIR/nano.short" ]]
[[ -f "$NIXORCIST_DESC_CACHE_DIR/nano.long" ]]
log "TEST-AFTER" "Result=PASS description cache files present"

# 5) Timing probes for key commands/functions
log "TEST-BEFORE" "Goal=Timing probes for core command paths"
start=$SECONDS
ensure_index >/dev/null
t_ensure=$((SECONDS - start))
start=$SECONDS
declare -A _tmp_map=()
printf 'w\n' | transaction_resolve_token_for_query "eclipses" _tmp_map 2>/dev/null || true
t_attr=$((SECONDS - start))
start=$SECONDS
printf '0\n' > "$FZF_CALL_FILE"
fzf() {
  cat >/dev/null || true
  printf 'enter\n'
  printf 'nano\n'
  printf 'nano\tnano\n'
}
selected2="$(transaction_pick_from_index)"
t_pick=$((SECONDS - start))
log "TEST-AFTER" "Result=PASS timings ensure_index=${t_ensure}s attrset=${t_attr}s pick=${t_pick}s pickResult=${selected2:-<empty>}"

echo "ALL_TESTS_PASSED"
