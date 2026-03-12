#!/usr/bin/env bash
# Advanced CLI transaction tool for nixorcist
# Allows forming a transaction: select packages to add/remove, attrsets handled as groups
# Writes a temporary transaction file, then applies changes in order

set -euo pipefail

transaction_file="/tmp/nixorcist-transaction-$$.txt"

# Interactive transaction builder
transaction_menu() {
  ensure_index
  mapfile -t all_pkgs < <(awk -F'|' '{print $1}' "$(get_index_file)")
  mapfile -t current < <(read_lock_entries)
  declare -A to_add to_remove

  while true; do
    echo "\nNixorcist Transaction Menu"
    echo "1) Add packages"
    echo "2) Remove packages"
    echo "3) Review transaction"
    echo "4) Apply transaction"
    echo "5) Cancel"
    read -p "Choose [1-5]: " action
    case "$action" in
      1)
        # Add packages or attrsets
        pkg=$(printf '%s\n' "${all_pkgs[@]}" | fzf --multi --prompt="ADD> " --preview 'pkg="{}"; desc=$(awk -F"|" -v p="$pkg" "$1==p{sub(/^[^|]*\|/, \"\"); print; exit}" "'"$(get_index_file)"'"); [[ -z "$desc" ]] && desc="No description"; printf "%s\n\nType: indexed entry\n" "$desc"')
        [[ -z "$pkg" ]] && continue
        if is_attrset "$pkg"; then
          mapfile -t variants < <(list_attrset_children "$pkg")
          for v in "${variants[@]}"; do
            to_add["$pkg.$v"]=1
            unset to_remove["$pkg.$v"]
          done
        else
          to_add["$pkg"]=1
          unset to_remove["$pkg"]
        fi
        ;;
      2)
        # Remove packages or attrsets
        pkg=$(printf '%s\n' "${current[@]}" | fzf --multi --prompt="REMOVE> " --preview 'pkg="{}"; desc=$(awk -F"|" -v p="$pkg" "$1==p{sub(/^[^|]*\|/, \"\"); print; exit}" "'"$(get_index_file)"'"); [[ -z "$desc" ]] && desc="No description"; printf "%s\n\nType: indexed entry\n" "$desc"')
        [[ -z "$pkg" ]] && continue
        if is_attrset "$pkg"; then
          mapfile -t variants < <(list_attrset_children "$pkg")
          for v in "${variants[@]}"; do
            to_remove["$pkg.$v"]=1
            unset to_add["$pkg.$v"]
          done
        else
          to_remove["$pkg"]=1
          unset to_add["$pkg"]
        fi
        ;;
      3)
        echo "\nTransaction Preview:"
        echo "To Add:"
        for k in "${!to_add[@]}"; do echo "  $k"; done
        echo "To Remove:"
        for k in "${!to_remove[@]}"; do echo "  $k"; done
        ;;
      4)
        echo "# ADD" > "$transaction_file"
        for k in "${!to_add[@]}"; do echo "$k" >> "$transaction_file"; done
        echo "# REMOVE" >> "$transaction_file"
        for k in "${!to_remove[@]}"; do echo "$k" >> "$transaction_file"; done
        echo "Transaction written to $transaction_file"
        apply_transaction "$transaction_file"
        break
        ;;
      5)
        echo "Transaction cancelled."
        break
        ;;
      *)
        echo "Invalid option."
        ;;
    esac
  done
}

# Apply transaction file: add, then remove
apply_transaction() {
  local file="$1"
  local mode=""
  mapfile -t lock < <(read_lock_entries)
  declare -A lock_set
  for p in "${lock[@]}"; do lock_set["$p"]=1; done
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && { mode=${line#\# }; continue; }
    [[ -z "$line" ]] && continue
    if [[ "$mode" == "ADD" ]]; then
      lock_set["$line"]=1
    elif [[ "$mode" == "REMOVE" ]]; then
      unset lock_set["$line"]
    fi
  done < "$file"
  printf '%s\n' "${!lock_set[@]}" | sort -u > "$LOCK_FILE"
  echo "Lock updated."
}

# Entrypoint
if [[ "${1:-}" == "transaction" ]]; then
  transaction_menu
fi
