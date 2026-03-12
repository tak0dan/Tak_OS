#!/usr/bin/env bash

INDEX_DIR="$ROOT/cache"
INDEX_FILE="$INDEX_DIR/nixpkgs-index.txt"
INDEX_VERSION="3"
INDEX_VERSION_FILE="$INDEX_DIR/nixpkgs-index.version"
INDEX_FETCH_TIME_FILE="$INDEX_DIR/index-fetch-seconds.txt"
INDEX_FETCH_PROFILE_FILE="$INDEX_DIR/index-fetch-profile.txt"
INDEX_STATUS_FILE="$INDEX_DIR/index-status.txt"
INDEX_REFRESH_ERROR_FILE="$INDEX_DIR/index-refresh-last-error.log"
INDEX_RECOMMENDED_REFRESH_SECS=$((7 * 24 * 60 * 60))

_INDEX_UI_ACTIVE=0
_INDEX_UI_LINES=7
_INDEX_EXPECTED_SECS=32
_INDEX_EXPECTED_A=8
_INDEX_EXPECTED_B=8
_INDEX_EXPECTED_C=14
_INDEX_LAST_STAGE_SECS=0

_index_valid_epoch() {
  local v="$1"
  [[ "$v" =~ ^[0-9]+$ ]] && (( v > 0 ))
}

_index_now_epoch() {
  date +%s
}

_index_read_status_value() {
  local key="$1"
  local raw=""

  [[ -f "$INDEX_STATUS_FILE" ]] || return 0
  raw="$(awk -F'=' -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$INDEX_STATUS_FILE" 2>/dev/null || true)"
  printf '%s\n' "$raw"
}

_index_file_mtime_epoch() {
  [[ -f "$INDEX_FILE" ]] || return 0
  stat -c %Y "$INDEX_FILE" 2>/dev/null || true
}

_index_write_status() {
  local fetch_epoch="$1"
  local all_epoch="$2"
  local fetch_elapsed="$3"
  local tmp_file=""

  mkdir -p "$INDEX_DIR"
  tmp_file="$(mktemp)"
  {
    printf 'last_fetch_epoch=%s\n' "$fetch_epoch"
    printf 'last_fetch_human=%s\n' "$(_index_format_epoch "$fetch_epoch")"
    printf 'last_all_epoch=%s\n' "$all_epoch"
    printf 'last_all_human=%s\n' "$(_index_format_epoch "$all_epoch")"
    printf 'last_fetch_duration_seconds=%s\n' "$fetch_elapsed"
    printf 'recommended_refresh_seconds=%s\n' "$INDEX_RECOMMENDED_REFRESH_SECS"
  } > "$tmp_file"
  mv "$tmp_file" "$INDEX_STATUS_FILE"
}

_index_format_epoch() {
  local epoch="$1"
  if ! _index_valid_epoch "$epoch"; then
    printf 'never\n'
    return
  fi
  date -d "@$epoch" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf '%s\n' "$epoch"
}

index_last_fetch_epoch() {
  local epoch=""

  epoch="$(_index_read_status_value last_fetch_epoch)"
  if _index_valid_epoch "$epoch"; then
    printf '%s\n' "$epoch"
    return
  fi

  epoch="$(_index_file_mtime_epoch)"
  if _index_valid_epoch "$epoch"; then
    printf '%s\n' "$epoch"
    return
  fi

  printf '0\n'
}

index_last_all_epoch() {
  local epoch=""
  epoch="$(_index_read_status_value last_all_epoch)"
  if _index_valid_epoch "$epoch"; then
    printf '%s\n' "$epoch"
    return
  fi
  printf '0\n'
}

index_last_fetch_text() {
  _index_format_epoch "$(index_last_fetch_epoch)"
}

index_last_all_text() {
  _index_format_epoch "$(index_last_all_epoch)"
}

index_refresh_age_seconds() {
  local now=0
  local fetch_epoch=0

  fetch_epoch="$(index_last_fetch_epoch)"
  if ! _index_valid_epoch "$fetch_epoch"; then
    printf '%s\n' '-1'
    return
  fi

  now="$(_index_now_epoch)"
  printf '%s\n' "$(( now - fetch_epoch ))"
}

