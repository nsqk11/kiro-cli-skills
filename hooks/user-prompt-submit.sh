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
EOF

# Correction signals
CORRECTION='不对|错了|不应该|不准确|你搞错|不对重来|你说错|搞错了|wrong|incorrect|not right|that.s not|你确定|确定吗|no.that|actually.no'
# Knowledge gap / doubt signals
DOUBT='我记得不是这样|我记得是|应该是.*不是|are you sure|i remember.differently'
# Improvement / alternative signals
IMPROVE='有没有其他|有没有别的|有更好的|is there another|better way|any other way'
# Unnecessary / overkill signals
OVERKILL='有必要吗|没必要|不需要|太复杂|is that necessary|overkill'

if echo "$PROMPT" | grep -qiE "$CORRECTION"; then
  printf "<correction-detected>\nUser may be correcting you. If this is a correction, log it immediately:\n  bash $SKILL_DIR/scripts/mem.sh add -t correction -k \"keyword\" -s \"summary\"\nThen write a correction entry before continuing work.\n</correction-detected>\n"
elif echo "$PROMPT" | grep -qiE "$DOUBT"; then
  printf "<possible-correction>\nUser may be questioning accuracy. Verify your claim, and if wrong, log as correction.\n</possible-correction>\n"
elif echo "$PROMPT" | grep -qiE "$IMPROVE"; then
  printf "<improvement-signal>\nUser is asking for alternatives. Consider logging as improvement or feature-request if a better approach exists.\n</improvement-signal>\n"
elif echo "$PROMPT" | grep -qiE "$OVERKILL"; then
  printf "<simplification-signal>\nUser thinks the approach is unnecessary or overcomplicated. Re-evaluate and consider logging as improvement.\n</simplification-signal>\n"
fi
