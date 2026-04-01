#!/bin/bash
# Self-Improving — stop hook
# Prompts session review per capture.md rules
set -e

cat << 'EOF'
<session-review>
Session ending. Per capture.md, do a session review:

1. If this conversation had substantive work, write a `session-summary` entry to LOG.md (format per capture.md 条目格式).
2. Check if any events occurred but were not captured (event types per capture.md 检测触发表).

Skip silently if conversation was trivial.
</session-review>
EOF
