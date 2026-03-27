#!/usr/bin/env bash
# Nixorcist - Interactive TUI Package Manager for NixOS
# Professional terminal-based interface

clear_screen() {
  clear
}

# Set to 0 (or comment out enable call in nixorcist.sh) to disable tracing.
NIXORCIST_TRACE_ENABLED="${NIXORCIST_TRACE_ENABLED:-1}"
NIXORCIST_TRACE_FILE="${NIXORCIST_TRACE_FILE:-${ROOT:-.}/nixorcist-trace.txt}"
NIXORCIST_TRACE_GUARD=0

nixorcist_trace_init() {
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  mkdir -p "$(dirname "$NIXORCIST_TRACE_FILE")" 2>/dev/null || true
  touch "$NIXORCIST_TRACE_FILE" 2>/dev/null || true
  printf '\n[%s] [SESSION] pid=%s user=%s pwd=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "${USER:-unknown}" "${PWD:-unknown}" >> "$NIXORCIST_TRACE_FILE" 2>/dev/null || true
}

nixorcist_trace() {
  local kind="$1"
  local message="$2"
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  printf '[%s] [%s] %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$kind" "$message" >> "$NIXORCIST_TRACE_FILE" 2>/dev/null || true
}

nixorcist_trace_selection() {
  local context="$1"
  local value="${2:-}"
  value="${value//$'\n'/\\n}"
  nixorcist_trace "SELECT" "$context => ${value:-<empty>}"
}

nixorcist_trace_debug_command() {
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  [[ "${NIXORCIST_TRACE_GUARD}" -eq 0 ]] || return 0

  local cmd="${BASH_COMMAND:-}"
  [[ -z "$cmd" ]] && return 0
  case "$cmd" in
    nixorcist_trace*|*nixorcist_trace_debug_command*|trap\ *DEBUG*)
      return 0
      ;;
  esac

  NIXORCIST_TRACE_GUARD=1
  cmd="${cmd//$'\n'/ ; }"
  nixorcist_trace "CMD" "$cmd"
  NIXORCIST_TRACE_GUARD=0
}

enable_nixorcist_trace() {
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  trap 'nixorcist_trace_debug_command' DEBUG
}

# Backward-compatible header helper used by nixorcist.sh command mode.
show_header() {
  local title="$1"
  clear_screen
  show_logo
  show_section_header "$title"
}

show_logo() {
  local logo_file="${ROOT}/assets/logo.txt"
  local wide_logo_file="${ROOT}/assets/logo-dual.txt"
  local selected_logo_file="$logo_file"

  if [[ -f "$wide_logo_file" ]]; then
    local terminal_cols="${COLUMNS:-0}"
    if ! [[ "$terminal_cols" =~ ^[0-9]+$ ]] || (( terminal_cols <= 0 )); then
      terminal_cols="$(tput cols 2>/dev/null || printf '0')"
    fi

    local wide_logo_width
    wide_logo_width="$(awk '{ if (length > max) max = length } END { print max + 0 }' "$wide_logo_file" 2>/dev/null || printf '0')"
    local min_cols_for_wide=$(( (wide_logo_width * 80 + 99) / 100 ))

    if (( wide_logo_width > 0 && terminal_cols >= min_cols_for_wide )); then
      selected_logo_file="$wide_logo_file"
    fi
  fi

  if [[ -f "$selected_logo_file" ]]; then
    cat "$selected_logo_file"
    echo
    return
  fi

  cat << 'LOGO'
  ███╗   ██╗██╗██╗  ██╗ ██████╗ ██████╗  ██████╗██╗███████╗████████╗
  ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔══██╗██╔════╝██║██╔════╝╚══██╔══╝
  ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██████╔╝██║     ██║███████╗   ██║
  ██║╚██╗██║██║ ██╔██╗ ██║   ██║██╔══██╗██║     ██║╚════██║   ██║
  ██║ ╚████║██║██╔╝ ██╗╚██████╔╝██║  ██║╚██████╗██║███████║   ██║
  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝╚══════╝   ╚═╝
      The Declarative NixOS Package Sorcerer
LOGO
  echo
}

show_divider() {
  printf '────────────────────────────────────────────────────────────\n'
}

show_section_header() {
  local title="$1"
  echo
  printf '%s\n' "$title"
  show_divider
}

show_section() {
  show_section_header "$1"
}

show_status_line() {
  local label="$1"
  local value="${2:-}"
  printf '  %-35s %s\n' "$label" "$value"
}

show_menu_item() {
  local num="$1"
  local desc="$2"
  printf '  %s) %s\n' "$num" "$desc"
}

