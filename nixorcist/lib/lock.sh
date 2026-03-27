set -euo pipefail

NIXORCIST_MARKER='#$nixorcist$#'
BUILT_MARKER='#$built$#'

: "${LOCK_FILE:?LOCK_FILE not set}"
: "${MODULES_DIR:?MODULES_DIR not set}"

read_lock_entries() {
  grep -v -F "$BUILT_MARKER" "$LOCK_FILE" 2>/dev/null \
    | tr -d '\r' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed '/^[[:space:]]*$/d' \
    | grep -E '^[a-zA-Z0-9._+-]+$' \
    | sort -u
}

write_lock_entries() {
  local -n entries_ref=$1
  printf '%s\n' "${entries_ref[@]}" \
    | tr -d '\r' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed '/^[[:space:]]*$/d' \
    | grep -E '^[a-zA-Z0-9._+-]+$' \
    | sort -u > "$LOCK_FILE"
  echo "$BUILT_MARKER" >> "$LOCK_FILE"
}

scan_managed_modules() {
  shopt -s nullglob
  for f in "$MODULES_DIR"/*.nix; do
    if grep -qF "$NIXORCIST_MARKER" "$f" 2>/dev/null; then
      grep -E '^[[:space:]]*#[[:space:]]*NIXORCIST-ATTRPATH:' "$f" \
        | head -1 \
        | sed 's/^[[:space:]]*#[[:space:]]*NIXORCIST-ATTRPATH:[[:space:]]*//'
    fi
  done | sort -u
  shopt -u nullglob
}

transaction_init() {
  declare -gA TX_ADD=()
  declare -gA TX_REMOVE=()
  declare -gA TX_LOCK=()
  declare -gA TX_QUERY_ADD=()
  declare -gA TX_QUERY_REMOVE=()
  TX_FILE="$(mktemp /tmp/nixorcist-transaction.XXXXXX)"

  local pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    TX_LOCK["$pkg"]=1
  done < <(read_lock_entries)
}

