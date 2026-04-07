#!/bin/bash
# Self-Improving — agentSpawn hook
# Loads pending LOG entries into context, outputs high-hits from log.md Hits field
set -euo pipefail

. "$(dirname "$0")/../scripts/lib.sh"

MAX_ENTRIES=20
PROMOTE_THRESHOLD=3

cat << 'EOF'
<self-improving-active>
self-improving active. Captures events to .data/log.md when:
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
Before logging, check: grep -i "keyword" .data/log.md
</self-improving-active>
EOF

[ -f "$LIB_LOG_FILE" ] || exit 0

# Collect pending entries using shared parser
PENDING=$(parse_pending_entries "$LIB_LOG_FILE")

[ -z "$PENDING" ] && exit 0

TOTAL=$(printf '%s\n' "$PENDING" | wc -l)
PENDING=$(printf '%s\n' "$PENDING" | head -n "$MAX_ENTRIES")

# Output pending entries
printf '\n<pending-logs>\n'
printf 'Pending logs from previous sessions. Apply automatically when relevant.\n'
[ "$TOTAL" -gt "$MAX_ENTRIES" ] && printf 'Showing %d of %d entries.\n' "$MAX_ENTRIES" "$TOTAL"
printf '\n'
while IFS=$'\t' read -r id type summary tags hits; do
  tag_suffix=""
  [ -n "$tags" ] && tag_suffix=" [$tags]"
  printf -- '- %s (%s): %s%s\n' "$id" "$type" "$summary" "$tag_suffix"
done <<< "$PENDING"
printf '</pending-logs>\n'

# High-hits entries
PROMOTE_LIST=""
while IFS=$'\t' read -r id type summary tags hits; do
  if [ "${hits:-0}" -ge "$PROMOTE_THRESHOLD" ]; then
    PROMOTE_LIST="${PROMOTE_LIST}$(printf '\n- %s (%sx): %s' "$id" "$hits" "$summary")"
  fi
done <<< "$PENDING"

if [ -n "$PROMOTE_LIST" ]; then
  printf '\n<high-hits>\n'
  printf 'These entries have Hits >= %d. Prioritize for consumption.\n' "$PROMOTE_THRESHOLD"
  printf '%s\n' "$PROMOTE_LIST"
  printf '</high-hits>\n'
fi

# Skill routing table
bash "$LIB_SKILL_DIR/scripts/skill-router.sh"

# Periodic review check
mkdir -p "$LIB_DATA_DIR"
if [ ! -f "$LIB_REVIEW_STATE" ]; then
  printf '{"sessions_since_review":0,"last_review_date":"%s","skill_review":{"last_review":"%s","conversation_count":0}}\n' \
    "$(date +%Y-%m-%d)" "$(date -Iseconds)" > "$LIB_REVIEW_STATE"
fi

sessions_since_review=$(jq -r '.sessions_since_review // 0' "$LIB_REVIEW_STATE" 2>/dev/null || \
  awk -F'[:,}]' '/"sessions_since_review"/{gsub(/[^0-9]/,"",$2);print $2}' "$LIB_REVIEW_STATE")
last_review_date=$(jq -r '.last_review_date // empty' "$LIB_REVIEW_STATE" 2>/dev/null || \
  awk -F'"' '/"last_review_date"/{print $4}' "$LIB_REVIEW_STATE")
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
After review, reset sessions_since_review to 0 and last_review_date to today in .data/review-state.json
</review-reminder>
REVIEW
fi
sed -i "s/\"sessions_since_review\":[0-9]*/\"sessions_since_review\":$sessions_since_review/" "$LIB_REVIEW_STATE"