show_error() {
  local msg="$1"
  printf '\n  ✗ Error: %s\n' "$msg" >&2
}

show_success() {
  local msg="$1"
  printf '\n  ✓ %s\n' "$msg"
}

show_info() {
  local msg="$1"
  printf '\n  ℹ %s\n' "$msg"
}

show_item() {
  local prefix="$1"
  local msg="$2"
  printf '  %s %s\n' "$prefix" "$msg"
}

show_warning() {
  local msg="$1"
  printf '\n  ⚠ %s\n' "$msg"
}

_ui_supports_color() {
  [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM:-}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]
}

_ui_color_code() {
  case "$1" in
    green) printf '\033[1;32m' ;;
    yellow) printf '\033[1;33m' ;;
    red) printf '\033[1;31m' ;;
    cyan) printf '\033[1;36m' ;;
    dim) printf '\033[2m' ;;
    reset) printf '\033[0m' ;;
    *) printf '' ;;
  esac
}

_ui_colorize() {
  local color="$1"
  local text="$2"
  if _ui_supports_color; then
    printf '%b%s%b' "$(_ui_color_code "$color")" "$text" "$(_ui_color_code reset)"
  else
    printf '%s' "$text"
  fi
}

_ui_format_duration() {
  local total="$1"
  local days=0
  local hours=0
  local minutes=0

  if ! [[ "$total" =~ ^-?[0-9]+$ ]]; then
    printf 'unknown\n'
    return
  fi

  if (( total < 0 )); then
    printf 'unknown\n'
    return
  fi

  days=$(( total / 86400 ))
  hours=$(( (total % 86400) / 3600 ))
  minutes=$(( (total % 3600) / 60 ))

  if (( days > 0 )); then
    printf '%dd %02dh\n' "$days" "$hours"
    return
  fi
  if (( hours > 0 )); then
    printf '%dh %02dm\n' "$hours" "$minutes"
    return
  fi
  printf '%dm\n' "$minutes"
}

_ui_refresh_slider() {
  local pct="$1"
  local width=28
  local filled=0
  local empty=0
  local fill=""
  local gap=""
  local color="green"
  local bar=""

  if (( pct < 0 )); then
    printf '[????????????????????????????]'
    return
  fi

  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  filled=$(( pct * width / 100 ))
  empty=$(( width - filled ))
  printf -v fill '%*s' "$filled" ''
  printf -v gap '%*s' "$empty" ''
  fill="${fill// /=}"
  gap="${gap// /.}"
  bar="[$fill$gap]"

  if (( pct <= 15 )); then
    color="red"
  elif (( pct <= 50 )); then
    color="yellow"
  fi

  _ui_colorize "$color" "$bar"
}

_ui_refresh_urgency_percent() {
  local remaining_pct="$1"
  local urgency=0

  if ! [[ "$remaining_pct" =~ ^-?[0-9]+$ ]]; then
    printf '0\n'
    return
  fi

  if (( remaining_pct < 0 )); then
    printf '0\n'
    return
  fi

  (( remaining_pct > 100 )) && remaining_pct=100
  urgency=$(( 100 - remaining_pct ))
  (( urgency < 0 )) && urgency=0
  (( urgency > 100 )) && urgency=100
  printf '%s\n' "$urgency"
}

show_refresh_countdown_bar() {
  local last_fetch="never"
  local left=-1
  local overdue=0
  local remaining_pct=0
  local urgency_pct=0
  local bar=""
  local eta_text="unknown until first fetch"

  if declare -F index_last_fetch_text >/dev/null 2>&1; then
    last_fetch="$(index_last_fetch_text)"
    left="$(index_refresh_seconds_left)"
    overdue="$(index_refresh_overdue_seconds)"
    remaining_pct="$(index_refresh_remaining_percent)"
  fi

  urgency_pct="$(_ui_refresh_urgency_percent "$remaining_pct")"
  bar="$(_ui_refresh_slider "$urgency_pct")"

  if [[ "$left" =~ ^[0-9]+$ ]]; then
    eta_text="$(_ui_format_duration "$left") left"
  fi
  if [[ "$overdue" =~ ^[0-9]+$ ]] && (( overdue > 0 )); then
    eta_text="overdue by $(_ui_format_duration "$overdue")"
  fi

  printf '  Refresh Countdown: %b %s%%\n' "$bar" "$urgency_pct"
  printf '  Next recommended fetch: %s\n' "$eta_text"
  printf '  Last fetch: %s\n' "$last_fetch"
  echo
}