transaction_has_query() {
  [[ ${#TX_QUERY_ADD[@]} -gt 0 || ${#TX_QUERY_REMOVE[@]} -gt 0 ]]
}

transaction_add_to_query() {
  local mode="$1"
  local token="$2"

  token="$(sanitize_token "$token")"
  [[ -z "$token" ]] && return 0
  if ! is_valid_token "$token"; then
    show_error "Invalid token: $token"
    return 1
  fi

  if [[ "$mode" == "add" ]]; then
    TX_QUERY_ADD["$token"]=1
    unset TX_QUERY_REMOVE["$token"] 2>/dev/null || true
  else
    TX_QUERY_REMOVE["$token"]=1
    unset TX_QUERY_ADD["$token"] 2>/dev/null || true
  fi

  nixorcist_trace "QUERY" "mode=$mode token=$token"

  return 0
}

_fzf_pkg_preview_cmd() {
  printf 'ROOT=%q; source %q >/dev/null 2>&1; pkg=$(printf "%%s" "{}" | cut -f1); get_pkg_preview_text "$pkg"' \
    "$ROOT" "$ROOT/lib/utils.sh"
}

_fzf_attrset_child_preview_cmd() {
  local attrset="$1"
  printf 'ROOT=%q; source %q >/dev/null 2>&1; pkg=%q.$(printf "%%s" "{}"); get_pkg_preview_text "$pkg"' \
    "$ROOT" "$ROOT/lib/utils.sh" "$attrset"
}

_entry_should_prompt_as_attrset() {
  local entry="$1"

  index_has_children "$entry" && return 0
  [[ "$(get_pkg_type "$entry")" == "attrset" ]]
}

_collect_attrset_recursive_for_query() {
  local attrset="$1"
  local depth="${2:-0}"
  local -n out_ref=$3
  local out_ref_name="${!out_ref}"
  local children="" child="" full=""

  if [[ "$depth" -gt 5 ]]; then
    show_warning "Max recursion depth reached for $attrset"
    return 1
  fi

  children="$(list_attrset_children "$attrset")" || true
  [[ -z "$children" ]] && return 1

  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    full="$attrset.$child"
    if _entry_should_prompt_as_attrset "$full"; then
      _collect_attrset_recursive_for_query "$full" $(( depth + 1 )) "$out_ref_name" || true
    elif [[ "$(get_pkg_type "$full")" == "package" ]]; then
      out_ref["$full"]=1
    fi
  done <<< "$children"

  return 0
}

_resolve_attrset_for_query() {
  local attrset="$1"
  local -n out_ref=$2
  local out_ref_name="${!out_ref}"
  local pkg_count="" raw_choice="" first_char="" child="" full="" child_type=""
  local selected=""
  local -a resolved=()

  pkg_count="$(count_attrset_packages "$attrset")"

  show_section "Attribute Set: $attrset"
  echo "  Your selection is a non-package attribute set ($pkg_count packages)."
  echo
  printf '  %s\n' "  Y - Select closest one by name"
  printf '  %s\n' "  W - Select all the associated packages"
  printf '  %s\n' "  N - Skip this attribute set"
  printf '  %s\n' "  M - Manually select from the associated packages"
  printf '  %s\n' "  A - Recursively resolve and select ALL associated packages"
  echo

  read -r -p "  [y/w/N/m/a]: " raw_choice || true
  nixorcist_trace_selection "query.attrset.resolve.$attrset" "$raw_choice"
  first_char="${raw_choice,,}"
  first_char="${first_char:0:1}"
  [[ -z "$first_char" ]] && first_char="n"

  case "$first_char" in
    y)
      if resolve_entry_to_packages "$attrset" resolved && [[ ${#resolved[@]} -gt 0 ]]; then
        out_ref["${resolved[0]}"]=1
        show_item "✓" "Selected closest: ${resolved[0]}"
        return 0
      fi
      show_error "No packages found in $attrset"
      return 1
      ;;
    w)
      if resolve_entry_to_packages "$attrset" resolved && [[ ${#resolved[@]} -gt 0 ]]; then
        local pkg=""
        for pkg in "${resolved[@]}"; do
          out_ref["$pkg"]=1
        done
        show_item "✓" "Selected all ${#resolved[@]} packages from $attrset"
        return 0
      fi
      show_error "No packages found in $attrset"
      return 1
      ;;
    m)
      selected=$(list_attrset_children "$attrset" | sort -u | fzf --multi \
        --prompt="SELECT FROM $attrset > " \
        --header="TAB=multi-select | ENTER=confirm | ESC=cancel" \
        --preview "$(_fzf_attrset_child_preview_cmd "$attrset")") || true

      if [[ -z "$selected" ]]; then
        show_item "⊘" "Selection cancelled"
        return 1
      fi

      while IFS= read -r child; do
        [[ -z "$child" ]] && continue
        full="$attrset.$child"
        if _entry_should_prompt_as_attrset "$full"; then
          _resolve_attrset_for_query "$full" "$out_ref_name" || true
          continue
        fi

        child_type="$(get_pkg_type "$full")"
        if [[ "$child_type" == "package" ]]; then
          out_ref["$full"]=1
        else
          show_warning "Could not resolve: $full"
        fi
      done <<< "$selected"
      return 0
      ;;
    a)
      if _collect_attrset_recursive_for_query "$attrset" 0 "$out_ref_name" && [[ ${#out_ref[@]} -gt 0 ]]; then
        show_item "✓" "Recursively selected packages under $attrset"
        return 0
      fi
      show_error "No packages found in $attrset"
      return 1
      ;;
    *)
      show_item "⊘" "Skipped: $attrset"
      return 1
      ;;
  esac
}

transaction_resolve_token_for_query() {
  local token="$1"
  local -n out_ref=$2
  local out_ref_name="${!out_ref}"

  token="$(sanitize_token "$token")"
  [[ -z "$token" ]] && return 1

  if _entry_should_prompt_as_attrset "$token"; then
    _resolve_attrset_for_query "$token" "$out_ref_name"
    return $?
  fi

  out_ref["$token"]=1
  return 0
}

transaction_stage_query() {
  local item
  local had_error=0

  TX_ADD=()
  TX_REMOVE=()

  for item in "${!TX_QUERY_ADD[@]}"; do
    transaction_expand_and_stage add "$item" || had_error=1
  done

  for item in "${!TX_QUERY_REMOVE[@]}"; do
    transaction_expand_and_stage remove "$item" || had_error=1
  done

  if [[ $had_error -ne 0 ]]; then
    show_warning 'Some query items could not be resolved. Review preview before applying.'
  fi
}

transaction_preview_query() {
  local total_add=${#TX_QUERY_ADD[@]}
  local total_remove=${#TX_QUERY_REMOVE[@]}

  printf '  Query Summary\n'
  show_divider
  printf '  Add Query:    %d item(s)\n' "$total_add"
  if [[ $total_add -gt 0 ]]; then
    printf '%s\n' "${!TX_QUERY_ADD[@]}" | sort -u | head -20 | while IFS= read -r item; do
      printf '    + %s\n' "$item"
    done
    [[ $total_add -gt 20 ]] && printf '    ... and %d more\n' $((total_add - 20))
  fi
  echo
  printf '  Remove Query: %d item(s)\n' "$total_remove"
  if [[ $total_remove -gt 0 ]]; then
    printf '%s\n' "${!TX_QUERY_REMOVE[@]}" | sort -u | head -20 | while IFS= read -r item; do
      printf '    - %s\n' "$item"
    done
    [[ $total_remove -gt 20 ]] && printf '    ... and %d more\n' $((total_remove - 20))
  fi
  echo
}

transaction_preview() {
  local total_add=${#TX_ADD[@]}
  local total_remove=${#TX_REMOVE[@]}

  printf '  Resolved Package Staging\n'
  show_divider
  printf '  To Install: %d package(s)\n' "$total_add"
  if [[ $total_add -gt 0 ]]; then
    printf '%s\n' "${!TX_ADD[@]}" | sort -u | head -40 | while IFS= read -r item; do
      printf '    + %s\n' "$item"
    done
    [[ $total_add -gt 40 ]] && printf '    ... and %d more\n' $((total_add - 40))
  fi
  echo
  printf '  To Remove:  %d package(s)\n' "$total_remove"
  if [[ $total_remove -gt 0 ]]; then
    printf '%s\n' "${!TX_REMOVE[@]}" | sort -u | head -40 | while IFS= read -r item; do
      printf '    - %s\n' "$item"
    done
    [[ $total_remove -gt 40 ]] && printf '    ... and %d more\n' $((total_remove - 40))
  fi
  echo
}

transaction_cleanup() {
  [[ -n "${TX_FILE:-}" && -f "$TX_FILE" ]] && rm -f "$TX_FILE"
}

transaction_expand_and_stage() {
  local mode="$1"
  local entry="$2"
  local -a resolved=()
  local pkg

  entry="$(sanitize_token "$entry")"
  if ! is_valid_token "$entry"; then
    show_error "Invalid token: $entry"
    return 1
  fi

  # Check if it's an attrset and handle special menu
  local entry_type="$(get_pkg_type "$entry")"
  if [[ "$entry_type" == "attrset" ]]; then
    transaction_handle_attrset "$mode" "$entry"
    return $?
  fi

  if ! resolve_entry_to_packages "$entry" resolved; then
    if [[ "$mode" == "remove" ]]; then
      # Removals should not depend on nixpkgs resolution. If a token exists
      # in lock but is no longer resolvable, still remove it by raw key.
      TX_REMOVE["$entry"]=1
      unset TX_ADD["$entry"] 2>/dev/null || true
      show_item "-" "Staged raw removal: $entry"
      nixorcist_trace "REMOVE_FALLBACK" "raw_token=$entry"
      return 0
    fi
    show_error "Skipping empty/invalid: $entry"
    return 1
  fi

  for pkg in "${resolved[@]}"; do
    if [[ "$mode" == "add" ]]; then
      TX_ADD["$pkg"]=1
      unset TX_REMOVE["$pkg"] 2>/dev/null || true
    else
      TX_REMOVE["$pkg"]=1
      unset TX_ADD["$pkg"] 2>/dev/null || true
    fi
  done

  if [[ "$mode" == "add" ]]; then
    show_item "+" "Staged: $entry [${#resolved[@]} package(s)]"
  else
    show_item "-" "Staged: $entry [${#resolved[@]} package(s)]"
  fi
  return 0
}

transaction_handle_attrset() {
  local mode="$1"
  local attrset="$2"
  local pkg_count
  pkg_count="$(count_attrset_packages "$attrset")"

  show_section "Attribute Set: $attrset"
  echo "  Your selection is a non-package attribute set ($pkg_count packages)."
  echo
  printf '  %s\n' "  Y - Select closest match by name"
  printf '  %s\n' "  W - Select all associated packages"
  printf '  %s\n' "  N - Skip this attribute set  (default)"
  printf '  %s\n' "  M - Manually select from associated packages"
  printf '  %s\n' "  A - Recursively select ALL associated packages"
  echo

  local raw_choice first_char
  read -r -p "  [y/w/N/m/a]: " raw_choice || true
  nixorcist_trace_selection "attrset.resolve.$attrset" "$raw_choice"
  first_char="${raw_choice,,}"
  first_char="${first_char:0:1}"
  [[ -z "$first_char" ]] && first_char="n"

  case "$first_char" in
    y) _attrset_select_closest "$mode" "$attrset" ;;
    w) _attrset_select_all     "$mode" "$attrset" ;;
    m) _attrset_select_manual  "$mode" "$attrset" ;;
    a) _attrset_select_recursive "$mode" "$attrset" 0 ;;
    *)
      show_item "⊘" "Skipped: $attrset"
      return 1
      ;;
  esac
}

# ---------- attrset resolution helpers ----------

# Stage a single package token into TX_ADD or TX_REMOVE.
_attrset_stage_pkg() {
  local mode="$1" pkg="$2"
  if [[ "$mode" == "add" ]]; then
    TX_ADD["$pkg"]=1
    unset "TX_REMOVE[$pkg]" 2>/dev/null || true
  else
    TX_REMOVE["$pkg"]=1
    unset "TX_ADD[$pkg]" 2>/dev/null || true
  fi
}

# Y — pick the first / closest-named package from the attrset.
_attrset_select_closest() {
  local mode="$1" attrset="$2"
  local -a resolved=()
  if resolve_entry_to_packages "$attrset" resolved && [[ ${#resolved[@]} -gt 0 ]]; then
    _attrset_stage_pkg "$mode" "${resolved[0]}"
    show_item "✓" "Selected closest: ${resolved[0]}"
    return 0
  fi
  show_error "No packages found in $attrset"
  return 1
}

# W — stage every package directly under the attrset (one level only).
_attrset_select_all() {
  local mode="$1" attrset="$2"
  local -a resolved=()
  if resolve_entry_to_packages "$attrset" resolved && [[ ${#resolved[@]} -gt 0 ]]; then
    local pkg
    for pkg in "${resolved[@]}"; do
      _attrset_stage_pkg "$mode" "$pkg"
    done
    show_item "✓" "Selected all ${#resolved[@]} packages from $attrset"
    return 0
  fi
  show_error "No packages found in $attrset"
  return 1
}

# M — fzf multi-select; sub-attrsets trigger another prompt recursively.
_attrset_select_manual() {
  local mode="$1" attrset="$2"
  local selected child full child_type

  selected=$(list_attrset_children "$attrset" | sort -u | fzf --multi \
    --prompt="SELECT FROM $attrset > " \
    --header="TAB=multi-select | ENTER=confirm | ESC=cancel" \
    --preview "$(_fzf_attrset_child_preview_cmd "$attrset")") || true

  if [[ -z "$selected" ]]; then
    show_item "⊘" "Selection cancelled"
    return 1
  fi

  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    full="$attrset.$child"
    child_type=$(get_pkg_type "$full")
    case "$child_type" in
      package)
        _attrset_stage_pkg "$mode" "$full"
        ;;
      attrset)
        # Recurse: the sub-attrset itself triggers a new resolution prompt.
        transaction_handle_attrset "$mode" "$full"
        ;;
      *)
        show_warning "Could not resolve: $full"
        ;;
    esac
  done <<< "$selected"
  return 0
}

# A — recursively stage EVERY leaf package under attrset (depth-limited).
_attrset_select_recursive() {
  local mode="$1" attrset="$2" depth="${3:-0}"
  local children child full child_type count=0

  if [[ "$depth" -gt 5 ]]; then
    show_warning "Max recursion depth reached for $attrset — stopping"
    return 1
  fi

  children=$(list_attrset_children "$attrset") || true
  if [[ -z "$children" ]]; then
    show_warning "No children found in $attrset"
    return 1
  fi

  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    full="$attrset.$child"
    child_type=$(get_pkg_type "$full")
    case "$child_type" in
      package)
        _attrset_stage_pkg "$mode" "$full"
        (( count++ )) || true
        ;;
      attrset)
        _attrset_select_recursive "$mode" "$full" $(( depth + 1 ))
        ;;
    esac
  done <<< "$children"

  show_item "✓" "Recursively selected $count package(s) under $attrset"
  return 0
}

transaction_pick_from_index() {
  ensure_index || return 1
  local index_file="" key="" query="" owner="" needle="" choice=""
  local fzf_out="" row=""
  local owner_menu_out="" approval_choice=""
  local -a out_lines selected_pkgs owner_candidates
  local -A owner_marks=()
  local -A owner_selected=()
  local owner_action_token="__OWNER_SEARCH__"

  index_file="$(get_index_file)"
  [[ -f "$index_file" ]] || {
    show_error 'Package index is unavailable.'
    return 1
  }

  _find_owner_candidates_for_query() {
    local query_text="${1:-}"
    awk -F'|' -v q="$query_text" '
      BEGIN { ql = tolower(q) }
      {
        p = $1
        pl = tolower(p)
        if (ql == "" || pl == ql || index(pl, ql) == 0) {
          next
        }

        split(p, parts, ".")
        if (length(parts) < 2) next

        owner = parts[1]
        for (i = 2; i < length(parts); i++) {
          owner = owner "." parts[i]
        }

        if (owner == "" || owner == q || seen[owner]++) next

        score = index(pl, ql) == 1 ? 0 : 1
        printf "%d|%08d|%s\n", score, length(owner), owner
      }
    ' "$index_file" | sort -t'|' -k1,1n -k2,2n -k3,3 | cut -d'|' -f3
  }

  _render_index_rows() {
    local pkg="" mark="" selected_mark=""
    printf '%s\t%s\n' "$owner_action_token" 'OWNER SEARCH FROM CURRENT QUERY'
    awk -F'|' '{print $1}' "$index_file" | sed '/^[[:space:]]*$/d' | sort -u \
      | while IFS= read -r pkg; do
          [[ -z "$pkg" ]] && continue
          mark="${owner_marks[$pkg]:-}"
          selected_mark=""
          [[ -n "${owner_selected[$pkg]:-}" ]] && selected_mark=" [SELECTED]"
          if [[ -n "$mark" ]]; then
            printf '%s\t%s%s \033[36m<=== OWNER OF THE SEARCHED PACKAGE %s\033[0m\n' "$pkg" "$pkg" "$selected_mark" "$mark"
          else
            printf '%s\t%s%s\n' "$pkg" "$pkg" "$selected_mark"
          fi
        done
  }

  while true; do
    fzf_out="$(_render_index_rows | fzf --ansi --multi \
      --expect=enter,ctrl-o \
      --print-query \
      --delimiter=$'\t' \
      --with-nth=2 \
      --prompt="SELECT> " \
      --header="TAB mark | ENTER confirm | ctrl-o or OWNER SEARCH row for owner menu" \
      --preview "$(_fzf_pkg_preview_cmd)" \
      --preview-window=down:6:wrap)" || return 1

    mapfile -t out_lines <<< "$fzf_out"
    key="${out_lines[0]:-}"
    query="${out_lines[1]:-}"
    selected_pkgs=()

    local i
    for (( i=2; i<${#out_lines[@]}; i++ )); do
      row="${out_lines[$i]}"
      [[ -z "$row" ]] && continue
      selected_pkgs+=("$(printf '%s\n' "$row" | cut -f1)")
    done

    if printf '%s\n' "${selected_pkgs[@]}" | grep -qx "$owner_action_token"; then
      key="OWNER_ACTION"
      selected_pkgs=()
    fi

    if [[ "$key" == "enter" && ${#selected_pkgs[@]} -eq 0 ]]; then
      needle="$(sanitize_token "$query")"
      if [[ -n "$needle" ]] && (index_has_exact_attr "$needle" || index_has_children "$needle" || is_valid_token "$needle"); then
        printf '%s\n' "$needle"
        return 0
      fi
    fi

    if [[ "$key" == "ctrl-o" || "$key" == "OWNER_ACTION" ]]; then
      needle="$(sanitize_token "$query")"
      if [[ -z "$needle" && ${#selected_pkgs[@]} -gt 0 ]]; then
        needle="${selected_pkgs[0]}"
      fi

      if [[ -z "$needle" ]]; then
        show_warning "Type something in the query field first, then press ctrl-o or pick OWNER SEARCH row."
        continue
      fi

      mapfile -t owner_candidates < <(_find_owner_candidates_for_query "$needle")
      if [[ ${#owner_candidates[@]} -eq 0 ]]; then
        echo
        show_warning "No owner package found for: $needle"
        printf '  Press ENTER to continue...'
        read -r
        continue
      fi

      owner_menu_out="$(printf '%s\n' "${owner_candidates[@]}" | sort -u | fzf --ansi --no-multi --expect=enter \
        --prompt="OWNER SEARCH> " \
        --header="Select owner for: $needle" \
        --preview "$(_fzf_pkg_preview_cmd)" \
        --preview-window=down:6:wrap --height=14 --layout=reverse --border)" || true

      mapfile -t out_lines <<< "$owner_menu_out"
      if [[ "${out_lines[0]:-}" != "enter" || -z "${out_lines[1]:-}" ]]; then
        continue
      fi

      owner="${out_lines[1]}"

      # Always annotate owner in menu A so user understands mapping,
      # even if they decline auto-selecting it.
      owner_marks["$owner"]="$needle"

      owner_menu_out="$(
        printf 'No - keep selection unchanged\nYes - add owner package\n' \
          | fzf --ansi --no-multi --expect=enter \
            --prompt="OWNER APPROVAL> " \
            --header="Owner found: $owner for query: $needle (default: No)" \
            --preview-window=hidden --height=10 --layout=reverse --border
      )" || true

      mapfile -t out_lines <<< "$owner_menu_out"
      approval_choice="${out_lines[1]:-}"
      if [[ "${out_lines[0]:-}" == "enter" && "$approval_choice" == Yes* ]]; then
        owner_selected["$owner"]=1
      fi
      continue
    fi

    if [[ ${#owner_selected[@]} -gt 0 ]]; then
      local selected_owner=""
      for selected_owner in "${!owner_selected[@]}"; do
        selected_pkgs+=("$selected_owner")
      done
    fi

    printf '%s\n' "${selected_pkgs[@]}" | sed '/^[[:space:]]*$/d' | sort -u
    return 0
  done
}

transaction_pick_for_remove() {
  {
    printf '%s\n' "${!TX_LOCK[@]}"
    printf '%s\n' "${!TX_ADD[@]}"
  } | sed '/^[[:space:]]*$/d' | sort -u \
    | fzf --multi \
      --prompt="REMOVE> " \
      --header="TAB mark | ENTER confirm" \
      --preview "$(_fzf_pkg_preview_cmd)" \
      --preview-window=down:4:wrap
}

transaction_unstage_menu() {
  local mode="$1"
  local scope="${2:-staged}"
  local selected
  local -n bucket_ref

  if [[ "$mode" == "add" ]]; then
    if [[ "$scope" == "query" ]]; then
      bucket_ref=TX_QUERY_ADD
    else
      bucket_ref=TX_ADD
    fi
  else
    if [[ "$scope" == "query" ]]; then
      bucket_ref=TX_QUERY_REMOVE
    else
      bucket_ref=TX_REMOVE
    fi
  fi

  if [[ "$mode" == "add" ]]; then
    [[ ${#bucket_ref[@]} -eq 0 ]] && { show_info "No items in add queue."; return; }
    selected=$(printf '%s\n' "${!bucket_ref[@]}" | sort -u | fzf --multi --prompt="UNSTAGE > ")
    [[ -z "$selected" ]] && return
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      unset bucket_ref["$pkg"]
    done <<< "$selected"
  else
    [[ ${#bucket_ref[@]} -eq 0 ]] && { show_info "No items in remove queue."; return; }
    selected=$(printf '%s\n' "${!bucket_ref[@]}" | sort -u | fzf --multi --prompt="UNSTAGE > ")
    [[ -z "$selected" ]] && return
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      unset bucket_ref["$pkg"]
    done <<< "$selected"
  fi
}

transaction_submenu_install_queue() {
  local use_query=1
  if ! transaction_has_query && [[ ${#TX_ADD[@]} -gt 0 || ${#TX_REMOVE[@]} -gt 0 ]]; then
    use_query=0
  fi

  while true; do
    clear
    show_logo
    show_section_header 'Manage Install Queue'
    
    if [[ $use_query -eq 1 && ${#TX_QUERY_ADD[@]} -eq 0 ]]; then
      printf '  (empty)\n'
    elif [[ $use_query -eq 0 && ${#TX_ADD[@]} -eq 0 ]]; then
      printf '  (empty)\n'
    else
      if [[ $use_query -eq 1 ]]; then
        printf '  Draft install query:\n\n'
        printf '%s\n' "${!TX_QUERY_ADD[@]}" | sort -u | nl | while read -r num pkg; do
          printf '    %2d. %s\n' "$num" "$pkg"
        done | head -20
        local total=${#TX_QUERY_ADD[@]}
      else
        printf '  Staged for installation:\n\n'
        printf '%s\n' "${!TX_ADD[@]}" | sort -u | nl | while read -r num pkg; do
          printf '    %2d. %s\n' "$num" "$pkg"
        done | head -20
        local total=${#TX_ADD[@]}
      fi
      if [[ $total -gt 20 ]]; then
        printf '\n    ... and %d more\n' $((total - 20))
      fi
    fi
    
    echo
    show_menu_item '1' 'Remove from queue    - select items to unstage'
    show_menu_item '2' 'Clear all            - empty the install queue'
    show_menu_item '0' 'Back'
    echo
    
    printf '  Select an option (0-2): '
    read -r choice
    nixorcist_trace_selection "install_queue.choice" "$choice"
    
    case "$choice" in
      1)
        if [[ $use_query -eq 1 ]]; then
          if [[ ${#TX_QUERY_ADD[@]} -eq 0 ]]; then
            show_error 'Install queue is empty'
            wait_for_key
          else
            transaction_unstage_menu add query
          fi
        else
          if [[ ${#TX_ADD[@]} -eq 0 ]]; then
            show_error 'Install queue is empty'
            wait_for_key
          else
            transaction_unstage_menu add staged
          fi
        fi
        ;;
      2)
        if [[ $use_query -eq 1 ]]; then
          if [[ ${#TX_QUERY_ADD[@]} -eq 0 ]]; then
            show_error 'Install queue is empty'
            wait_for_key
          else
            show_warning 'This will clear all query installs.'
            show_yes_no_prompt 'Continue?'
            read -r confirm
            nixorcist_trace_selection "install_queue.clear_query.confirm" "$confirm"
            if [[ "${confirm,,}" == "y" ]]; then
              TX_QUERY_ADD=()
              show_success 'Install query cleared'
              sleep 1
            fi
          fi
        else
          if [[ ${#TX_ADD[@]} -eq 0 ]]; then
            show_error 'Install queue is empty'
            wait_for_key
          else
            show_warning 'This will clear all staged installs.'
            show_yes_no_prompt 'Continue?'
            read -r confirm
            nixorcist_trace_selection "install_queue.clear_staged.confirm" "$confirm"
            if [[ "${confirm,,}" == "y" ]]; then
              TX_ADD=()
              show_success 'Install queue cleared'
              sleep 1
            fi
          fi
        fi
        ;;
      0) break ;;
      *)
        show_error 'Invalid option.'
        wait_for_key
        ;;
    esac
  done
}

transaction_submenu_remove_queue() {
  local use_query=1
  if ! transaction_has_query && [[ ${#TX_ADD[@]} -gt 0 || ${#TX_REMOVE[@]} -gt 0 ]]; then
    use_query=0
  fi

  while true; do
    clear
    show_logo
    show_section_header 'Manage Remove Queue'
    
    if [[ $use_query -eq 1 && ${#TX_QUERY_REMOVE[@]} -eq 0 ]]; then
      printf '  (empty)\n'
    elif [[ $use_query -eq 0 && ${#TX_REMOVE[@]} -eq 0 ]]; then
      printf '  (empty)\n'
    else
      if [[ $use_query -eq 1 ]]; then
        printf '  Draft remove query:\n\n'
        printf '%s\n' "${!TX_QUERY_REMOVE[@]}" | sort -u | nl | while read -r num pkg; do
          printf '    %2d. %s\n' "$num" "$pkg"
        done | head -20
        local total=${#TX_QUERY_REMOVE[@]}
      else
        printf '  Staged for removal:\n\n'
        printf '%s\n' "${!TX_REMOVE[@]}" | sort -u | nl | while read -r num pkg; do
        printf '    %2d. %s\n' "$num" "$pkg"
      done | head -20
        local total=${#TX_REMOVE[@]}
      fi
      if [[ $total -gt 20 ]]; then
        printf '\n    ... and %d more\n' $((total - 20))
      fi
    fi
    
    echo
    show_menu_item '1' 'Remove from queue    - select items to unstage'
    show_menu_item '2' 'Clear all            - empty the remove queue'
    show_menu_item '0' 'Back'
    echo
    
    printf '  Select an option (0-2): '
    read -r choice
    nixorcist_trace_selection "remove_queue.choice" "$choice"
    
    case "$choice" in
      1)
        if [[ $use_query -eq 1 ]]; then
          if [[ ${#TX_QUERY_REMOVE[@]} -eq 0 ]]; then
            show_error 'Remove queue is empty'
            wait_for_key
          else
            transaction_unstage_menu remove query
          fi
        else
          if [[ ${#TX_REMOVE[@]} -eq 0 ]]; then
            show_error 'Remove queue is empty'
            wait_for_key
          else
            transaction_unstage_menu remove staged
          fi
        fi
        ;;
      2)
        if [[ $use_query -eq 1 ]]; then
          if [[ ${#TX_QUERY_REMOVE[@]} -eq 0 ]]; then
            show_error 'Remove queue is empty'
            wait_for_key
          else
            show_warning 'This will clear all query removals.'
            show_yes_no_prompt 'Continue?'
            read -r confirm
            nixorcist_trace_selection "remove_queue.clear_query.confirm" "$confirm"
            if [[ "${confirm,,}" == "y" ]]; then
              TX_QUERY_REMOVE=()
              show_success 'Remove query cleared'
              sleep 1
            fi
          fi
        else
          if [[ ${#TX_REMOVE[@]} -eq 0 ]]; then
            show_error 'Remove queue is empty'
            wait_for_key
          else
            show_warning 'This will clear all staged removals.'
            show_yes_no_prompt 'Continue?'
            read -r confirm
            nixorcist_trace_selection "remove_queue.clear_staged.confirm" "$confirm"
            if [[ "${confirm,,}" == "y" ]]; then
              TX_REMOVE=()
              show_success 'Remove queue cleared'
              sleep 1
            fi
          fi
        fi
        ;;
      0) break ;;
      *)
        show_error 'Invalid option.'
        wait_for_key
        ;;
    esac
  done
}
show_transaction_header() {
  show_section_header 'Transaction Builder'
  if transaction_has_query; then
    printf '  %-45s %s\n' "Query Install Items:" "${#TX_QUERY_ADD[@]} item(s)"
    printf '  %-45s %s\n' "Query Remove Items:" "${#TX_QUERY_REMOVE[@]} item(s)"
  else
    printf '  %-45s %s\n' "Queued to Install:" "${#TX_ADD[@]} package(s)"
    printf '  %-45s %s\n' "Queued to Remove:" "${#TX_REMOVE[@]} package(s)"
  fi
  echo
  show_divider
  echo
}

prompt_index_fetch_depth() {
  local depth_input=""
  local fetch_depth="5"

  while true; do
    printf '  Enter fetch depth [1-5] (default 5, q to cancel): '
    read -r depth_input || true
    depth_input="${depth_input//[[:space:]]/}"
    depth_input="${depth_input,,}"

    if [[ -z "$depth_input" ]]; then
      printf '%s\n' "5"
      return 0
    fi

    if [[ "$depth_input" == "q" ]]; then
      return 1
    fi

    if [[ "$depth_input" =~ ^[1-5]$ ]]; then
      fetch_depth="$depth_input"
      printf '%s\n' "$fetch_depth"
      return 0
    fi

    show_error 'Invalid depth. Use 1, 2, 3, 4, or 5.'
  done
}

transaction_menu_loop_tty() {
  local choice
  local selected item

  while true; do
    clear
    show_logo
    show_refresh_countdown_bar
    show_transaction_header
    show_status_line "Use numbers and Enter to navigate."
    echo
    show_menu_item '1' 'Add packages        - add items to install query'
    show_menu_item '2' 'Remove packages     - add items to remove query'
    show_menu_item '3' 'Manage install queue'
    show_menu_item '4' 'Manage remove queue'
    show_menu_item '5' 'Preview changes'
    show_menu_item '6' 'Install query       - stage query and apply lock changes'
    show_menu_item '7' 'Fetch index         - choose depth (1-5) and store cache'
    show_menu_item '0' 'Cancel'
    echo
    show_input_prompt 'Select an option (0-7):'
    read -r choice
    nixorcist_trace_selection "transaction_menu.choice" "$choice"
    
    case "$choice" in
      1)
        selected="$(transaction_pick_from_index || true)"
        [[ -z "$selected" ]] && continue
        local -A resolved_add_tokens=()
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_resolve_token_for_query "$item" resolved_add_tokens || true
        done <<< "$selected"
        [[ ${#resolved_add_tokens[@]} -eq 0 ]] && continue
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_add_to_query add "$item" || true
        done < <(printf '%s\n' "${!resolved_add_tokens[@]}" | sort -u)
        show_success 'Added to install query'
        sleep 1
        ;;
      2)
        selected="$(transaction_pick_for_remove || true)"
        [[ -z "$selected" ]] && continue
        local -A resolved_remove_tokens=()
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_resolve_token_for_query "$item" resolved_remove_tokens || true
        done <<< "$selected"
        [[ ${#resolved_remove_tokens[@]} -eq 0 ]] && continue
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_add_to_query remove "$item" || true
        done < <(printf '%s\n' "${!resolved_remove_tokens[@]}" | sort -u)
        show_success 'Added to remove query'
        sleep 1
        ;;
      3)
        transaction_submenu_install_queue
        ;;
      4)
        transaction_submenu_remove_queue
        ;;
      5)
        clear
        show_logo
        show_section_header 'Transaction Preview'
        echo
        if transaction_has_query; then
          transaction_preview_query
        else
          transaction_preview
        fi
        wait_for_key
        ;;
      6)
        clear
        show_logo
        show_section_header 'Install Query'
        if transaction_has_query; then
          show_warning 'This will resolve your query, stage packages, and update the lock file.'
        else
          show_warning 'This will update the lock file with staged changes.'
        fi
        show_yes_no_prompt 'Continue?'
        read -r confirm
        nixorcist_trace_selection "transaction_menu.install_query.confirm" "$confirm"
        if [[ "${confirm,,}" == "y" ]]; then
          if transaction_has_query; then
            transaction_stage_query
          fi
          transaction_apply
          return 0
        fi
        ;;
      7)
        local selected_depth=""

        clear
        show_logo
        show_refresh_countdown_bar
        show_section_header 'Fetch Package Index'
        selected_depth="$(prompt_index_fetch_depth || true)"
        if [[ -z "$selected_depth" ]]; then
          show_warning 'Fetch cancelled'
          wait_for_key
          continue
        fi

        clear
        show_logo
        show_refresh_countdown_bar
        show_section_header "Fetching Package Index (depth ${selected_depth})"
        if build_nix_index "$selected_depth"; then
          show_success 'Package index fetched and cached'
        else
          local fetch_rc=$?
          if [[ "$fetch_rc" -eq 130 ]]; then
            show_warning 'Package index fetch cancelled by user'
          else
            show_error 'Package index fetch failed'
          fi
        fi
        wait_for_key
        ;;
      0)
        clear
        show_warning 'Transaction cancelled'
        sleep 1
        return 1
        ;;
      *)
        show_error 'Invalid option.'
        wait_for_key
        ;;
    esac
  done
}

transaction_write_temp() {
  {
    echo "# ADD"
    printf '%s\n' "${!TX_ADD[@]}" | sed '/^[[:space:]]*$/d' | sort -u
    echo "# REMOVE"
    printf '%s\n' "${!TX_REMOVE[@]}" | sed '/^[[:space:]]*$/d' | sort -u
  } > "$TX_FILE"
}

transaction_apply() {
  local -A next=()
  local pkg

  nixorcist_trace "APPLY" "begin add=${#TX_ADD[@]} remove=${#TX_REMOVE[@]} lock=${#TX_LOCK[@]}"

  # Start with current lock entries
  for pkg in "${!TX_LOCK[@]}"; do
    next["$pkg"]=1
  done

  # Add new packages
  for pkg in "${!TX_ADD[@]}"; do
    next["$pkg"]=1
  done

  # Remove packages (AFTER additions to handle conflicts properly)
  for pkg in "${!TX_REMOVE[@]}"; do
    unset next["$pkg"]
  done

  local final=()
  for pkg in "${!next[@]}"; do
    final+=("$pkg")
  done

  if [[ ${#final[@]} -gt 0 ]]; then
    nixorcist_trace "APPLY_FINAL_ITEMS" "$(printf '%s,' "${final[@]}" | sed 's/,$//')"
  else
    nixorcist_trace "APPLY_FINAL_ITEMS" "<empty>"
  fi

  write_lock_entries final
  nixorcist_trace "APPLY" "final_count=${#final[@]}"
  transaction_write_temp
  show_success "Lock updated - Changes will be applied on rebuild"
}

transaction_menu_loop() {
  transaction_menu_loop_tty
}

run_transaction_cli() {
  transaction_init
  if transaction_menu_loop; then
    transaction_cleanup
    return 0
  fi
  transaction_cleanup
  return 1
}

select_packages() {
  run_transaction_cli
}

add_packages() {
  run_transaction_cli
}

remove_packages() {
  run_transaction_cli
}

handle_missing_package() {
  local missing="$1"
  local mode="${2:-add}"
  local index_file similar_pkgs count
  index_file="$(get_index_file)"

  ensure_index

  # Build a ranked candidate list
  similar_pkgs="$(find_similar_packages "$missing")"

  echo
  show_section "Package not found: '$missing'"

  if [[ -z "$similar_pkgs" ]]; then
    show_info "No close matches found in the index."
    echo
    printf '  Enter an exact package name to use instead, or press Enter to skip:\n'
    local manual
    read -r manual
    [[ -z "$manual" ]] && { show_item "⊘" "Skipped: $missing"; return 0; }
    local suggested
    suggested="$(sanitize_token "$manual")"
    if [[ -n "$suggested" ]]; then
      if [[ "$mode" == "add" ]]; then
        TX_ADD["$suggested"]=1; unset "TX_REMOVE[$suggested]" 2>/dev/null || true
      else
        TX_REMOVE["$suggested"]=1; unset "TX_ADD[$suggested]" 2>/dev/null || true
      fi
      show_item "✓" "Added: $suggested"
    fi
    return 0
  fi

  # Show ranked candidates with descriptions
  count="$(printf '%s\n' "$similar_pkgs" | wc -l)"
  printf '  Closest matches (%d):\n\n' "$count"

  local i=1 pkg desc
  while IFS= read -r pkg; do
    desc="$(awk -F'|' -v p="$pkg" '$1==p{sub(/^[^|]*\|/,""); print; exit}' "$index_file" 2>/dev/null)"
    desc="${desc:-(no description)}"
    desc="${desc:0:55}"
    printf '    %2d) %-36s  %s\n' "$i" "$pkg" "$desc"
    (( i++ ))
  done <<< "$similar_pkgs"

  echo
  printf '     0) Skip\n'
  printf '     b) Browse all packages in fzf\n'
  echo

  local choice chosen
  while true; do
    read -rp "  Select [0-${count}/b]: " choice
    nixorcist_trace_selection "missing_package.choice.$missing" "$choice"

    if [[ "$choice" == "0" ]]; then
      show_item "⊘" "Skipped: $missing"
      return 0
    fi

    if [[ "${choice,,}" == "b" ]]; then
      chosen="$(awk -F'|' '{print $1}' "$index_file" | sort -u | fzf --multi \
        --prompt="BROWSE > " \
        --header="TAB=multi-select | ENTER=confirm | ESC=cancel" \
        --preview "$(_fzf_pkg_preview_cmd)" || true)"
      if [[ -n "$chosen" ]]; then
        while IFS= read -r pkg; do
          [[ -z "$pkg" ]] && continue
          if [[ "$mode" == "add" ]]; then
            TX_ADD["$pkg"]=1; unset "TX_REMOVE[$pkg]" 2>/dev/null || true
          else
            TX_REMOVE["$pkg"]=1; unset "TX_ADD[$pkg]" 2>/dev/null || true
          fi
        done <<< "$chosen"
        show_item "✓" "Selected from browse"
        return 0
      fi
      continue
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      chosen="$(printf '%s\n' "$similar_pkgs" | sed -n "${choice}p")"
      if [[ "$mode" == "add" ]]; then
        TX_ADD["$chosen"]=1; unset "TX_REMOVE[$chosen]" 2>/dev/null || true
      else
        TX_REMOVE["$chosen"]=1; unset "TX_ADD[$chosen]" 2>/dev/null || true
      fi
      show_item "✓" "Selected: $chosen"
      return 0
    fi

    show_error "Enter a number between 0 and $count, or 'b' to browse."
  done
}


# ═══════════════════════════════════════════════════════════════════════════════
# Core pipeline — the execution heart of every package change.
#
# Caller must have called transaction_init() and populated TX_ADD / TX_REMOVE.
# Order:
#   1. Delete .nix modules for TX_REMOVE  (BEFORE anything else)
#   2. Generate .nix modules for TX_ADD   (without touching lock)
#   3. Regenerate hub                     (reflects both changes atomically)
#   4. Apply lock changes                 (commit TX_ADD adds, TX_REMOVE removes)
#
# Optionally runs nixos-rebuild at the end when $1 == "--rebuild".
# ═══════════════════════════════════════════════════════════════════════════════

nixorcist_pipeline() {
  local do_rebuild=0
  [[ "${1:-}" == "--rebuild" ]] && do_rebuild=1

  local add_n=${#TX_ADD[@]} rem_n=${#TX_REMOVE[@]}

  if (( add_n == 0 && rem_n == 0 )); then
    show_info "Nothing to do — transaction is empty."
    return 0
  fi

  show_divider
  if (( rem_n > 0 )); then
    printf '  To remove (%d):\n' "$rem_n"
    printf '%s\n' "${!TX_REMOVE[@]}" | sort | while IFS= read -r p; do printf '    \033[31m- %s\033[0m\n' "$p"; done
  fi
  if (( add_n > 0 )); then
    printf '  To install (%d):\n' "$add_n"
    printf '%s\n' "${!TX_ADD[@]}" | sort | while IFS= read -r p; do printf '    \033[32m+ %s\033[0m\n' "$p"; done
  fi
  show_divider

  # ── Phase 1: Remove .nix files for packages being removed ─────────────────
  if (( rem_n > 0 )); then
    show_info "Phase 1/4: Removing modules for deleted packages"
    remove_staged_modules || true
  fi

  # ── Phase 2: Generate .nix files for packages being added ─────────────────
  if (( add_n > 0 )); then
    show_info "Phase 2/4: Generating modules for new packages"
    local pkg
    for pkg in "${!TX_ADD[@]}"; do
      generate_module_for_pkg "$pkg" || true
    done
  fi

  # ── Phase 3: Regenerate hub ───────────────────────────────────────────────
  show_info "Phase 3/4: Regenerating hub"
  regenerate_hub

  # ── Phase 4: Apply lock changes ───────────────────────────────────────────
  show_info "Phase 4/4: Updating lock file"
  transaction_apply

  show_success "Transaction applied."

  # ── Optional rebuild ──────────────────────────────────────────────────────
  if (( do_rebuild )); then
    echo
    show_info "Starting NixOS rebuild..."
    echo
    run_rebuild
  else
    echo
    show_info "Run 'nixorcist rebuild' to apply changes to the running system."
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# import_from_file — the base command; all others delegate here.
#
# File format: one package per line (or comma-separated).
# Lines may use +/- prefixes. No prefix = install.
# Asks before applying; passes --rebuild if user wants full rebuild.
# ═══════════════════════════════════════════════════════════════════════════════

import_from_file() {
  local file="$1"
  local _silent="${2:-}"   # pass "--silent" to skip the preview prompt

  if [[ -z "$file" || ! -f "$file" ]]; then
    show_error "Provide a valid text file."
    return 1
  fi

  ensure_index
  transaction_init

  local normalized token mode="add" rest segment sign
  normalized="$(tr ',\n\t ' '\n\n\n\n' < "$file")"

  while IFS= read -r -u 3 token; do
    token="$(sanitize_token "$token")"
    [[ -z "$token" ]] && continue

    rest="$token"
    while [[ -n "$rest" ]]; do
      sign="${rest:0:1}"
      if [[ "$sign" == "+" || "$sign" == "-" ]]; then
        [[ "$sign" == "+" ]] && mode="add" || mode="remove"
        rest="${rest:1}"
        continue
      fi

      if [[ "$rest" == *[+-]* ]]; then
        segment="${rest%%[+-]*}"
        rest="${rest:${#segment}}"
      else
        segment="$rest"
        rest=""
      fi

      segment="$(sanitize_token "$segment")"
      [[ -z "$segment" ]] && continue

      if [[ "$mode" == "add" ]]; then
        if ! transaction_expand_and_stage add "$segment"; then
          handle_missing_package "$segment" "add" || show_item "?" "Unresolved: $segment"
        fi
      else
        if ! transaction_expand_and_stage remove "$segment"; then
          if is_valid_token "$segment"; then
            TX_REMOVE["$segment"]=1
            unset "TX_ADD[$segment]" 2>/dev/null || true
            show_item "-" "Staged removal: $segment"
          else
            show_item "?" "Unresolved remove token: $segment"
          fi
        fi
      fi
    done
  done 3<<< "$normalized"

  if [[ "${NIXORCIST_IMPORT_AUTO:-0}" == "1" ]]; then
    nixorcist_pipeline
    transaction_cleanup
    return 0
  fi

  if [[ "$_silent" != "--silent" ]]; then
    echo
    local answer
    read -rp "  Apply transaction? [Y/n/r] (y=apply, n=cancel, r=apply+rebuild): " answer
    nixorcist_trace_selection "import.apply_confirm" "$answer"
    case "${answer,,}" in
      n) show_warning "Import cancelled."; transaction_cleanup; return 1 ;;
      r) nixorcist_pipeline --rebuild ;;
      *) nixorcist_pipeline ;;
    esac
  else
    nixorcist_pipeline
  fi

  transaction_cleanup
}

# ═══════════════════════════════════════════════════════════════════════════════
# chant_from_args — writes tokens to a temp file, delegates to import_from_file.
# install_from_args — chant with only + tokens.
# delete_from_args  — chant with only - tokens.
# ═══════════════════════════════════════════════════════════════════════════════

chant_from_args() {
  if [[ $# -eq 0 ]]; then
    show_error "chant requires at least one token (e.g. +bat -nano)"
    return 1
  fi

  local tmp
  tmp="$(mktemp /tmp/nixorcist-chant.XXXXXX)"

  local mode="add" raw token rest segment sign
  for raw in "$@"; do
    raw="${raw//,/ }"
    for token in $raw; do
      [[ -z "$token" ]] && continue
      rest="$token"

      while [[ -n "$rest" ]]; do
        sign="${rest:0:1}"
        if [[ "$sign" == "+" || "$sign" == "-" ]]; then
          [[ "$sign" == "+" ]] && mode="add" || mode="remove"
          rest="${rest:1}"
          continue
        fi

        if [[ "$rest" == *[+-]* ]]; then
          segment="${rest%%[+-]*}"
          rest="${rest:${#segment}}"
        else
          segment="$rest"
          rest=""
        fi

        segment="$(sanitize_token "$segment")"
        [[ -z "$segment" ]] && continue

        if [[ "$mode" == "add" ]]; then
          printf '+%s\n' "$segment"
        else
          printf -- '-%s\n' "$segment"
        fi
      done
    done
  done > "$tmp"

  import_from_file "$tmp"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

install_from_args() {
  if [[ $# -eq 0 ]]; then
    show_error "install requires at least one package name"
    return 1
  fi
  # Prefix all args with + and delegate to chant
  local prefixed=()
  local arg
  for arg in "$@"; do
    prefixed+=("+${arg#+}")   # strip accidental + then re-add
  done
  chant_from_args "${prefixed[@]}"
}

delete_from_args() {
  if [[ $# -eq 0 ]]; then
    show_error "delete requires at least one package name"
    return 1
  fi
  # Prefix all args with - and delegate to chant
  local prefixed=()
  local arg
  for arg in "$@"; do
    prefixed+=("-${arg#-}")   # strip accidental - then re-add
  done
  chant_from_args "${prefixed[@]}"
}
