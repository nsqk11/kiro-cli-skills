#!/bin/bash
# Self-Improving — postToolUse hook
# Auto-logs genuine errors via si.sh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SI="bash $SKILL_DIR/scripts/si.sh"

EVENT=$(cat)

TOOL_NAME=$(jq -r '.tool_name // "unknown"' <<< "$EVENT" 2>/dev/null)
RESPONSE=$(jq -r '.tool_response // empty' <<< "$EVENT" 2>/dev/null)
EXIT_STATUS=$(jq -r '.exit_status // empty' <<< "$RESPONSE" 2>/dev/null || echo "")

[ -z "$RESPONSE" ] && exit 0

IS_ERROR=false
ERROR_LINE=""

case "$TOOL_NAME" in
  execute_bash|execute_cmd|shell)
    if [ -n "$EXIT_STATUS" ] && [ "$EXIT_STATUS" != "0" ] && [ "$EXIT_STATUS" != "null" ]; then
      IS_ERROR=true
      ERROR_LINE=$(grep -iE 'error|fatal|denied|not found|no such' <<< "$RESPONSE" | head -1 | cut -c1-120)
      [ -z "$ERROR_LINE" ] && ERROR_LINE="Command exited with status $EXIT_STATUS"
    fi
    ;;
  use_aws)
    if [ -n "$EXIT_STATUS" ] && [ "$EXIT_STATUS" != "0" ] && [ "$EXIT_STATUS" != "null" ]; then
      IS_ERROR=true
      ERROR_LINE=$(grep -iE 'error|exception|denied' <<< "$RESPONSE" | head -1 | cut -c1-120)
    fi
    ;;
  fs_write|fs_read)
    if head -3 <<< "$RESPONSE" | grep -qiE 'error|failed|denied'; then
      IS_ERROR=true
      ERROR_LINE=$(head -3 <<< "$RESPONSE" | grep -iE 'error|failed|denied' | head -1 | cut -c1-120)
    fi
    ;;
esac

[ "$IS_ERROR" = false ] && exit 0
[ -z "$ERROR_LINE" ] && ERROR_LINE="Unknown error from $TOOL_NAME"

# Try to add; si.sh handles dedup (exit 2 = duplicate)
OUT=$($SI add -t error -k "$TOOL_NAME" -s "$ERROR_LINE" 2>&1) || true

if [[ "$OUT" == DUPLICATE* ]]; then
  printf '<error-detected>\nTool error from %s (duplicate): %s\n</error-detected>\n' "$TOOL_NAME" "$ERROR_LINE"
else
  printf '<error-detected>\n📝 %s: %s\n</error-detected>\n' "$OUT" "$ERROR_LINE"
fi