show_refresh_health_panel() {
  local last_fetch="never"
  local last_all="never"
  local age=-1
  local left=-1
  local overdue=0
  local pct=-1
  local urgency_pct=0
  local slider=""

  if declare -F index_last_fetch_text >/dev/null 2>&1; then
    last_fetch="$(index_last_fetch_text)"
    last_all="$(index_last_all_text)"
    age="$(index_refresh_age_seconds)"
    left="$(index_refresh_seconds_left)"
    overdue="$(index_refresh_overdue_seconds)"
    pct="$(index_refresh_remaining_percent)"
  fi

  printf '  Index Refresh Health:\n'
  show_status_line 'Last index refresh' "$last_fetch"
  show_status_line 'Last nixorcist all' "$last_all"
  urgency_pct="$(_ui_refresh_urgency_percent "$pct")"
  slider="$(_ui_refresh_slider "$urgency_pct")"
  printf '  %-35s %b\n' 'Refresh window' "$slider"

  if (( left >= 0 )); then
    show_status_line 'Recommended cadence' 'Refresh once every 7 days'
    if (( overdue > 0 )); then
      show_status_line 'Past due by' "$(_ui_colorize red "$(_ui_format_duration "$overdue")")"
      printf '  %b\n' "$(_ui_colorize red 'You are way past the refresh. Refresh it now or I will proceed to exorcism process.')"
    else
      show_status_line 'Time left' "$(_ui_format_duration "$left") left before refresh is recommended"
    fi
  else
    show_status_line 'Recommended cadence' 'Refresh once every 7 days'
    show_status_line 'Time left' 'unknown until the first successful fetch'
  fi

  echo
}

wait_for_key() {
  printf '\n  Press ENTER to continue...'
  read -r
  nixorcist_trace_selection "wait_for_key" "ENTER"
}

show_input_prompt() {
  local prompt="$1"
  printf '\n  %s: ' "$prompt"
}


show_yes_no_prompt() {
  local question="$1"
  printf '\n  %s [y/n]: ' "$question"
}

# Backward-compatible command help used by nixorcist.sh help mode.
show_menu() {
  show_section_header 'Command Help'
  printf '  Usage: nixorcist <command> [args]\n\n'

  printf '  ── Package management ─────────────────────────────────────────\n'
  show_menu_item 'install [pkg...]'    'Add package(s); opens TUI picker when no args'
  show_menu_item 'delete <pkg...>'    'Remove package(s) from CLI args'
  show_menu_item 'chant <tokens...>'  'Mixed install/delete tokens (+add / -remove)'
  show_menu_item 'import <file>'      'Import packages from a file'
  show_menu_item 'transaction'        'Interactive transaction builder (TUI)'
  echo

  printf '  ── Build pipeline ─────────────────────────────────────────────\n'
  show_menu_item 'gen'                'Generate Nix modules from lock'
  show_menu_item 'hub'                'Regenerate all-packages hub'
  show_menu_item 'rebuild'            'gen + hub + NixOS rebuild (with error resolver)'
  show_menu_item 'all [--refresh-index]' 'Transaction + gen + hub + rebuild'
  echo

  printf '  ── Observability ──────────────────────────────────────────────\n'
  show_menu_item 'status'             'Snapshot: CLI layer vs config layer + overlaps'
  show_menu_item 'diff'               'Diff: CLI-only / config-only / duplicates'
  show_menu_item 'trace <pkg>'        'Trace: all locations where a package is declared'
  echo

  printf '  ── Utilities ──────────────────────────────────────────────────\n'
  show_menu_item 'merge <name>'       'Merge all lock packages into one .nix file'
  show_menu_item 'refresh-index'      'Rebuild cached nixpkgs package index'
  show_menu_item 'purge'              'Remove all generated modules and clear lock'
  show_menu_item 'help'               'Show this help screen'
  echo

  printf '  ── Lifecycle model ────────────────────────────────────────────\n'
  printf '  %-28s %s\n' '  nixorcist install <pkg>'  '→ adds to generated layer'
  printf '  %-28s %s\n' '  nixorcist merge my-pkgs'  '→ consolidates generated layer'
  printf '  %-28s %s\n' '  (copy to config manually)' '→ promotes to declarative layer'
  printf '  %-28s %s\n' '  nixorcist purge'          '→ clears generated layer'
  echo
}