index_refresh_seconds_left() {
  local age=0
  age="$(index_refresh_age_seconds)"
  if (( age < 0 )); then
    printf '%s\n' '-1'
    return
  fi
  if (( age >= INDEX_RECOMMENDED_REFRESH_SECS )); then
    printf '0\n'
    return
  fi
  printf '%s\n' "$(( INDEX_RECOMMENDED_REFRESH_SECS - age ))"
}

index_refresh_overdue_seconds() {
  local age=0
  age="$(index_refresh_age_seconds)"
  if (( age <= INDEX_RECOMMENDED_REFRESH_SECS )); then
    printf '0\n'
    return
  fi
  printf '%s\n' "$(( age - INDEX_RECOMMENDED_REFRESH_SECS ))"
}

index_refresh_remaining_percent() {
  local left=0
  left="$(index_refresh_seconds_left)"
  if (( left < 0 )); then
    printf '%s\n' '-1'
    return
  fi
  printf '%s\n' "$(( left * 100 / INDEX_RECOMMENDED_REFRESH_SECS ))"
}

index_mark_fetch_updated() {
  local fetch_epoch=0
  local all_epoch=0
  local fetch_elapsed="${1:-0}"

  fetch_epoch="$(_index_now_epoch)"
  all_epoch="$(index_last_all_epoch)"
  _index_write_status "$fetch_epoch" "$all_epoch" "$fetch_elapsed"
}

index_mark_all_executed() {
  local fetch_epoch=0
  local all_epoch=0
  local fetch_elapsed=""

  fetch_epoch="$(index_last_fetch_epoch)"
  all_epoch="$(_index_now_epoch)"
  fetch_elapsed="$(_index_read_status_value last_fetch_duration_seconds)"
  [[ "$fetch_elapsed" =~ ^[0-9]+$ ]] || fetch_elapsed=0
  _index_write_status "$fetch_epoch" "$all_epoch" "$fetch_elapsed"
}

_is_valid_fetch_seconds() {
  local v="$1"
  [[ "$v" =~ ^[0-9]+$ ]] && (( v >= 1 )) && (( v <= 900 ))
}

_index_profile_defaults_from_total() {
  local total="$1"
  _INDEX_EXPECTED_A=$(( total * 25 / 100 ))
  _INDEX_EXPECTED_B=$(( total * 25 / 100 ))
  _INDEX_EXPECTED_C=$(( total * 45 / 100 ))
  (( _INDEX_EXPECTED_A < 2 )) && _INDEX_EXPECTED_A=2
  (( _INDEX_EXPECTED_B < 2 )) && _INDEX_EXPECTED_B=2
  (( _INDEX_EXPECTED_C < 3 )) && _INDEX_EXPECTED_C=3
  return 0
}

_index_load_profile() {
  local key="" val=""
  local seen=0

  _index_profile_defaults_from_total "$_INDEX_EXPECTED_SECS"

  [[ -f "$INDEX_FETCH_PROFILE_FILE" ]] || return 0
  while IFS='=' read -r key val; do
    key="${key//[[:space:]]/}"
    val="${val//[[:space:]]/}"
    _is_valid_fetch_seconds "$val" || continue
    case "$key" in
      A) _INDEX_EXPECTED_A="$val"; seen=1 ;;
      B) _INDEX_EXPECTED_B="$val"; seen=1 ;;
      C) _INDEX_EXPECTED_C="$val"; seen=1 ;;
    esac
  done < "$INDEX_FETCH_PROFILE_FILE"

  if [[ "$seen" -eq 0 ]]; then
    _index_profile_defaults_from_total "$_INDEX_EXPECTED_SECS"
  fi

  return 0
}

_index_save_profile() {
  local a="$1"
  local b="$2"
  local c="$3"
  _is_valid_fetch_seconds "$a" || return 0
  _is_valid_fetch_seconds "$b" || return 0
  _is_valid_fetch_seconds "$c" || return 0
  {
    printf 'A=%s\n' "$a"
    printf 'B=%s\n' "$b"
    printf 'C=%s\n' "$c"
  } > "$INDEX_FETCH_PROFILE_FILE" 2>/dev/null || true
}

_index_load_expected_secs() {
  local raw=""
  if [[ -f "$INDEX_FETCH_TIME_FILE" ]]; then
    raw="$(head -n1 "$INDEX_FETCH_TIME_FILE" 2>/dev/null | tr -d '[:space:]')"
    if [[ "$raw" =~ ^[0-9]+$ ]] && (( raw >= 5 )) && (( raw <= 900 )); then
      _INDEX_EXPECTED_SECS="$raw"
      return
    fi
  fi
  _INDEX_EXPECTED_SECS=32
}

