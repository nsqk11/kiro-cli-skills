#!/bin/bash
# Self-Improving — userPromptSubmit hook
# Detects correction signals in user messages
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SI="bash $SKILL_DIR/scripts/si.sh"

EVENT=$(cat)
PROMPT=$(jq -r '.prompt // empty' <<< "$EVENT" 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

if echo "$PROMPT" | grep -qiE '不对|不是|错了|不应该|不准确|你搞错|wrong|incorrect|not right|that.s not'; then
  printf '<correction-detected>\nUser may be correcting you. If this is a correction, log it immediately:\n  bash scripts/si.sh add -t correction -k "keyword" -s "summary"\nThen write a correction entry before continuing work.\n</correction-detected>\n'
fi
