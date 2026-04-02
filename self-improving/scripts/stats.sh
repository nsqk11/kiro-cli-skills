#!/bin/bash
# Self-Improving Stats Dashboard
# Usage: ./stats.sh
set -euo pipefail

LOG_FILE="${KIRO_HOME:-$HOME/.kiro}/.learnings/LOG.md"
ARCHIVE_FILE="${KIRO_HOME:-$HOME/.kiro}/.learnings/ARCHIVE.md"

# Color detection
if [ -t 1 ]; then
  CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'
else
  CYAN=''; GREEN=''; YELLOW=''; RED=''; NC=''; BOLD=''
fi

printf "${BOLD}═══ Self-Improving Dashboard ═══${NC}\n\n"

[ -f "$LOG_FILE" ] || { printf 'No LOG.md found.\n'; exit 0; }

# By status
printf "${BOLD}By Status:${NC}\n"
for status in pending done; do
  count=$(grep -c "Status\*\*: $status" "$LOG_FILE" 2>/dev/null || true)
  case $status in
    pending) color=$YELLOW ;;
    done)    color=$GREEN ;;
  esac
  printf "  ${color}%-10s${NC} %d\n" "$status" "$count"
done
archived=0
[ -f "$ARCHIVE_FILE" ] && archived=$(grep -c '^## \[LOG-' "$ARCHIVE_FILE" 2>/dev/null || true)
printf "  %-10s %d\n" "archived" "$archived"

# By type (awk instead of grep -oP)
printf "\n${BOLD}By Type:${NC}\n"
awk '/^## \[LOG-[^]]+\] / { sub(/^## \[LOG-[^]]+\] */, ""); print $1 }' "$LOG_FILE" 2>/dev/null \
  | sort | uniq -c | sort -rn | while read -r count type; do
  printf "  %-20s %d\n" "$type" "$count"
done

# By tags (top 10, awk instead of grep -oP)
printf "\n${BOLD}Top Tags:${NC}\n"
awk '/Tags\*\*:/ { sub(/.*Tags\*\*: */, ""); print }' "$LOG_FILE" 2>/dev/null \
  | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | sort -rn | head -10 \
  | while read -r count tag; do
  printf "  %-20s %d\n" "$tag" "$count"
done

# High hits
printf "\n${BOLD}High Hits (≥3):${NC}\n"
awk '
  /^## \[LOG-/ { id=$0; sub(/^## /, "", id); sub(/\].*/, "]", id); hits=0; summary=""; next }
  /Hits\*\*:/ { hits=$0; sub(/.*Hits\*\*: */, "", hits); sub(/ .*/, "", hits); hits=hits+0; next }
  /^### Summary/ { getline; summary=$0; next }
  /^---$/ { if (hits >= 3) printf "  %-25s %dx  %s\n", id, hits, summary }
' "$LOG_FILE" 2>/dev/null

# Last 7 days (awk instead of grep -oP)
printf "\n${BOLD}Last 7 Days:${NC}\n"
week_ago=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
if [ -n "$week_ago" ]; then
  recent=$(awk '/Logged\*\*:/ { sub(/.*Logged\*\*: */, ""); sub(/T.*/, ""); print }' "$LOG_FILE" 2>/dev/null \
    | while read -r d; do
    [ "$d" \> "$week_ago" ] || [ "$d" = "$week_ago" ] && printf 'x\n'
  done | wc -l)
  printf "  New entries: %d\n" "$recent"
fi