_index_save_expected_secs() {
  local seconds="$1"
  [[ "$seconds" =~ ^[0-9]+$ ]] || return 0
  (( seconds < 5 )) && return 0
  (( seconds > 900 )) && return 0
  printf '%s\n' "$seconds" > "$INDEX_FETCH_TIME_FILE" 2>/dev/null || true
}

_index_smooth_secs() {
  local old="$1"
  local measured="$2"
  if ! _is_valid_fetch_seconds "$old"; then
    echo "$measured"
    return
  fi
  if ! _is_valid_fetch_seconds "$measured"; then
    echo "$old"
    return
  fi
  echo $(( (old * 7 + measured * 3) / 10 ))
}

_index_ui_begin() {
  if [[ -t 2 ]]; then
    _INDEX_UI_ACTIVE=1
    printf '\n\n\n\n\n\n' >&2
  else
    _INDEX_UI_ACTIVE=0
  fi
}

_index_ui_end() {
  if [[ "$_INDEX_UI_ACTIVE" -eq 1 ]]; then
    printf '\n' >&2
  fi
}

_index_progress_bar() {
  local pct="$1"
  local width=40
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar_fill=""
  local bar_empty=""

  printf -v bar_fill '%*s' "$filled" ''
  printf -v bar_empty '%*s' "$empty" ''
  bar_fill="${bar_fill// /#}"
  bar_empty="${bar_empty// /-}"
  printf '[%s%s] %3d%%' "$bar_fill" "$bar_empty" "$pct"
}

_index_fmt_secs() {
  local s="$1"
  (( s < 0 )) && s=0
  local m=$(( s / 60 ))
  local r=$(( s % 60 ))
  printf '%02d:%02d' "$m" "$r"
}

_index_ui_draw() {
  local pct="$1"
  local stage="$2"
  local detail="$3"
  local elapsed_s="${4:-0}"
  local eta_s="${5:-0}"
  local bar=""
  local elapsed_txt=""
  local eta_txt=""

  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  [[ -z "$detail" ]] && detail="working..."
  detail="${detail//$'\r'/}"

  bar="$(_index_progress_bar "$pct")"
  elapsed_txt="$(_index_fmt_secs "$elapsed_s")"
  eta_txt="$(_index_fmt_secs "$eta_s")"

  if [[ "$_INDEX_UI_ACTIVE" -eq 1 ]]; then
    printf '\033[%dA' "$_INDEX_UI_LINES" >&2
    printf '\033[2K+------------------------------------------------------------+\n' >&2
    printf '\033[2K| Fetching nixpkgs index (cached list for package search)    |\n' >&2
    printf '\033[2K| %s |\n' "$bar" >&2
    printf '\033[2K| Stage: %-51s|\n' "$stage" >&2
    printf '\033[2K| Time:  elapsed %-8s eta %-33s|\n' "$elapsed_txt" "$eta_txt" >&2
    printf '\033[2K| Output: %-50s|\n' "${detail:0:50}" >&2
    printf '\033[2K+------------------------------------------------------------+\n' >&2
  else
    printf 'Index fetch: %s | %s | elapsed=%s eta=%s | %s\n' "$bar" "$stage" "$elapsed_txt" "$eta_txt" "$detail" >&2
  fi
}

