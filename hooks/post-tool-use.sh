#!/bin/bash
# Self-Improving — postToolUse hook
# Auto-logs genuine errors to log.md
set -euo pipefail

. "$(dirname "$0")/../scripts/lib.sh"

EVENT=$(cat)

if command -v jq &>/dev/null; then
  TOOL_NAME=$(jq -r '.tool_name // "unknown"' <<< "$EVENT" 2>/dev/null)
  RESPONSE=$(jq -r '.tool_response // empty' <<< "$EVENT" 2>/dev/null)
  EXIT_STATUS=$(jq -r '.exit_status // empty' <<< "$RESPONSE" 2>/dev/null || echo "")
else
  TOOL_NAME="unknown"
  RESPONSE="$EVENT"
  EXIT_STATUS=""
fi

[ -z "$RESPONSE" ] && exit 0

IS_ERROR=false
ERROR_LINE=""

case "$TOOL_NAME" in
  execute_bash|execute_cmd|shell)
    if [ -n "$EXIT_STATUS" ] && [ "$EXIT_STATUS" != "0" ] && [ "$EXIT_STATUS" != "null" ]; then
      IS_ERROR=true
      ERROR_LINE=$(extract_error "$RESPONSE" "$PAT_GENERIC_ERROR")
      [ -z "$ERROR_LINE" ] && ERROR_LINE="Command exited with status $EXIT_STATUS"
    fi
    ;;
  web_fetch)
    if matches_error "$RESPONSE" "$PAT_WEB_FETCH"; then
      IS_ERROR=true
      ERROR_LINE=$(grep -oE "(Failed to fetch|An error occurred).*" <<< "$RESPONSE" | head -1 | cut -c1-120)
    fi
    ;;
  use_aws)
    if [ -n "$EXIT_STATUS" ] && [ "$EXIT_STATUS" != "0" ] && [ "$EXIT_STATUS" != "null" ]; then
      IS_ERROR=true
      ERROR_LINE=$(extract_error "$RESPONSE" "$PAT_AWS_ERROR")
    fi
    ;;
  fs_write)
    if matches_error "$RESPONSE" "$PAT_FS_WRITE"; then
      IS_ERROR=true
      ERROR_LINE=$(extract_error "$RESPONSE" "$PAT_FS_WRITE")
    fi
    ;;
  fs_read)
    if matches_error "$RESPONSE" "$PAT_FS_READ"; then
      IS_ERROR=true
      ERROR_LINE=$(extract_error "$RESPONSE" "$PAT_FS_READ")
    fi
    ;;
  *)
    if matches_error "$(head -3 <<< "$RESPONSE")" "$PAT_FALLBACK"; then
      IS_ERROR=true
      ERROR_LINE=$(extract_error "$RESPONSE" 'error')
    fi
    ;;
esac

[ "$IS_ERROR" = false ] && exit 0
[ -z "$ERROR_LINE" ] && ERROR_LINE="Unknown error from $TOOL_NAME"

# Dedup: increment Hits if same error already logged
DUP_ID=$(find_dup_entry "$LIB_LOG_FILE" "$ERROR_LINE")
if [ -n "$DUP_ID" ]; then
  NEW_HITS=$(increment_hits "$LIB_LOG_FILE" "$DUP_ID")
  printf '<error-detected>\nTool error from %s (Hits +1): %s\n</error-detected>\n' "$TOOL_NAME" "$ERROR_LINE"
  exit 0
fi

# New entry
LOG_ID=$(next_log_id "$LIB_LOG_FILE")
write_log_entry "$LIB_LOG_FILE" "$LOG_ID" "$TOOL_NAME" "$ERROR_LINE" "${EXIT_STATUS:-unknown}"

printf '<error-detected>\n📝 Logged [%s]: %s\n</error-detected>\n' "$LOG_ID" "$ERROR_LINE"
