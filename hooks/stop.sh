#!/bin/bash
# Self-Improving — stop hook
# Prompts session review per capture.md rules
set -euo pipefail

cat << 'EOF'
<session-review>
Session ending. Per capture.md, do a session review:

1. If this conversation had substantive work, write a `session-summary` entry to log.md (format per capture.md 条目格式).
2. Check if any events occurred but were not captured (event types per capture.md 检测触发表).

Skip silently if conversation was trivial.
</session-review>
EOF

# Auto-cleanup: archive done entries when log exceeds 30
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$SKILL_DIR/.data/log.md"
if [ -f "$LOG_FILE" ]; then
  count=$(grep -c '^## \[LOG-' "$LOG_FILE" 2>/dev/null || true)
  if [ "${count:-0}" -gt 30 ]; then
    bash "$SKILL_DIR/scripts/cleanup.sh" 2>/dev/null || true
  fi
fi
