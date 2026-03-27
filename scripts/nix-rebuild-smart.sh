#!/usr/bin/env bash
# Interactive NixOS rebuild + evaluation warning / missing-attribute resolver
# Uses the nixorcist package index for fast, relevance-ranked suggestions.

set -euo pipefail

CONFIG_DIR="/etc/nixos"
NIXORCIST_INDEX="${CONFIG_DIR}/nixorcist/cache/nixpkgs-index.txt"
NIXORCIST_LOCK="${CONFIG_DIR}/nixorcist/generated/.lock"
TMP_LOG="$(mktemp)"

# ─── File helpers ─────────────────────────────────────────────────────────────

apply_replace() {
    local file="$1" line="$2" old="$3" new="$4"
    if [[ -w "$file" ]]; then sed -i "${line}s|$old|$new|g" "$file"
    else                       sudo sed -i "${line}s|$old|$new|g" "$file"; fi
}

apply_replace_all() {
    local file="$1" old="$2" new="$3"
    if [[ -w "$file" ]]; then sed -i "s|$old|$new|g" "$file"
    else                       sudo sed -i "s|$old|$new|g" "$file"; fi
}

# ─── Index-based package search (same ranking as nixorcist find_similar_packages)
# Ranks by how closely the LEAF NAME of the attr path matches the query:
#   0 – exact leaf match      (pip  → python3Packages.pip)
#   1 – leaf starts with it   (pip  → pipx, pip-tools)
#   2 – leaf ends with it     (pip  → python-pip)
#   3 – query is a whole word (pip  → get-pip)
# Results capped at 12 and sorted by score, then alphabetically.

_index_find_similar() {
    local query="$1"
    [[ -f "$NIXORCIST_INDEX" ]] || return 0
    awk -F'|' -v q="$query" '
        BEGIN { ql = tolower(q) }
        {
            path = $1
            n = split(path, parts, ".")
            leaf = tolower(parts[n])
            if      (leaf == ql)                                          { score = 0 }
            else if (substr(leaf, 1, length(ql)) == ql)                   { score = 1 }
            else if (substr(leaf, length(leaf)-length(ql)+1) == ql)       { score = 2 }
            else if (leaf ~ ("(^|[-_])" ql "($|[-_])"))                   { score = 3 }
            else { next }
            printf "%d|%s\n", score, path
        }
    ' "$NIXORCIST_INDEX" | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f2 | head -12
}

_index_get_desc() {
    local pkg="$1"
    [[ -f "$NIXORCIST_INDEX" ]] || { printf '(no description)'; return; }
    awk -F'|' -v p="$pkg" '$1==p { sub(/^[^|]*\|/,""); print substr($0,1,60); exit }' \
        "$NIXORCIST_INDEX"
}

# ─── Interactive resolver for a single missing attribute ─────────────────────

