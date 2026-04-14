#!/bin/bash
# Self-Improving — stop hook
# Prompts session review
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SI="bash $SKILL_DIR/scripts/mem.sh"

OPEN=$($SI list --status open 2>/dev/null)
OPEN_COUNT=0
[ -n "$OPEN" ] && OPEN_COUNT=$(printf '%s\n' "$OPEN" | wc -l)

cat << EOF
<session-review>
Session ending. Quick review:
1. Any uncaptured events this session? (error/correction/gotcha/convention)
   → bash $SKILL_DIR/scripts/mem.sh add -t TYPE -k "kw" -s "summary"
2. Open entries: $OPEN_COUNT
3. Any entry ready to graduate?
   → bash $SKILL_DIR/scripts/mem.sh graduate -i ID -S "section"
Skip silently if conversation was trivial.
</session-review>
EOF
