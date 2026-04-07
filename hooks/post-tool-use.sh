#!/bin/bash
# Self-Improving — postToolUse hook
# Auto-logs genuine errors to log.md
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$SKILL_DIR/.data"
LOG_FILE="$DATA_DIR/log.md"
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
      ERROR_LINE=$(grep -iE "error:|failed|command not found|No such file|Permission denied|Traceback|Exception" <<< "$RESPONSE" | head -1 | cut -c1-120)
      [ -z "$ERROR_LINE" ] && ERROR_LINE="Command exited with status $EXIT_STATUS"
    fi
    ;;
  web_fetch)
    if grep -q "Failed to fetch URL\|An error occurred processing the tool" <<< "$RESPONSE"; then
      IS_ERROR=true
      ERROR_LINE=$(grep -oE "(Failed to fetch|An error occurred).*" <<< "$RESPONSE" | head -1 | cut -c1-120)
    fi
    ;;
  use_aws)
    if [ -n "$EXIT_STATUS" ] && [ "$EXIT_STATUS" != "0" ] && [ "$EXIT_STATUS" != "null" ]; then
      IS_ERROR=true
      ERROR_LINE=$(grep -iE "error|AccessDenied|InvalidParameter|ResourceNotFound" <<< "$RESPONSE" | head -1 | cut -c1-120)
    fi
    ;;
  fs_write)
    if grep -qE "^Error:|not unique|No such file|Failed to validate" <<< "$RESPONSE"; then
      IS_ERROR=true
      ERROR_LINE=$(grep -iE "Error:|not unique|No such file|Failed to validate" <<< "$RESPONSE" | head -1 | cut -c1-120)
    fi
    ;;
  fs_read)
    if grep -qE "^Error:|Failed to validate|Path is not" <<< "$RESPONSE"; then
      IS_ERROR=true
      ERROR_LINE=$(grep -iE "Error:|Failed to validate|Path is not" <<< "$RESPONSE" | head -1 | cut -c1-120)
    fi
    ;;
  *)
    if head -3 <<< "$RESPONSE" | grep -qiE "^error|^Error|\"error\":|An error occurred"; then
      IS_ERROR=true
      ERROR_LINE=$(grep -iE "error" <<< "$RESPONSE" | head -1 | cut -c1-120)
    fi
    ;;
esac

[ "$IS_ERROR" = false ] && exit 0
[ -z "$ERROR_LINE" ] && ERROR_LINE="Unknown error from $TOOL_NAME"

# Dedup: increment Hits if same error already logged
if grep -qF "$ERROR_LINE" "$LOG_FILE" 2>/dev/null; then
  ENTRY_ID=$(grep -B5 -F "$ERROR_LINE" "$LOG_FILE" | grep -oP '\[LOG-[0-9]+-[0-9]+\]' | tail -1)
  if [ -n "$ENTRY_ID" ]; then
    TODAY=$(date +%Y-%m-%d)
    CURRENT_HITS=$(awk -v id="$ENTRY_ID" '
      $0 ~ "\\[" id "\\]" { found=1 }
      found && /Hits\*\*:/ { sub(/.*Hits\*\*: */, ""); sub(/ .*/, ""); print; exit }
    ' "$LOG_FILE")
    NEW_HITS=$(( ${CURRENT_HITS:-1} + 1 ))
    ESCAPED_ID=$(printf '%s\n' "$ENTRY_ID" | sed 's/[][\\/.^$*]/\\&/g')
    sed -i "/${ESCAPED_ID}/,/^---$/ s|\\(Hits\\*\\*: \\)[0-9]*\\(.*\\)|\\1${NEW_HITS}\\2, ${TODAY}|" "$LOG_FILE" 2>/dev/null || true
  fi
  printf '<error-detected>\nTool error from %s (Hits +1): %s\n</error-detected>\n' "$TOOL_NAME" "$ERROR_LINE"
  exit 0
fi

# Generate next LOG ID
TODAY=$(date +%Y%m%d)
LAST_SEQ=$({ grep -oP "LOG-${TODAY}-\\K\\d+" "$LOG_FILE" 2>/dev/null || true; } | sort -n | tail -1)
NEXT_SEQ=$(printf "%03d" $(( 10#${LAST_SEQ:-0} + 1 )))
LOG_ID="LOG-${TODAY}-${NEXT_SEQ}"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S%z)

mkdir -p "$DATA_DIR"

# Use printf to avoid heredoc injection from ERROR_LINE
{
  printf '\n## [%s] error\n\n' "$LOG_ID"
  printf '**Logged**: %s\n' "$TIMESTAMP"
  printf '**Status**: pending\n'
  printf '**Hits**: 1 (%s)\n' "$(date +%Y-%m-%d)"
  printf '**Priority**: medium\n'
  printf '**Pattern-Key**: error.%s\n' "$TOOL_NAME"
  printf '**Tags**: auto-logged, %s\n\n' "$TOOL_NAME"
  printf '### Summary\n%s\n\n' "$ERROR_LINE"
  printf '### Details\nTool: %s\nExit status: %s\n\n---\n' "$TOOL_NAME" "${EXIT_STATUS:-unknown}"
} >> "$LOG_FILE"

printf '<error-detected>\n📝 Logged [%s]: %s\n</error-detected>\n' "$LOG_ID" "$ERROR_LINE"
