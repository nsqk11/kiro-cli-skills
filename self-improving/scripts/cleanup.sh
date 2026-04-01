#!/bin/bash
# Self-Improving Cleanup: archive done entries from LOG.md
# Usage: ./cleanup.sh [--dry-run]
set -e

LOG_FILE="${KIRO_HOME:-$HOME/.kiro}/.learnings/LOG.md"
ARCHIVE="${KIRO_HOME:-$HOME/.kiro}/.learnings/ARCHIVE.md"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

[ -f "$LOG_FILE" ] || { echo "No LOG.md found."; exit 0; }

if [ ! -f "$ARCHIVE" ]; then
  $DRY_RUN || cat > "$ARCHIVE" << 'HEADER'
# Archive

Done entries archived from LOG.md.

---
HEADER
fi

entries=$(awk -v cutoff="$(date -d '24 hours ago' +%s 2>/dev/null || date -v-24H +%s 2>/dev/null)" '
  /^## \[LOG-/ { buf=$0"\n"; has_done=0; logged=""; next }
  buf { buf=buf $0"\n" }
  buf && /Status\*\*: done/ { has_done=1 }
  buf && /Logged\*\*:/ { logged=$0; sub(/.*Logged\*\*: */, "", logged) }
  buf && /^---$/ {
    if (has_done && logged != "") {
      cmd = "date -d \"" logged "\" +%s 2>/dev/null || echo 0"
      cmd | getline epoch
      close(cmd)
      if (epoch+0 < cutoff+0) printf "%s", buf
    }
    buf=""; has_done=0; logged=""
  }
' "$LOG_FILE")

[ -z "$entries" ] && { echo "No done entries to archive."; exit 0; }
count=$(echo "$entries" | grep -c '^## \[' || true)

if $DRY_RUN; then
  echo -e "${YELLOW}[DRY RUN]${NC} Would archive $count entries"
  echo "$entries" | grep '^## \['
else
  echo "" >> "$ARCHIVE"
  echo "<!-- Archived on $(date -Iseconds) -->" >> "$ARCHIVE"
  echo "$entries" >> "$ARCHIVE"

  awk -v cutoff="$(date -d '24 hours ago' +%s 2>/dev/null || date -v-24H +%s 2>/dev/null)" '
    /^## \[LOG-/ { buf=$0"\n"; has_done=0; logged=""; next }
    buf && !/^---$/ { buf=buf $0"\n"; if (/Status\*\*: done/) has_done=1; if (/Logged\*\*:/) { logged=$0; sub(/.*Logged\*\*: */, "", logged) }; next }
    buf && /^---$/ {
      if (has_done && logged != "") {
        cmd = "date -d \"" logged "\" +%s 2>/dev/null || echo 0"
        cmd | getline epoch
        close(cmd)
        if (epoch+0 < cutoff+0) { buf=""; has_done=0; logged=""; next }
      }
      printf "%s---\n", buf; buf=""; has_done=0; logged=""; next
    }
    !buf { print }
  ' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"

  echo -e "${GREEN}Archived${NC} $count entries. Done."
fi