_index_run_stage() {
  local from_pct="$1"
  local to_pct="$2"
  local stage_label="$3"
  local expected_stage_secs="$4"
  shift 4

  local stage_log=""
  local pid=""
  local rc=0
  local span=$(( to_pct - from_pct ))
  local cur_pct="$from_pct"
  local detail=""
  local stage_start=0
  local elapsed=0
  local eta=0

  stage_log="$(mktemp)"

  "$@" >"$stage_log" 2>&1 &
  pid=$!
  stage_start=$SECONDS

  while kill -0 "$pid" 2>/dev/null; do
    elapsed=$(( SECONDS - stage_start ))
    if (( expected_stage_secs > 0 )) && (( span > 1 )); then
      cur_pct=$(( from_pct + (elapsed * span / expected_stage_secs) ))
      if (( cur_pct >= to_pct )); then
        cur_pct=$(( to_pct - 1 ))
      fi
      eta=$(( expected_stage_secs - elapsed ))
      (( eta < 0 )) && eta=0
    else
      cur_pct="$from_pct"
      eta=0
    fi
    detail="$(tail -n1 "$stage_log" 2>/dev/null || true)"
    _index_ui_draw "$cur_pct" "$stage_label" "$detail" "$elapsed" "$eta"
    sleep 0.2
  done

  if wait "$pid"; then
    rc=0
  else
    rc=$?
  fi

  detail="$(tail -n1 "$stage_log" 2>/dev/null || true)"
  elapsed=$(( SECONDS - stage_start ))
  _INDEX_LAST_STAGE_SECS="$elapsed"
  if [[ $rc -eq 0 ]]; then
    _index_ui_draw "$to_pct" "$stage_label" "done" "$elapsed" 0
  else
    _index_ui_draw "$to_pct" "$stage_label" "failed" "$elapsed" 0
    [[ -n "$detail" ]] && printf '  stage error: %s\n' "$detail" >&2
  fi

  rm -f "$stage_log"
  return "$rc"
}

_index_source_a() {
  local out_file="$1"
  local -a nix_args=()

  if declare -F _init_nix_pkg_args >/dev/null 2>&1; then
    _init_nix_pkg_args
    nix_args=("${_nix_pkg_args[@]}")
  fi

  command -v nix-env >/dev/null 2>&1 || return 0
  nix-env "${nix_args[@]}" -f '<nixpkgs>' -qaP --description 2>/dev/null \
    | awk '{
        attr=$1;
        if (attr == "") next;
        $1="";
        $2="";
        sub(/^[[:space:]]+/, "", $0);
        gsub(/\|/, "/", $0);
        print attr "|" $0;
      }' > "$out_file"
}

_index_source_b() {
  local out_file="$1"
  local -a nix_args=()

  if declare -F _init_nix_pkg_args >/dev/null 2>&1; then
    _init_nix_pkg_args
    nix_args=("${_nix_pkg_args[@]}")
  fi

  nix eval --impure "${nix_args[@]}" --raw --expr '
    let
      pkgs = import <nixpkgs> {};
      names = builtins.attrNames pkgs;

      format = name:
        let
          val = builtins.tryEval pkgs.${name};
        in
          if val.success && builtins.isAttrs val.value then
            name + "|" + (val.value.meta.description or "")
          else
            name + "|";
    in
      builtins.concatStringsSep "\n" (map format names)
  ' > "$out_file" 2>/dev/null
}

_index_source_c() {
  local out_file="$1"
  : > "$out_file"
}

