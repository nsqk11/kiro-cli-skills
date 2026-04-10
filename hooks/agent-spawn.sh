#!/bin/bash
# Self-Improving — agentSpawn hook
# Loads memory + pending entries via mem.sh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SI="bash $SKILL_DIR/scripts/mem.sh"
REVIEW_STATE="$SKILL_DIR/.data/review-state.json"

cat << EOF
<self-improving-context>
SKILL_DIR=$SKILL_DIR
</self-improving-context>
EOF

# Memory: graduated entries not bound to any skill
MEMORY=$($SI memory 2>/dev/null)
if [ -n "$MEMORY" ]; then
  printf '\n<memory>\n%s\n</memory>\n' "$MEMORY"
fi

# Pending: open entries from previous sessions
PENDING=$($SI list --status open 2>/dev/null)
if [ -n "$PENDING" ]; then
  TOTAL=$(printf '%s\n' "$PENDING" | wc -l)
  printf '\n<pending-logs count="%d">\n%s\n</pending-logs>\n' "$TOTAL" "$PENDING"
fi

# Skill routing table
bash "$SKILL_DIR/scripts/skill-router.sh"

# Periodic review check
mkdir -p "$SKILL_DIR/.data"
if [ ! -f "$REVIEW_STATE" ]; then
  printf '{"sessions_since_review":0,"last_review_date":"%s"}\n' "$(date +%Y-%m-%d)" > "$REVIEW_STATE"
fi

sessions=$(jq -r '.sessions_since_review // 0' "$REVIEW_STATE" 2>/dev/null)
last_date=$(jq -r '.last_review_date // empty' "$REVIEW_STATE" 2>/dev/null)
sessions=$(( ${sessions:-0} + 1 ))
days=$(( ( $(date +%s) - $(date -d "${last_date:-$(date +%Y-%m-%d)}" +%s) ) / 86400 ))

if [ "$sessions" -ge 20 ] || [ "$days" -ge 7 ]; then
  cat << 'REVIEW'

<review-reminder>
Periodic review triggered. Check:
- Repeated keywords 3+ → graduate candidate?
- Open entries stale 7+ days → resolve or drop?
After review, reset via: jq '.sessions_since_review=0|.last_review_date="TODAY"' review-state.json
</review-reminder>
REVIEW
fi
jq --argjson s "$sessions" '.sessions_since_review = $s' "$REVIEW_STATE" > "$REVIEW_STATE.tmp" && mv -f "$REVIEW_STATE.tmp" "$REVIEW_STATE"
