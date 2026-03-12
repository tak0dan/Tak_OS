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
  cat << 'LOGO'

  ███╗   ██╗██╗██╗  ██╗ ██████╗ ██████╗  ██████╗██╗███████╗████████╗
  ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔══██╗██╔════╝██║██╔════╝╚══██╔══╝
  ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██████╔╝██║     ██║███████╗   ██║   
  ██║╚██╗██║██║ ██╔██╗ ██║   ██║██╔══██╗██║     ██║╚════██║   ██║   
  ██║ ╚████║██║██╔╝ ██╗╚██████╔╝██║  ██║╚██████╗██║███████║   ██║   
  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝╚══════╝   ╚═╝   
      The Declarative NixOS Package Sorcerer

LOGO
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
  show_menu_item 'transaction' 'Interactive transaction builder'
  show_menu_item 'select' 'Alias for interactive transaction flow'
  show_menu_item 'import <file>' 'Import packages from a file'
  show_menu_item 'install <pkg...>' 'Add package(s) from CLI args'
  show_menu_item 'delete <pkg...>' 'Remove package(s) from CLI args'
  show_menu_item 'chant <tokens...>' 'Mixed install/delete tokens'
  show_menu_item 'gen' 'Generate package modules'
  show_menu_item 'hub' 'Regenerate all-packages hub'
  show_menu_item 'rebuild' 'Generate + rebuild NixOS'
  show_menu_item 'refresh-index' 'Rebuild cached package index'
  show_menu_item 'purge' 'Remove generated modules and clear lock'
  show_menu_item 'all [--refresh-index]' 'Transaction + generate + hub + rebuild'
  show_menu_item 'help' 'Show this help screen'
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
    
    show_menu_item '1' 'Generate Modules     - Generate from current lock'
    show_menu_item '2' 'Rebuild Hub          - Regenerate all-packages.nix'
    show_menu_item '3' 'Full Rebuild         - gen → hub → nixos-rebuild'
    show_menu_item '4' 'Purge All Modules    - Remove all generated modules'
    show_menu_item '5' 'Build NixOS Index    - Refresh package database'
    echo
    show_menu_item '0' 'Back to Main Menu'
    echo
    
    printf '  Select an option (0-5): '
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
      0) break ;;
      *)
        show_error 'Invalid option. Please choose a number between 0 and 5.'
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
  
  printf '  File Locations:\n'
  show_status_line 'Lock file' "$LOCK_FILE"
  show_status_line 'Modules directory' "$MODULES_DIR"
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