_resolve_missing_attr() {
    local attr="$1"

    # Well-known renames — always offered first
    declare -A _KNOWN=(
        [python]=python3    [python2]=python27
        [nodejs]=nodejs_22  [ruby]=ruby_3_3
        [java]=jdk21        [openjdk]=jdk21
        [gcc]=gcc14         [clang]=clang_18
        [pip]=python3Packages.pip  [pip3]=python3Packages.pip
    )

    echo
    printf '  ┌─ Missing attribute ──────────────────────────────────┐\n'
    printf '  │  %-52s│\n' "'${attr}' not found in nixpkgs"
    printf '  └──────────────────────────────────────────────────────┘\n'
    echo

    # Build candidate list: well-known rename first, then index search
    local -a candidates=()
    if [[ -v _KNOWN[$attr] ]]; then
        candidates+=("${_KNOWN[$attr]}")
    fi
    local found
    while IFS= read -r found; do
        # Avoid duplicating the well-known entry
        local already=0
        local c; for c in "${candidates[@]}"; do [[ "$c" == "$found" ]] && already=1; done
        (( already )) || candidates+=("$found")
    done < <(_index_find_similar "$attr")

    if [[ ${#candidates[@]} -eq 0 ]]; then
        printf '  No close matches found in the index.\n'
        printf '  Enter a replacement name (or press Enter to skip): '
        local manual; read -r manual
        [[ -z "$manual" ]] && { echo "  Skipped."; return 0; }
        candidates+=("$manual")
    fi

    # Display candidates with descriptions
    printf '  Closest matches:\n\n'
    local i pkg desc
    for (( i=0; i<${#candidates[@]}; i++ )); do
        pkg="${candidates[$i]}"
        desc="$(_index_get_desc "$pkg")"
        [[ -z "$desc" ]] && desc="(no description)"
        printf '    %2d) %-38s  %s\n' "$((i+1))" "$pkg" "$desc"
    done
    printf '\n     0) Skip — remove %s from config\n\n' "$attr"

    local choice new_attr
    while true; do
        read -rp "  Choose [0-${#candidates[@]}]: " choice

        if [[ "$choice" == "0" ]]; then
            _smart_remove_from_lock "$attr"
            echo "  Removed '$attr' from nixorcist lock."
            return 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#candidates[@]} )); then
            new_attr="${candidates[$((choice-1))]}"
            break
        fi
        printf '  Enter a number between 0 and %d.\n' "${#candidates[@]}"
    done

    echo "  Replacing '$attr' → '$new_attr'..."

    # Replace in all managed .nix files
    local -a affected=()
    mapfile -t affected < <(
        grep -Rl "\b${attr}\b" "$CONFIG_DIR" --include="*.nix" 2>/dev/null || true
    )
    for f in "${affected[@]}"; do
        apply_replace_all "$f" "$attr" "$new_attr"
        echo "    Updated: $f"
    done

    # Update nixorcist lock (plain text, one package per line)
    _smart_replace_in_lock "$attr" "$new_attr"
}

_smart_remove_from_lock() {
    local attr="$1"
    [[ -f "$NIXORCIST_LOCK" ]] || return 0
    local tmp; tmp="$(mktemp)"
    grep -v "^${attr}$" "$NIXORCIST_LOCK" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$NIXORCIST_LOCK"
}

_smart_replace_in_lock() {
    local old="$1" new="$2"
    [[ -f "$NIXORCIST_LOCK" ]] || return 0
    # If new is already in lock, just remove old to avoid duplicates
    if grep -qx "$new" "$NIXORCIST_LOCK" 2>/dev/null; then
        _smart_remove_from_lock "$old"
    else
        local tmp; tmp="$(mktemp)"
        sed "s/^${old}$/${new}/" "$NIXORCIST_LOCK" > "$tmp"
        mv "$tmp" "$NIXORCIST_LOCK"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

echo "Running nixos-rebuild switch --upgrade..."
echo "--------------------------------------------------"

REBUILD_EXIT=0
sudo nixos-rebuild switch --upgrade 2>&1 | tee "$TMP_LOG" || REBUILD_EXIT=$?

# ── Evaluation warnings (moved packages) ──────────────────────────────────────
echo
echo "Parsing evaluation warnings..."
echo "--------------------------------------------------"

mapfile -t WARNINGS < <(grep "evaluation warning:" "$TMP_LOG" || true)

if [[ ${#WARNINGS[@]} -eq 0 ]]; then
    echo "No evaluation warnings detected."
else
    printf '%s\n\n' "${WARNINGS[@]}"

    for line in "${WARNINGS[@]}"; do
        OLD=$(echo "$line" | sed -n "s/.*'\([^']*\)' was moved.*/\1/p")
        NEW=$(echo "$line" | sed -n "s/.*Please use '\([^']*\)' directly.*/\1/p")
        [[ -z "$OLD" || -z "$NEW" ]] && continue

        echo "Rename detected:  $OLD  →  $NEW"
        mapfile -t MATCHES < <(grep -R --line-number --color=never "$OLD" "$CONFIG_DIR" || true)

        if [[ ${#MATCHES[@]} -eq 0 ]]; then echo "  No occurrences in config."; echo; continue; fi

        printf 'Occurrences:\n%s\n\n' "${MATCHES[@]}"
        read -rp "[Y/n/c] Replace ALL / Skip / Controlled? " CHOICE

        case "$CHOICE" in
            Y|y)
                mapfile -t FILES < <(grep -Rl "$OLD" "$CONFIG_DIR" || true)
                for file in "${FILES[@]}"; do apply_replace_all "$file" "$OLD" "$NEW"; echo "  Updated $file"; done
                ;;
            n|N) echo "Skipped." ;;
            c|C)
                for entry in "${MATCHES[@]}"; do
                    FILE=$(echo "$entry" | cut -d: -f1)
                    LINE=$(echo "$entry" | cut -d: -f2)
                    CONTENT=$(echo "$entry" | cut -d: -f3-)
                    echo; echo "  File: $FILE  Line: $LINE"; echo "  Code: $CONTENT"
                    read -rp "  Replace? [y/N] " CONFIRM
                    [[ "$CONFIRM" =~ ^[Yy]$ ]] && apply_replace "$FILE" "$LINE" "$OLD" "$NEW" && echo "  Replaced."
                done
                ;;
            *) echo "Skipped." ;;
        esac
        echo
    done
fi

# ── Missing / deprecated attributes ───────────────────────────────────────────
echo
echo "Checking for missing / deprecated attributes..."
echo "--------------------------------------------------"

mapfile -t MISSING_ATTRS < <(
    {
        grep -oP "attribute '\K[^']+(?=' missing)" "$TMP_LOG" 2>/dev/null || true
        grep -oP "undefined variable '\K[^']+(?=')"  "$TMP_LOG" 2>/dev/null || true
        grep -q  "Python 2 interpreter has been removed" "$TMP_LOG" 2>/dev/null && echo "python" || true
        grep -q  "Python2 is end-of-life"                "$TMP_LOG" 2>/dev/null && echo "python" || true
    } | sort -u
)

if [[ ${#MISSING_ATTRS[@]} -eq 0 ]]; then
    echo "No missing/undefined attributes detected."
else
    for attr in "${MISSING_ATTRS[@]}"; do
        _resolve_missing_attr "$attr"
    done
fi

rm -f "$TMP_LOG"

echo
echo "Finished."
[[ "$REBUILD_EXIT" -ne 0 ]] && exit "$REBUILD_EXIT"
exit 0
