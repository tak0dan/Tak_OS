#!/usr/bin/env bash
# Tak_OS · discover-users.sh — discover existing human users for declarative export
# github.com/tak0dan/Tak_OS · GNU GPLv3
# Output format (tab-separated):
#   username  description  shell  is_admin  networking  virtualisation  audio  video  input  plugdev
set -euo pipefail

is_human_user() {
  local user="$1" uid="$2" home="$3" shell="$4"
  [[ "$user" == "nobody" ]] && return 1
  [[ "$uid" -lt 1000 || "$uid" -ge 65534 ]] && return 1
  [[ "$shell" =~ (nologin|false|sync)$ ]] && return 1
  [[ "$home" == /home/* || "$home" == /var/home/* || -d "$home" ]] || return 1
  return 0
}

emit_user() {
  local user="$1"
  local entry uid home shell gecos desc shell_base groups
  entry="$(getent passwd "$user" || true)"
  [[ -n "$entry" ]] || return 0
  IFS=: read -r _ _ uid _ gecos home shell <<< "$entry"
  is_human_user "$user" "$uid" "$home" "$shell" || return 0

  desc="${gecos%%,*}"
  [[ -n "$desc" ]] || desc="$user"
  shell_base="$(basename "$shell")"
  case "$shell_base" in
    zsh|bash|fish) ;;
    *) shell_base="bash" ;;
  esac

  groups="$(id -nG "$user" 2>/dev/null || true)"
  has_group() { grep -Eq "(^|[[:space:]])$1($|[[:space:]])" <<< "$groups"; }

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$user" \
    "$desc" \
    "$shell_base" \
    "$(has_group wheel && echo true || echo false)" \
    "$(has_group networkmanager && echo true || echo false)" \
    "$( { has_group vboxusers || has_group docker; } && echo true || echo false)" \
    "$(has_group audio && echo true || echo false)" \
    "$(has_group video && echo true || echo false)" \
    "$(has_group input && echo true || echo false)" \
    "$(has_group plugdev && echo true || echo false)"
}

main() {
  local -a users=()
  local line user _ _ uid _

  while IFS=: read -r user _ uid _ _ home shell; do
    if is_human_user "$user" "$uid" "$home" "$shell"; then
      users+=("$user")
    fi
  done < <(getent passwd)

  if [[ ${#users[@]} -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    users+=("${SUDO_USER}")
  fi

  if [[ ${#users[@]} -eq 0 ]]; then
    echo "No existing non-system users discovered." >&2
    exit 1
  fi

  printf '%s\n' "${users[@]}" | sort -u | while IFS= read -r user; do
    emit_user "$user"
  done
}

main "$@"