build_nix_index() {
  echo "Building nixpkgs index..." >&2

  mkdir -p "$INDEX_DIR"

  local tmp_a="" tmp_b="" tmp_c="" tmp_all="" line_count=""
  local build_start=0 build_elapsed=0
  local exp_a=0 exp_b=0 exp_c=0
  local observed_a=0 observed_b=0 observed_c=0
  local next_a=0 next_b=0 next_c=0
  tmp_a="$(mktemp)"
  tmp_b="$(mktemp)"
  tmp_c="$(mktemp)"
  tmp_all="$(mktemp)"
  trap 'rm -f "${tmp_a:-}" "${tmp_b:-}" "${tmp_c:-}" "${tmp_all:-}"' RETURN

  _index_ui_begin
  _index_load_expected_secs
  _index_load_profile
  build_start=$SECONDS
  _index_ui_draw 2 "Initializing" "preparing temporary files" 0 "$_INDEX_EXPECTED_SECS"

  exp_a="$_INDEX_EXPECTED_A"
  exp_b="$_INDEX_EXPECTED_B"
  exp_c="$_INDEX_EXPECTED_C"

  _index_run_stage 5 30 "Source A (nix-env package list)" "$exp_a" _index_source_a "$tmp_a" || true
  observed_a="$_INDEX_LAST_STAGE_SECS"

  _index_run_stage 30 55 "Source B (top-level attrs)" "$exp_b" _index_source_b "$tmp_b" || true
  observed_b="$_INDEX_LAST_STAGE_SECS"

  _index_run_stage 55 80 "Source C (recursive flake scan)" "$exp_c" _index_source_c "$tmp_c" || true
  observed_c="$_INDEX_LAST_STAGE_SECS"

  local lines_a=0
  local lines_b=0
  local lines_c=0
  lines_a="$(wc -l < "$tmp_a" 2>/dev/null | tr -d '[:space:]')"
  lines_b="$(wc -l < "$tmp_b" 2>/dev/null | tr -d '[:space:]')"
  lines_c="$(wc -l < "$tmp_c" 2>/dev/null | tr -d '[:space:]')"

  build_elapsed=$(( SECONDS - build_start ))
  _index_ui_draw 85 "Merging" "deduplicating package rows" "$build_elapsed" 0

  cat "$tmp_a" "$tmp_b" "$tmp_c" \
    | awk -F'|' '
      {
        attr=$1;
        desc=$2;
        if (attr == "") next;
        if (!(attr in best) || (best[attr] == "" && desc != "")) {
          best[attr] = desc;
        }
      }
      END {
        for (attr in best) {
          print attr "|" best[attr];
        }
      }
    ' \
    | sort -f > "$tmp_all"

  build_elapsed=$(( SECONDS - build_start ))
  _index_ui_draw 92 "Validating" "counting final rows" "$build_elapsed" 0
  line_count="$(wc -l < "$tmp_all" | tr -d '[:space:]')"
  if [[ -z "$line_count" || "$line_count" -eq 0 ]]; then
    build_elapsed=$(( SECONDS - build_start ))
    _index_save_expected_secs "$build_elapsed"
    next_a="$(_index_smooth_secs "$exp_a" "$observed_a")"
    next_b="$(_index_smooth_secs "$exp_b" "$observed_b")"
    next_c="$(_index_smooth_secs "$exp_c" "$observed_c")"
    _index_save_profile "$next_a" "$next_b" "$next_c"
    {
      printf '[%s] build failed: no entries produced\n' "$(date '+%Y-%m-%d %H:%M:%S')"
      printf 'source_a_lines=%s\n' "${lines_a:-0}"
      printf 'source_b_lines=%s\n' "${lines_b:-0}"
      printf 'source_c_lines=%s\n' "${lines_c:-0}"
      if declare -F _init_nix_pkg_args >/dev/null 2>&1; then
        _init_nix_pkg_args
        printf 'nix_args=%s\n' "${_nix_pkg_args[*]:-(none)}"
      else
        printf 'nix_args=%s\n' '(utils resolver unavailable)'
      fi
      printf 'NIX_PATH=%s\n' "${NIX_PATH:-}"
    } > "$INDEX_REFRESH_ERROR_FILE" 2>/dev/null || true
    _index_ui_draw 100 "Failed" "no entries produced" "$build_elapsed" 0
    _index_ui_end
    echo "Failed to build nixpkgs index from all sources." >&2
    return 1
  fi

  build_elapsed=$(( SECONDS - build_start ))
  _index_ui_draw 97 "Writing cache" "saving to $INDEX_FILE" "$build_elapsed" 0
  mv "$tmp_all" "$INDEX_FILE"
  printf '%s\n' "$INDEX_VERSION" > "$INDEX_VERSION_FILE"
  build_elapsed=$(( SECONDS - build_start ))
  _index_save_expected_secs "$build_elapsed"
  next_a="$(_index_smooth_secs "$exp_a" "$observed_a")"
  next_b="$(_index_smooth_secs "$exp_b" "$observed_b")"
  next_c="$(_index_smooth_secs "$exp_c" "$observed_c")"
  _index_save_profile "$next_a" "$next_b" "$next_c"
  index_mark_fetch_updated "$build_elapsed"
  _index_ui_draw 100 "Done" "$line_count entries cached" "$build_elapsed" 0
  _index_ui_end

  echo "Index written to $INDEX_FILE ($line_count entries)" >&2
}

# Return the path to the package index file
get_index_file() {
  printf '%s\n' "$INDEX_FILE"
}

# Ensure index exists and is valid; build if missing or stale
ensure_index() {
  local index_version=""

  # Check if index file exists and version matches
  if [[ -f "$INDEX_FILE" ]] && [[ -f "$INDEX_VERSION_FILE" ]]; then
    index_version="$(cat "$INDEX_VERSION_FILE" 2>/dev/null || true)"
    if [[ "$index_version" == "$INDEX_VERSION" ]] && [[ -s "$INDEX_FILE" ]]; then
      # Index is valid and current
      return 0
    fi
  fi

  # Index missing, stale, or invalid - rebuild it
  build_nix_index
}
