#!/usr/bin/env bash
# Update every Git worktree on local filesystems.  Create skip-script.txt in a
# repository root to opt that repository out; its contents are ignored.

set -u -o pipefail

declare -i updated=0 skipped=0 failed=0

while IFS= read -r -d '' git_entry; do
  repo_root=$(git -C "$(dirname "$git_entry")" rev-parse --show-toplevel 2>/dev/null) || continue

  if [[ -e "$repo_root/skip-script.txt" ]]; then
    printf 'Skipping %s (skip-script.txt present)\n' "$repo_root"
    ((skipped += 1))
    continue
  fi

  printf 'Updating %s\n' "$repo_root"
  if git -C "$repo_root" pull; then
    ((updated += 1))
  else
    printf 'Failed to update %s\n' "$repo_root" >&2
    ((failed += 1))
  fi
done < <(
  find / \
    \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
    -name .git \( -type d -o -type f \) -print0 2>/dev/null
)

printf 'Completed: %d updated, %d skipped, %d failed.\n' \
  "$updated" "$skipped" "$failed"

(( failed == 0 ))
