#!/bin/bash
# Hook dispatcher — scans repo for scripts with matching @hook annotation
# Requires all three annotations: @hook, @priority, @description
# Usage: dispatch.sh <hook-name> [stdin-data]
set -euo pipefail

HOOK="${1:?Usage: dispatch.sh <hook-name>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STDIN_DATA=""
[ ! -t 0 ] && STDIN_DATA=$(cat)

# Scan for scripts with all 3 annotations matching this hook
declare -a SCRIPTS=()
while IFS= read -r f; do
  head -15 "$f" | grep -q "^# @hook $HOOK" || continue
  head -15 "$f" | grep -q "^# @priority " || continue
  head -15 "$f" | grep -q "^# @description " || continue
  pri=$(head -15 "$f" | grep "^# @priority " | head -1 | sed 's/^# @priority //')
  SCRIPTS+=("$pri|$f")
done < <(find "$REPO_ROOT" -type f \( -name '*.py' -o -name '*.sh' \) \
  -not -path '*/hooks/dispatch.sh' \
  -not -path '*/.git/*' \
  -not -path '*/.data/*' \
  -not -path '*/tests/*' 2>/dev/null)

[ ${#SCRIPTS[@]} -eq 0 ] && exit 0

# Sort by priority (ascending)
SORTED=$(printf '%s\n' "${SCRIPTS[@]}" | sort -t'|' -k1 -n)

# Execute each script
while IFS='|' read -r pri script; do
  name=$(basename "$script")
  echo "[dispatch] $HOOK → $name (p$pri)" >&2
  if [[ "$script" == *.py ]]; then
    if [ -n "$STDIN_DATA" ]; then
      printf '%s' "$STDIN_DATA" | python3.12 "$script"
    else
      python3.12 "$script"
    fi
  else
    if [ -n "$STDIN_DATA" ]; then
      printf '%s' "$STDIN_DATA" | bash "$script"
    else
      bash "$script"
    fi
  fi
done <<< "$SORTED"