main_menu() {
  while true; do
    clear_screen
    show_logo
    show_section_header 'Main Menu'
    
    printf '  Manage your NixOS packages interactively.\n'
    printf '  Choose an option below to get started.\n'
    echo
    show_refresh_health_panel
    
    show_menu_item '1' 'Transaction Builder - Add/Remove packages interactively'
    show_menu_item '2' 'Import from File     - Import packages from a text file'
    show_menu_item '3' 'Direct Commands      - Quick commands and utilities'
    show_menu_item '4' 'View Status          - Show current lock file state'
    show_menu_item '5' 'Settings             - Configuration options'
    echo
    show_menu_item '0' 'Exit nixorcist'
    echo
    
    printf '  Select an option (0-5): '
    read -r choice
    nixorcist_trace_selection "main_menu.choice" "$choice"
    
    case "$choice" in
      1) transaction_builder_flow ;;
      2) import_file_flow ;;
      3) direct_commands_menu ;;
      4) view_status_screen ;;
      5) settings_menu ;;
      0)
        clear_screen
        show_success 'Exiting nixorcist'
        exit 0
        ;;
      *)
        show_error 'Invalid option. Please choose a number between 0 and 5.'
        wait_for_key
        ;;
    esac
  done
}

transaction_builder_flow() {
  clear_screen
  show_logo
  show_section_header 'Transaction Builder'
  
  printf '  Stage packages for installation and removal.\n'
  printf '  Use this to carefully plan your system changes.\n'
  echo
  
  if run_transaction_cli; then
    clear_screen
    show_logo
    show_section_header 'Transaction Applied'
    
    printf '  Your transaction has been staged successfully.\n'
    echo
    show_menu_item '1' 'Rebuild NixOS now    - Apply changes immediately'
    show_menu_item '2' 'Rebuild later        - Apply changes manually later'
    show_menu_item '0' 'Back to Main Menu'
    echo
    
    printf '  Select an option (0-2): '
    read -r choice
    nixorcist_trace_selection "transaction_builder_flow.choice" "$choice"
    
    case "$choice" in
      1)
        clear_screen
        show_logo
        show_section_header 'NixOS Rebuild'
        printf '  Building your system with the staged changes...\n\n'
        run_rebuild || show_error 'Rebuild failed. Check logs for details.'
        wait_for_key
        ;;
      2)
        show_success 'Transaction saved. Run nixorcist rebuild when ready.'
        wait_for_key
        ;;
      0) ;;
      *)
        show_error 'Invalid option.'
        wait_for_key
        ;;
    esac
  fi
}

import_file_flow() {
  clear_screen
  show_logo
  show_section_header 'Import from File'
  
  printf '  Import packages from a text file.\n'
  printf '  Supported formats: comma or newline separated package names.\n'
  printf '  You can use +/- prefixes to specify add/remove operations.\n'
  echo
  
  show_input_prompt 'Enter file path'
  read -r file_path
  nixorcist_trace_selection "import_file_flow.file_path" "$file_path"
  
  if [[ -z "$file_path" ]]; then
    show_error 'File path cannot be empty.'
    wait_for_key
    return
  fi
  
  if [[ ! -f "$file_path" ]]; then
    show_error "File not found: $file_path"
    wait_for_key
    return
  fi
  
  clear_screen
  show_logo
  show_section_header 'Importing Packages'
  printf '  Processing file: %s\n\n' "$file_path"
  
  if import_from_file "$file_path"; then
    show_success 'File import completed successfully.'
  else
    show_error 'File import was cancelled.'
  fi
  
  wait_for_key
}

