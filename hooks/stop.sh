#!/bin/bash
# Self-Improving — stop hook
# Prompts session review per SKILL.md Capture rules
set -euo pipefail

. "$(dirname "$0")/../scripts/lib.sh"

cat << 'EOF'
<session-review>
Session ending. Per SKILL.md Capture rules, do a session review:

1. If this conversation had substantive work, write a `session-summary` entry to log.md.
2. Check if any events occurred but were not captured (event types per SKILL.md Detection Trigger Table).
3. Capture unfinished items with clear next-steps for session handoff.

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
