#!/bin/bash
# Self-Improving — Shared library
# Source this file: . "$(dirname "$0")/../scripts/lib.sh" (from hooks)
#                   . "$(dirname "$0")/lib.sh"            (from scripts)

# --- Paths ---
LIB_SKILL_DIR="${LIB_SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LIB_DATA_DIR="$LIB_SKILL_DIR/.data"
LIB_LOG_FILE="$LIB_DATA_DIR/log.md"
LIB_ARCHIVE_FILE="$LIB_DATA_DIR/archive.md"
LIB_KB_FILE="$LIB_DATA_DIR/knowledge.md"
LIB_REVIEW_STATE="$LIB_DATA_DIR/review-state.json"

# --- Error patterns (grep -iE) ---
PAT_GENERIC_ERROR='error:|failed|command not found|No such file|Permission denied|Traceback|Exception'
PAT_WEB_FETCH='Failed to fetch URL|An error occurred processing the tool'
PAT_AWS_ERROR='error|AccessDenied|InvalidParameter|ResourceNotFound'
PAT_FS_WRITE='Error:|not unique|No such file|Failed to validate'
PAT_FS_READ='Error:|Failed to validate|Path is not'
PAT_FALLBACK='^error|^Error|"error":|An error occurred'

# --- Markdown patterns ---
PAT_LOG_HEADER='^## \[LOG-'
PAT_LOG_ID='\[LOG-[0-9]+-[0-9]+\]'
PAT_STATUS_PENDING='Status\*\*: pending'
PAT_STATUS_DONE='Status\*\*: done'
PAT_SECTION_END='^---$'

# --- Functions ---

# Extract first matching error line from response (max 120 chars)
# Usage: error_line=$(extract_error "$response" "$pattern")
extract_error() {
  grep -iE "$2" <<< "$1" | head -1 | cut -c1-120
}

# Check if response matches error pattern
# Usage: if matches_error "$response" "$pattern"; then ...
matches_error() {
  grep -qiE "$2" <<< "$1" 2>/dev/null
}

# Generate next LOG ID for today
# Usage: log_id=$(next_log_id "$log_file")
next_log_id() {
  local today=$(date +%Y%m%d)
  local last=$({ grep -oP "LOG-${today}-\\K\\d+" "$1" 2>/dev/null || true; } | sort -n | tail -1)
  printf 'LOG-%s-%03d' "$today" $(( 10#${last:-0} + 1 ))
}

# Count LOG entries in a file
# Usage: n=$(count_log_entries "$file")
count_log_entries() {
  grep -c "$PAT_LOG_HEADER" "$1" 2>/dev/null || echo 0
}

# Dedup: find existing entry ID by error line, return empty if not found
# Usage: entry_id=$(find_dup_entry "$log_file" "$error_line")
find_dup_entry() {
  grep -qF "$2" "$1" 2>/dev/null || return 0
  grep -B5 -F "$2" "$1" | grep -oP "$PAT_LOG_ID" | tail -1
}

# Increment Hits field for an entry
# Usage: increment_hits "$log_file" "$entry_id"
increment_hits() {
  local file="$1" id="$2" today=$(date +%Y-%m-%d)
  local current=$(awk -v id="$id" \
    '$0 ~ "\\[" id "\\]" {f=1} f && /Hits\*\*:/ {sub(/.*Hits\*\*: */,""); sub(/ .*/,""); print; exit}' "$file")
  local new=$(( ${current:-1} + 1 ))
  local esc=$(printf '%s\n' "$id" | sed 's/[][\\/.^$*]/\\&/g')
  sed -i "/${esc}/,/^---$/ s|\\(Hits\\*\\*: \\)[0-9]*\\(.*\\)|\\1${new}\\2, ${today}|" "$file" 2>/dev/null || true
  echo "$new"
}

# Write a new LOG entry to log.md
# Usage: write_log_entry "$log_file" "$log_id" "$tool_name" "$error_line" "$exit_status"
write_log_entry() {
  local file="$1" id="$2" tool="$3" summary="$4" exit_status="${5:-unknown}"
  local ts=$(date +%Y-%m-%dT%H:%M:%S%z)
  mkdir -p "$(dirname "$file")"
  {
    printf '\n## [%s] error\n\n' "$id"
    printf '**Logged**: %s\n' "$ts"
    printf '**Status**: pending\n'
    printf '**Hits**: 1 (%s)\n' "$(date +%Y-%m-%d)"
    printf '**Priority**: medium\n'
    printf '**Pattern-Key**: error.%s\n' "$tool"
    printf '**Tags**: auto-logged, %s\n\n' "$tool"
    printf '### Summary\n%s\n\n' "$summary"
    printf '### Details\nTool: %s\nExit status: %s\n\n---\n' "$tool" "$exit_status"
  } >> "$file"
}

# Parse pending entries from log.md (tab-separated: id, type, summary, tags, hits)
# Usage: pending=$(parse_pending_entries "$log_file")
parse_pending_entries() {
  awk '
    /^## \[LOG-/ {
      id=$0; sub(/^## /, "", id); sub(/\].*/, "]", id)
      type=$0; sub(/.*\] */, "", type)
      summary=""; tags=""; hits=""; is_pending=0; next
    }
    /Status\*\*: pending/ { is_pending=1; next }
    /Hits\*\*:/ { hits=$0; sub(/.*Hits\*\*: */, "", hits); sub(/ .*/, "", hits); next }
    /^### Summary/ { if ((getline line) > 0) summary=line; next }
    /Tags\*\*:/ { tags=$0; sub(/.*Tags\*\*: */, "", tags); next }
    /^---$/ {
      if (is_pending && summary != "") print id "\t" type "\t" summary "\t" tags "\t" hits
      is_pending=0
    }
  ' "$1"
}

# Color helpers (auto-detect terminal)
if [ -t 1 ]; then
  C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[0;31m'
  C_CYAN='\033[0;36m'; C_BOLD='\033[1m'; C_NC='\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''; C_BOLD=''; C_NC=''
fi
