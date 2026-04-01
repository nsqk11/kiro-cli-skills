#!/bin/bash
# Self-Improving Stats Dashboard
# Usage: ./stats.sh
set -e

LOG_FILE="${KIRO_HOME:-$HOME/.kiro}/.learnings/LOG.md"
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}═══ Self-Improving Dashboard ═══${NC}"
echo ""

[ -f "$LOG_FILE" ] || { echo "No LOG.md found."; exit 0; }

# By status
echo -e "${BOLD}By Status:${NC}"
for status in pending done; do
  count=$(grep -c "Status\*\*: $status" "$LOG_FILE" 2>/dev/null || true)
  case $status in
    pending) color=$YELLOW ;;
    done)    color=$GREEN ;;
  esac
  printf "  ${color}%-10s${NC} %d\n" "$status" "$count"
done
archived=0
[ -f "${KIRO_HOME:-$HOME/.kiro}/.learnings/ARCHIVE.md" ] && archived=$(grep -c '^## \[LOG-' "${KIRO_HOME:-$HOME/.kiro}/.learnings/ARCHIVE.md" 2>/dev/null || true)
printf "  %-10s %d\n" "archived" "$archived"

# By type
echo ""
echo -e "${BOLD}By Type:${NC}"
grep -oP '^\## \[LOG-[^\]]+\] \K\S+' "$LOG_FILE" 2>/dev/null | sort | uniq -c | sort -rn | while read -r count type; do
  printf "  %-20s %d\n" "$type" "$count"
done

# By tags (top 10)
echo ""
echo -e "${BOLD}Top Tags:${NC}"
grep -oP 'Tags\*\*: \K.*' "$LOG_FILE" 2>/dev/null | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | sort -rn | head -10 | while read -r count tag; do
  printf "  %-20s %d\n" "$tag" "$count"
done

# High hits
echo ""
echo -e "${BOLD}High Hits (≥3):${NC}"
awk '
  /^## \[LOG-/ { id=$0; sub(/^## /, "", id); sub(/\].*/, "]", id); hits=0; summary=""; next }
  /Hits\*\*:/ { hits=$0; sub(/.*Hits\*\*: */, "", hits); sub(/ .*/, "", hits); hits=hits+0; next }
  /^### Summary/ { getline; summary=$0; next }
  /^---$/ { if (hits >= 3) printf "  %-25s %dx  %s\n", id, hits, summary }
' "$LOG_FILE" 2>/dev/null

# Last 7 days
echo ""
echo -e "${BOLD}Last 7 Days:${NC}"
week_ago=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
if [ -n "$week_ago" ]; then
  recent=$(grep -oP 'Logged\*\*: \K\S+' "$LOG_FILE" 2>/dev/null | while read -r ts; do
    d=${ts:0:10}; [ "$d" \> "$week_ago" ] || [ "$d" = "$week_ago" ] && echo x
  done | wc -l)
  echo "  New entries: $recent"
fi