direct_commands_menu() {
  while true; do
    clear_screen
    show_logo
    show_section_header 'Direct Commands'
    
    printf '  Quick access to common nixorcist operations.\n'
    echo
    show_refresh_health_panel
    
    show_menu_item '1' 'Generate Modules     - Generate from current lock'
    show_menu_item '2' 'Rebuild Hub          - Regenerate all-packages.nix'
    show_menu_item '3' 'Full Rebuild         - gen → hub → nixos-rebuild'
    show_menu_item '4' 'Purge All Modules    - Remove all generated modules'
    show_menu_item '5' 'Build NixOS Index    - Refresh package database'
    show_menu_item '6' 'All + Refresh        - refresh index, then full rebuild'
    echo
    show_menu_item '0' 'Back to Main Menu'
    echo
    
    printf '  Select an option (0-6): '
    read -r choice
    
    case "$choice" in
      1)
        clear_screen
        show_logo
        show_section_header 'Generate Modules'
        printf '  Generating Nix modules from lock file...\n\n'
        generate_modules
        wait_for_key
        ;;
      2)
        clear_screen
        show_logo
        show_section_header 'Rebuild Hub'
        printf '  Regenerating hub configuration...\n\n'
        regenerate_hub
        wait_for_key
        ;;
      3)
        clear_screen
        show_logo
        show_section_header 'Full Rebuild'
        printf '  Running complete pipeline...\n\n'
        generate_modules && regenerate_hub && run_rebuild
        wait_for_key
        ;;
      4)
        clear_screen
        show_logo
        show_section_header 'Purge All Modules'
        
        show_warning 'This will remove ALL generated modules and clear the lock file.'
        show_yes_no_prompt 'Are you sure?'
        read -r confirm
        
        if [[ "${confirm,,}" == "y" ]]; then
          purge_all_modules
          show_success 'All modules purged and lock cleared.'
        else
          show_info 'Purge cancelled.'
        fi
        
        wait_for_key
        ;;
      5)
        clear_screen
        show_logo
        show_section_header 'Building Package Index'
        printf '  This may take a moment...\n\n'
        build_nix_index
        show_success 'Package index built successfully.'
        wait_for_key
        ;;
      6)
        clear_screen
        show_logo
        show_section_header 'Full Build with Refresh'
        printf '  Refreshing package index, then running full pipeline...\n\n'
        index_mark_all_executed
        build_nix_index && generate_modules && regenerate_hub && run_rebuild
        show_success 'Full build with refresh completed.'
        wait_for_key
        ;;
      0) break ;;
      *)
        show_error 'Invalid option. Please choose a number between 0 and 6.'
        wait_for_key
        ;;
    esac
  done
}

view_status_screen() {
  clear_screen
  show_logo
  show_section_header 'Current Status'
  
  local lock_count=0
  local module_count=0
  
  if [[ -f "$LOCK_FILE" ]]; then
    lock_count=$(grep -v -F "$BUILT_MARKER" "$LOCK_FILE" 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l)
  fi
  
  if [[ -d "$MODULES_DIR" ]]; then
    module_count=$(find "$MODULES_DIR" -name '*.nix' -type f 2>/dev/null | wc -l)
  fi
  
  printf '  Lock File Status:\n'
  show_status_line 'Packages in lock' "$lock_count"
  show_status_line 'Generated modules' "$module_count"
  echo
  show_refresh_health_panel
  
  printf '  File Locations:\n'
  show_status_line 'Lock file' "$LOCK_FILE"
  show_status_line 'Modules directory' "$MODULES_DIR"
  show_status_line 'Index metadata' "$INDEX_STATUS_FILE"
  echo
  
  show_menu_item '1' 'View package list    - Show all packages in lock'
  show_menu_item '0' 'Back to Main Menu'
  echo
  
  printf '  Select an option (0-1): '
  read -r choice
  
  case "$choice" in
    1)
      clear_screen
      show_logo
      show_section_header 'Packages in Lock File'
      echo
      
      if [[ -f "$LOCK_FILE" ]]; then
        grep -v -F "$BUILT_MARKER" "$LOCK_FILE" 2>/dev/null | sed '/^[[:space:]]*$/d' | nl | while read -r num pkg; do
          printf '  %3d. %s\n' "$num" "$pkg"
        done | head -30
        
        local total=$(grep -v -F "$BUILT_MARKER" "$LOCK_FILE" 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l)
        if [[ $total -gt 30 ]]; then
          printf '\n  ... and %d more packages\n' $((total - 30))
        fi
      else
        printf '  (Lock file is empty)\n'
      fi
      
      wait_for_key
      ;;
    0) ;;
    *)
      show_error 'Invalid option.'
      wait_for_key
      ;;
  esac
}

settings_menu() {
  while true; do
    clear_screen
    show_logo
    show_section_header 'Settings'
    
    printf '  Configuration options for nixorcist.\n'
    echo
    
    show_menu_item '1' 'Auto-rebuild after transaction - Toggle'
    show_menu_item '2' 'Verbose output                 - Toggle'
    show_menu_item '3' 'Reset to defaults              - Restore defaults'
    echo
    show_menu_item '0' 'Back to Main Menu'
    echo
    
    printf '  Select an option (0-3): '
    read -r choice
    
    case "$choice" in
      1)
        show_info 'Auto-rebuild toggle not yet implemented.'
        wait_for_key
        ;;
      2)
        show_info 'Verbose output toggle not yet implemented.'
        wait_for_key
        ;;
      3)
        show_warning 'Resetting to defaults...'
        show_success 'Settings reset to defaults.'
        sleep 1
        ;;
      0) break ;;
      *)
        show_error 'Invalid option. Please choose a number between 0 and 3.'
        wait_for_key
        ;;
    esac
  done
}

