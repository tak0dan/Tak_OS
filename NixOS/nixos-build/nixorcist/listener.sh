#!/usr/bin/env bash

# Full terminal I/O listener (captures output + errors + keystrokes).
# Set to 0 (or comment out the call in nixorcist.sh) to disable.
# Default off: interactive wrappers can interfere with fzf/read flows on some hosts.
# Opt in by exporting NIXORCIST_LISTENER_ENABLED=1.
NIXORCIST_LISTENER_ENABLED="${NIXORCIST_LISTENER_ENABLED:-0}"
NIXORCIST_LISTENER_FILE="${NIXORCIST_LISTENER_FILE:-${ROOT:-.}/nixorcist-listener.txt}"
NIXORCIST_LISTENER_TIMING="${NIXORCIST_LISTENER_TIMING:-${ROOT:-.}/nixorcist-listener.timing}"
NIXORCIST_LISTENER_ACTIVE="${NIXORCIST_LISTENER_ACTIVE:-0}"

start_nixorcist_listener() {
  [[ "${NIXORCIST_LISTENER_ENABLED}" == "1" ]] || return 0
  [[ "${NIXORCIST_LISTENER_ACTIVE}" == "1" ]] && return 0

  if ! command -v script >/dev/null 2>&1; then
    printf 'listener disabled: script command not found\n' >&2
    return 0
  fi

  mkdir -p "$(dirname "$NIXORCIST_LISTENER_FILE")" 2>/dev/null || true

  local -a cmd=()
  local cmd_str=""
  local arg

  cmd+=("$0")
  for arg in "$@"; do
    cmd+=("$arg")
  done
  printf -v cmd_str '%q ' "${cmd[@]}"
  cmd_str="${cmd_str% }"

  export NIXORCIST_LISTENER_ACTIVE=1
  script --quiet --flush --return \
    --log-io "$NIXORCIST_LISTENER_FILE" \
    --log-timing "$NIXORCIST_LISTENER_TIMING" \
    --command "$cmd_str"
  exit $?
}
