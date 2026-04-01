#!/bin/bash
# Self-Improving — agentSpawn hook
# Loads pending LOG entries into context, outputs high-hits from LOG.md Hits field
set -e

LOG_FILE="${KIRO_HOME:-$HOME/.kiro}/.learnings/LOG.md"
MAX_ENTRIES=20
PROMOTE_THRESHOLD=3

cat << 'EOF'
<self-improving-active>
self-improving active. Captures events to $KIRO_HOME/.learnings/LOG.md when:
- Commands fail unexpectedly (error)
- User corrects you (correction)
- Knowledge is outdated (knowledge-gap)
- Better approach discovered (improvement)
- User requests missing capability (feature-request)
- User establishes convention/decision (convention, decision)
- Workflow/communication pattern observed (workflow, user-pattern)
- Environment limitation hit (environment)
- Non-obvious pitfall found (gotcha)
- Deprecated item referenced (deprecation)
Before logging, check: grep -i "keyword" $KIRO_HOME/.learnings/LOG.md
</self-improving-active>
EOF

[ -f "$LOG_FILE" ] || exit 0

# Collect pending entries: ID, Type, Summary, Tags, Hits
PENDING=$(awk '
  /^## \[LOG-/ { id=$0; sub(/^## /, "", id); sub(/\].*/, "]", id); type=$0; sub(/.*\] */, "", type);
    summary=""; tags=""; hits=""; is_pending=0; next }
  /Status\*\*: pending/ { is_pending=1; next }
  /Hits\*\*:/ { hits=$0; sub(/.*Hits\*\*: */, "", hits); sub(/ .*/, "", hits); next }
  /^### Summary/ { getline; summary=$0; next }
  /Tags\*\*:/ { tags=$0; sub(/.*Tags\*\*: */, "", tags); next }
  /^---$/ { if (is_pending && summary != "") print id "\t" type "\t" summary "\t" tags "\t" hits; is_pending=0 }
' "$LOG_FILE")

[ -z "$PENDING" ] && exit 0

TOTAL=$(echo "$PENDING" | wc -l)
PENDING=$(echo "$PENDING" | head -n "$MAX_ENTRIES")

# Output pending entries
echo ""
echo "<pending-logs>"
echo "Pending logs from previous sessions. Apply automatically when relevant."
[ "$TOTAL" -gt "$MAX_ENTRIES" ] && echo "Showing $MAX_ENTRIES of $TOTAL entries."
echo ""
while IFS=$'\t' read -r id type summary tags hits; do
  tag_suffix=""
  [ -n "$tags" ] && tag_suffix=" [$tags]"
  echo "- ${id} (${type}): ${summary}${tag_suffix}"
done <<< "$PENDING"
echo "</pending-logs>"

# High-hits entries (from LOG.md Hits field directly)
PROMOTE_LIST=""
while IFS=$'\t' read -r id type summary tags hits; do
  [ "${hits:-0}" -ge "$PROMOTE_THRESHOLD" ] && PROMOTE_LIST="${PROMOTE_LIST}\n- ${id} (${hits}x): ${summary}"
done <<< "$PENDING"

if [ -n "$PROMOTE_LIST" ]; then
  echo ""
  echo "<high-hits>"
  echo "These entries have Hits >= $PROMOTE_THRESHOLD. Prioritize for consumption."
  echo -e "$PROMOTE_LIST"
  echo "</high-hits>"
fi

# Skill routing table
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/skill-router.sh"

# Periodic review check
REVIEW_STATE="${KIRO_HOME:-$HOME/.kiro}/.learnings/review-state"
mkdir -p "$(dirname "$REVIEW_STATE")"
[ -f "$REVIEW_STATE" ] || printf 'sessions_since_review=0\nlast_review_date=%s\n' "$(date +%Y-%m-%d)" > "$REVIEW_STATE"
. "$REVIEW_STATE"
sessions_since_review=$(( ${sessions_since_review:-0} + 1 ))
days_since=$(( ( $(date +%s) - $(date -d "${last_review_date:-$(date +%Y-%m-%d)}" +%s) ) / 86400 ))
if [ "$sessions_since_review" -ge 20 ] || [ "$days_since" -ge 7 ]; then
  cat << 'REVIEW'

<review-reminder>
Periodic review triggered. Check per improve.md 周期性 Review:
- Repeated tags 3+ → Skill Candidate?
- Skills unused 30+ days → Archive?
- 3+ pending improvements → Batch update?
- Scope overlap → Merge?
After review, reset: echo -e "sessions_since_review=0\nlast_review_date=$(date +%Y-%m-%d)" > $KIRO_HOME/.learnings/review-state
</review-reminder>
REVIEW
fi
sed -i "s/^sessions_since_review=.*/sessions_since_review=$sessions_since_review/" "$REVIEW_STATE"
