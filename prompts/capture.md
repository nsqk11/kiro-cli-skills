# Capture

Reference: [5W2H](5w2h.md) | [MECE](mece.md)

## Why

- **do**: Valuable events in conversation — errors, corrections, discoveries — are lost if not captured promptly.
- **don't**: No speculative content without a concrete trigger event. No event = no log.

## What

- **do**: Detect valuable events in conversation and write them to `log.md` as pending entries. Record only — do not process.
- **don't**: Do not extract knowledge, modify skills, or consume LOG entries.

## Who

- **do**: Capture module. Uses `grep` for dedup checks in sub-steps.
- **don't**: Does not do Learn's or Improve's job.

## When

- **do**: Triggered on direct or indirect signals (see [Detection Trigger Table](#detection-trigger-table)). Session-end review runs via the stop hook. Quick Save triggers on user commands like `/save`.
- **don't**: Always deduplicate first — if it already exists, increment Hits instead of creating a new entry.

## Where

- **do**: Write to `.data/log.md`
- **don't**: Do not write to KB or skill files.

## How

- **do**:
  1. Detect event (signal types in [Detection Trigger Table](#detection-trigger-table))
  2. Dedup: `grep -F "Pattern-Key"` for exact match, then `grep -i "keyword"` for fuzzy match
  3. Match found → Hits +1, append date; no match → create new entry
  4. Write using [Entry Format](#entry-format)
  5. session-summary entries skip dedup (each is unique per session)
- **don't**: Do not chain commands — separate read and write calls.

## How much

- **do**: One entry per event. ID format: `LOG-YYYYMMDD-XXX`. Hits ≥ 3 = high priority.
- **don't**: No duplicates after dedup.

---

## Detection Trigger Table

### Event Types

| Situation | Type |
|-----------|------|
| Command/tool fails | `error` |
| User corrects you | `correction` |
| Knowledge was wrong/outdated | `knowledge-gap` |
| Better approach found | `improvement` |
| Missing capability requested | `feature-request` |
| Design/architecture decision | `decision` |
| Naming/format/process convention | `convention` |
| Task processing pattern | `workflow` |
| User communication pattern | `user-pattern` |
| Non-obvious pitfall | `gotcha` |
| Environment config/limitation | `environment` |
| Deprecated functionality | `deprecation` |
| End-of-session summary | `session-summary` |
| Skill improvement suggestion | `skill-improvement` |

### Indirect Signals

The user may not state intent explicitly. Watch for these patterns (examples in both Chinese and English):

| User Says | Likely Meaning |
|-----------|---------------|
| "Is this right?" / "Are you sure?" / "这样做能对吗？" / "确定吗？" | Correction — verify before proceeding |
| "I remember it differently" / "You said before..." / "我记得不是这样的" / "之前你说的是..." | Correction or knowledge-gap |
| "Is there another way?" / "Can you..." / "有没有其他方式" / "能不能..." | Feature-request or improvement |
| "Is that necessary?" / "Why not..." / "Can't we just...?" / "有必要吗？" / "为什么不..." / "不能直接...吗？" | Suggesting a better approach |
| "OK" / "Fine" after you explain a limitation / "好的" / "可以"（在你解释限制之后） | Resigned acceptance → likely feature-request |
| "Redo it" / "Revert" / "That's wrong, start over" / "重新改" / "改回去" / "不对重来" | Previous approach was wrong |

### Self-Improving Detection

If you realize mid-conversation that the user was correcting, requesting, or suggesting something earlier but it wasn't captured at the time — log the user's original words as `user-pattern`. This makes trigger detection improve over time.

---

## Entry Format

```markdown
## [LOG-YYYYMMDD-XXX] type

**Logged**: ISO-8601
**Status**: pending
**Hits**: 1 (YYYY-MM-DD)
**Pattern-Key**: domain.topic (optional)
**Tags**: tag1, tag2

### Summary
One-line description

### Details
Full context (error messages, user's exact words, trigger scenario, etc.)
```

### Pattern-Key

Optional stable dedup key in `domain.topic` format. Entries sharing the same Pattern-Key are automatically linked for pattern detection. Hits ≥ 3 + Pattern-Key = strong skill candidate signal. Do not add for one-off events.

### Priority Guidelines

| Priority | When |
|----------|------|
| critical | Blocks core functionality, data loss, security |
| high | Significant impact, common workflows, recurring, Hits ≥ 3 |
| medium | Moderate impact, workaround exists |
| low | Minor, edge case |
