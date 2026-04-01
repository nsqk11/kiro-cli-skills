#!/bin/bash
# Self-Improving — postToolUse hook
# Auto-logs genuine errors to LOG.md
set -e

LOG_FILE="${KIRO_HOME:-$HOME/.kiro}/.learnings/LOG.md"
EVENT=$(cat)

if command -v jq &>/dev/null; then
  TOOL_NAME=$(echo "$EVENT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
  RESPONSE=$(echo "$EVENT" | jq -r '.tool_response // empty' 2>/dev/null)
  EXIT_STATUS=$(echo "$RESPONSE" | jq -r '.exit_status // empty' 2>/dev/null || echo "")
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
      ERROR_LINE=$(echo "$RESPONSE" | grep -iE "error:|failed|command not found|No such file|Permission denied|Traceback|Exception" | head -1 | cut -c1-120)
      [ -z "$ERROR_LINE" ] && ERROR_LINE="Command exited with status $EXIT_STATUS"
    fi
    ;;
  web_fetch)
    if echo "$RESPONSE" | grep -q "Failed to fetch URL\|An error occurred processing the tool"; then
      IS_ERROR=true
      ERROR_LINE=$(echo "$RESPONSE" | grep -oE "(Failed to fetch|An error occurred).*" | head -1 | cut -c1-120)
    fi
    ;;
  use_aws)
    if [ -n "$EXIT_STATUS" ] && [ "$EXIT_STATUS" != "0" ] && [ "$EXIT_STATUS" != "null" ]; then
      IS_ERROR=true
      ERROR_LINE=$(echo "$RESPONSE" | grep -iE "error|AccessDenied|InvalidParameter|ResourceNotFound" | head -1 | cut -c1-120)
    fi
    ;;
  fs_write)
    if echo "$RESPONSE" | grep -qE "^Error:|not unique|No such file|Failed to validate"; then
      IS_ERROR=true
      ERROR_LINE=$(echo "$RESPONSE" | grep -iE "Error:|not unique|No such file|Failed to validate" | head -1 | cut -c1-120)
    fi
    ;;
  fs_read)
    if echo "$RESPONSE" | grep -qE "^Error:|Failed to validate|Path is not"; then
      IS_ERROR=true
      ERROR_LINE=$(echo "$RESPONSE" | grep -iE "Error:|Failed to validate|Path is not" | head -1 | cut -c1-120)
    fi
    ;;
  *)
    if echo "$RESPONSE" | head -3 | grep -qiE "^error|^Error|\"error\":|An error occurred"; then
      IS_ERROR=true
      ERROR_LINE=$(echo "$RESPONSE" | grep -iE "error" | head -1 | cut -c1-120)
    fi
    ;;
esac

[ "$IS_ERROR" = false ] && exit 0
[ -z "$ERROR_LINE" ] && ERROR_LINE="Unknown error from $TOOL_NAME"

# Dedup: increment Hits if same error already logged
if grep -qF "$ERROR_LINE" "$LOG_FILE" 2>/dev/null; then
  ENTRY_ID=$(grep -B5 "$ERROR_LINE" "$LOG_FILE" | grep -oP '\[LOG-[0-9]+-[0-9]+\]' | tail -1)
  if [ -n "$ENTRY_ID" ]; then
    TODAY=$(date +%Y-%m-%d)
    ESCAPED_ID=$(printf '%s\n' "$ENTRY_ID" | sed 's/[][\\/.^$*]/\\&/g')
    sed -i "/$ESCAPED_ID/,/^---$/ s|\(Hits\*\*: \)\([0-9]*\)\(.*\)|\1$(( $(grep -A10 "$ENTRY_ID" "$LOG_FILE" | grep -oP 'Hits\*\*: \K[0-9]+') + 1 ))\3, $TODAY|" "$LOG_FILE" 2>/dev/null || true
  fi
  cat << EOF
<error-detected>
Tool error from $TOOL_NAME (Hits +1): $ERROR_LINE
</error-detected>
EOF
  exit 0
fi

# Generate next LOG ID
TODAY=$(date +%Y%m%d)
LAST_SEQ=$(grep -oP "LOG-${TODAY}-\K\d+" "$LOG_FILE" 2>/dev/null | sort -n | tail -1)
NEXT_SEQ=$(printf "%03d" $(( 10#${LAST_SEQ:-0} + 1 )))
LOG_ID="LOG-${TODAY}-${NEXT_SEQ}"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S%z)

mkdir -p "$(dirname "$LOG_FILE")"

cat >> "$LOG_FILE" << EOF

## [$LOG_ID] error

**Logged**: $TIMESTAMP
**Status**: pending
**Hits**: 1 ($( date +%Y-%m-%d ))
**Priority**: medium
**Pattern-Key**: error.$TOOL_NAME
**Tags**: auto-logged, $TOOL_NAME

### Summary
$ERROR_LINE

### Details
Tool: $TOOL_NAME
Exit status: ${EXIT_STATUS:-unknown}

---
EOF

cat << EOF
<error-detected>
📝 Logged [$LOG_ID]: $ERROR_LINE
</error-detected>
EOF
