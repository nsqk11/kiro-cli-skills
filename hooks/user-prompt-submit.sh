#!/bin/bash
# Self-Improving — userPromptSubmit hook
# Detects correction signals in user messages and reminds to log
set -euo pipefail

EVENT=$(cat)

PROMPT=""
if command -v jq &>/dev/null; then
  PROMPT=$(jq -r '.prompt // empty' <<< "$EVENT" 2>/dev/null)
fi

[ -z "$PROMPT" ] && exit 0

# Correction keywords (Chinese + English)
if echo "$PROMPT" | grep -qiE '不对|不是|错了|不应该|不准确|你搞错|wrong|incorrect|not right|that.s not'; then
  printf '<correction-detected>\nUser may be correcting you. If this is a correction, log it immediately:\ngrep -i "keyword" .data/log.md  # dedup check first\nThen write a correction entry before continuing work.\n</correction-detected>\n'
fi
