#!/bin/bash
# Self-Improving Cleanup: archive done entries from LOG.md
# Usage: ./cleanup.sh [--dry-run]
set -euo pipefail

. "$(dirname "$0")/lib.sh"

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

[ -f "$LIB_LOG_FILE" ] || { printf 'No log.md found.\n'; exit 0; }

if [ ! -f "$LIB_ARCHIVE_FILE" ]; then
  $DRY_RUN || cat > "$LIB_ARCHIVE_FILE" << 'HEADER'
# Archive

Done entries archived from log.md.

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
' "$LIB_LOG_FILE")

[ -z "$entries" ] && { printf 'No done entries to archive.\n'; exit 0; }

count=$(printf '%s\n' "$entries" | grep -c "$PAT_LOG_HEADER" || true)

if $DRY_RUN; then
  printf "${C_YELLOW}[DRY RUN]${C_NC} Would archive %d entries\n" "$count"
  printf '%s\n' "$entries" | grep "$PAT_LOG_HEADER"
else
  printf '\n' >> "$LIB_ARCHIVE_FILE"
  printf '<!-- Archived on %s -->\n' "$(date -Iseconds)" >> "$LIB_ARCHIVE_FILE"
  printf '%s\n' "$entries" >> "$LIB_ARCHIVE_FILE"

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
  ' "$LIB_LOG_FILE" > "$LIB_LOG_FILE.tmp"

  if [ -s "$LIB_LOG_FILE.tmp" ] || [ "$count" -gt 0 ]; then
    mv -f "$LIB_LOG_FILE.tmp" "$LIB_LOG_FILE"
  else
    printf 'Error: temp file creation failed, log.md unchanged.\n' >&2
    exit 1
  fi

  printf "${C_GREEN}Archived${C_NC} %d entries.\n" "$count"
fi

# --- Phase 2: Clean merged KB entries ---
if [ -f "$LIB_KB_FILE" ]; then
  merged=$(grep -c '\[merged to skill:' "$LIB_KB_FILE" 2>/dev/null || true)
  if [ "$merged" -gt 0 ]; then
    if $DRY_RUN; then
      printf "${C_YELLOW}[DRY RUN]${C_NC} Would remove %d merged KB sections\n" "$merged"
    else
      awk '
        /^### .* \[merged to skill:/ { skip=1; next }
        /^###? / { skip=0 }
        !skip { print }
      ' "$LIB_KB_FILE" > "$LIB_KB_FILE.tmp"
      mv -f "$LIB_KB_FILE.tmp" "$LIB_KB_FILE"
      printf "${C_GREEN}Cleaned${C_NC} %d merged KB sections.\n" "$merged"
    fi
  fi
fi

printf 'Done.\n'
