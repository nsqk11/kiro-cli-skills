#!/bin/bash
# Self-Improving Stats Dashboard
# Usage: ./stats.sh
set -euo pipefail

. "$(dirname "$0")/lib.sh"

printf "${C_BOLD}═══ Self-Improving Dashboard ═══${C_NC}\n\n"

[ -f "$LIB_LOG_FILE" ] || { printf 'No log.md found.\n'; exit 0; }

# By status
printf "${C_BOLD}By Status:${C_NC}\n"
for status in pending done; do
  count=$(grep -c "Status\\*\\*: $status" "$LIB_LOG_FILE" 2>/dev/null || true)
  case $status in
    pending) color=$C_YELLOW ;;
    done)    color=$C_GREEN ;;
  esac
  printf "  ${color}%-10s${C_NC} %d\n" "$status" "$count"
done
archived=0
[ -f "$LIB_ARCHIVE_FILE" ] && archived=$(count_log_entries "$LIB_ARCHIVE_FILE")
printf "  %-10s %d\n" "archived" "$archived"

# By type
printf "\n${C_BOLD}By Type:${C_NC}\n"
awk "/$PAT_LOG_HEADER[^]]+\\] / { sub(/$PAT_LOG_HEADER[^]]+\\] */, \"\"); print \$1 }" "$LIB_LOG_FILE" 2>/dev/null \
  | sort | uniq -c | sort -rn | while read -r count type; do
  printf "  %-20s %d\n" "$type" "$count"
done

# By tags (top 10)
printf "\n${C_BOLD}Top Tags:${C_NC}\n"
awk '/Tags\*\*:/ { sub(/.*Tags\*\*: */, ""); print }' "$LIB_LOG_FILE" 2>/dev/null \
  | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | sort -rn | head -10 \
  | while read -r count tag; do
  printf "  %-20s %d\n" "$tag" "$count"
done

# High hits
printf "\n${C_BOLD}High Hits (≥3):${C_NC}\n"
awk '
  /^## \[LOG-/ { id=$0; sub(/^## /, "", id); sub(/\].*/, "]", id); hits=0; summary=""; next }
  /Hits\*\*:/ { hits=$0; sub(/.*Hits\*\*: */, "", hits); sub(/ .*/, "", hits); hits=hits+0; next }
  /^### Summary/ { getline; summary=$0; next }
  /^---$/ { if (hits >= 3) printf "  %-25s %dx  %s\n", id, hits, summary }
' "$LIB_LOG_FILE" 2>/dev/null

# Last 7 days
printf "\n${C_BOLD}Last 7 Days:${C_NC}\n"
week_ago=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
if [ -n "$week_ago" ]; then
  recent=$(awk '/Logged\*\*:/ { sub(/.*Logged\*\*: */, ""); sub(/T.*/, ""); print }' "$LIB_LOG_FILE" 2>/dev/null \
    | while read -r d; do
    [ "$d" \> "$week_ago" ] || [ "$d" = "$week_ago" ] && printf 'x\n'
  done | wc -l)
  printf "  New entries: %d\n" "$recent"
fi
