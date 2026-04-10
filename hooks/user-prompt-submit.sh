#!/bin/bash
# Self-Improving — userPromptSubmit hook
# Detects correction signals in user messages
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SI="bash $SKILL_DIR/scripts/mem.sh"

EVENT=$(cat)
PROMPT=$(jq -r '.prompt // empty' <<< "$EVENT" 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

cat << 'EOF'

<proactive-agent>
Verify before asking. Finish then suggest next step. Flag risks immediately.
</proactive-agent>

<capture-check>
Review this message for capture signals (correction, doubt, improvement, overkill, convention, knowledge-gap).
If detected, log via mem.sh before continuing work.
</capture-check>
EOF
