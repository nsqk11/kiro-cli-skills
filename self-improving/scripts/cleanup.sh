#!/bin/bash
# Self-Improving Cleanup: archive done entries from LOG.md
# Usage: ./cleanup.sh [--dry-run]
set -euo pipefail

LOG_FILE="${KIRO_HOME:-$HOME/.kiro}/.learnings/LOG.md"
ARCHIVE="${KIRO_HOME:-$HOME/.kiro}/.learnings/ARCHIVE.md"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

# Color detection
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; NC=''
fi

[ -f "$LOG_FILE" ] || { printf 'No LOG.md found.\n'; exit 0; }

if [ ! -f "$ARCHIVE" ]; then
  $DRY_RUN || cat > "$ARCHIVE" << 'HEADER'
# Archive

Done entries archived from LOG.md.

---
HEADER
fi

# Pre-compute cutoff timestamp to avoid forking date inside awk
CUTOFF=$(date -d '24 hours ago' +%s 2>/dev/null || date -v-24H +%s 2>/dev/null)

entries=$(awk -v cutoff="$CUTOFF" '
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

[ -z "$entries" ] && { printf 'No done entries to archive.\n'; exit 0; }
count=$(printf '%s\n' "$entries" | grep -c '^## \[' || true)

if $DRY_RUN; then
  printf "${YELLOW}[DRY RUN]${NC} Would archive %d entries\n" "$count"
  printf '%s\n' "$entries" | grep '^## \['
else
  printf '\n' >> "$ARCHIVE"
  printf '<!-- Archived on %s -->\n' "$(date -Iseconds)" >> "$ARCHIVE"
  printf '%s\n' "$entries" >> "$ARCHIVE"

  awk -v cutoff="$CUTOFF" '
    /^## \[LOG-/ { buf=$0"\n"; has_done=0; logged=""; next }
    buf && !/^---$/ {
      buf=buf $0"\n"
      if (/Status\*\*: done/) has_done=1
      if (/Logged\*\*:/) { logged=$0; sub(/.*Logged\*\*: */, "", logged) }
      next
    }
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
  ' "$LOG_FILE" > "$LOG_FILE.tmp"

  # Safe replace: only overwrite if tmp was created successfully
  if [ -s "$LOG_FILE.tmp" ] || [ ! -s "$LOG_FILE.tmp" -a "$count" -gt 0 ]; then
    mv -f "$LOG_FILE.tmp" "$LOG_FILE"
  else
    rm -f "$LOG_FILE.tmp"
    printf 'Error: temp file creation failed, LOG.md unchanged.\n' >&2
    exit 1
  fi

  printf "${GREEN}Archived${NC} %d entries. Done.\n" "$count"
fi
