#!/bin/bash
# Self-Improving — stop hook
# Prompts session review per capture.md rules
set -euo pipefail

. "$(dirname "$0")/../scripts/lib.sh"

cat << 'EOF'
<session-review>
Session ending. Per capture.md, do a session review:

1. If this conversation had substantive work, write a `session-summary` entry to log.md (format per capture.md 条目格式).
2. Check if any events occurred but were not captured (event types per capture.md 检测触发表).

Skip silently if conversation was trivial.
</session-review>
EOF

# Auto-cleanup: archive done entries when log exceeds 30
if [ -f "$LIB_LOG_FILE" ]; then
  count=$(count_log_entries "$LIB_LOG_FILE")
  if [ "${count:-0}" -gt 30 ]; then
    bash "$LIB_SKILL_DIR/scripts/cleanup.sh" 2>/dev/null || true
  fi
fi
