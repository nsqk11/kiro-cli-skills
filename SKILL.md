---
name: self-improving
description: "Three-module closed-loop system for continuous self-improvement"
triggers:
  - "command fails"
  - "user corrects"
  - "knowledge outdated"
  - "missing capability"
  - "better approach"
  - "convention"
  - "pending learnings"
---

# Self-Improving

Reference: [5W2H](prompts/5w2h.md) | [MECE](prompts/mece.md)

## Why

- **do**: Knowledge decays, operations fail, capabilities have gaps. The closed-loop captures events, distills knowledge, and feeds improvements back into skills.
- **don't**: Not for one-off tasks or scenarios where accumulated experience adds no value.

## What

- **do**: Three-module closed loop — Capture → Learn → Improve. Turns errors, corrections, and discoveries into persistent knowledge and concrete skill improvements.
- **don't**: Does not execute business logic, replace domain-specific skills, or modify its own files.

## Who

- **do**: Capture (detect & log events) → Learn (digest into KB) → Improve (feed back into skills).
- **don't**: Capture does not process knowledge. Learn does not modify skills. Improve does not record events.

## When

- **do**:
  - Command/tool fails, user corrects, knowledge outdated, better approach, convention/decision → Capture
  - New session with pending entries → Learn
  - Same topic ≥ 3 hits in KB → Improve
- **don't**: Always dedup first: `grep -i "keyword" .data/log.md` — skip if already logged.

## Where

- **do**: `.data/log.md` (event buffer) | `.data/knowledge.md` (KB) | `.data/archive.md`
- **don't**: Does not touch other skills' resource paths.

## How

```
Capture → Learn → Improve
   ↑                  │
   └──────────────────┘
```

Strictly sequential. Hook-driven: agentSpawn, postToolUse, stop. Read and write in separate calls. Never skip Learn (LOG → KB → Skill, not LOG → Skill).

When log.md exceeds 30 done entries, `scripts/cleanup.sh` archives them (stop hook).

### Capture

1. Detect event → dedup (`grep -F "Pattern-Key"` exact, then `grep -i` fuzzy)
2. Match found → Hits +1; no match → create new entry
3. session-summary entries skip dedup
4. Do not chain commands — separate read and write calls

#### Event Types

| Situation | Type |
|-----------|------|
| Command/tool fails | `error` |
| User corrects you | `correction` |
| Knowledge wrong/outdated | `knowledge-gap` |
| Better approach found | `improvement` |
| Missing capability | `feature-request` |
| Design/architecture decision | `decision` |
| Naming/format/process convention | `convention` |
| Task processing pattern | `workflow` |
| User communication pattern | `user-pattern` |
| Non-obvious pitfall | `gotcha` |
| Environment limitation | `environment` |
| Deprecated functionality | `deprecation` |
| End-of-session summary | `session-summary` |
| Skill improvement suggestion | `skill-improvement` |

#### Indirect Signals

| User Says | Likely Meaning |
|-----------|---------------|
| "Is this right?" / "确定吗？" | Correction |
| "I remember it differently" / "我记得不是这样的" | Correction or knowledge-gap |
| "Is there another way?" / "有没有其他方式" | Feature-request or improvement |
| "Is that necessary?" / "有必要吗？" | Better approach |
| "OK" / "Fine" after limitation explained | Feature-request |
| "Redo it" / "不对重来" | Previous approach wrong |

If you realize mid-conversation a correction/request wasn't captured — log the user's original words as `user-pattern`.

#### Entry Format

```markdown
## [LOG-YYYYMMDD-XXX] type

**Logged**: ISO-8601
**Status**: pending
**Hits**: 1 (YYYY-MM-DD)
**Pattern-Key**: domain.topic (optional, for dedup linking; skip for one-off)
**Tags**: tag1, tag2

### Summary
One-line description

### Details
Full context
```

Priority: critical > high (Hits ≥ 3) > medium (workaround exists) > low.

### Learn

1. Read all pending entries
2. `grep -i "keyword"` against KB:
   - Exists & consistent → skip, mark done
   - Contradicts → overwrite (user correction wins)
   - New → append
3. `knowledge update` to rebuild index
4. Mark `Status: done`
5. session-summaries: same topic ≥ 3 times across sessions → promote to KB

No leftovers. Do not modify skills or assign skill attribution.

#### Knowledge Lifecycle

Each KB entry has an implicit lifecycle state:

| State | Condition | Action |
|-------|-----------|--------|
| `new` | Just distilled from LOG | Available for use, not yet attributed |
| `active` | Attributed `[skill: <name>]` | In use, may be merged to skill |
| `promoted` | Merged to skill | Marked `[merged to skill: <name>]` |
| `archived` | Superseded or obsolete | Moved to archive.md by cleanup |

User correction always wins — overwrite without asking.

#### Knowledge Compaction

Prevent KB bloat over time:
- Entries promoted to skills → keep one-line summary + `[merged to skill: X]`, remove details
- Entries with `[skill: none]` older than 90 days and Hits = 1 → archive
- Contradicted entries → replaced in-place, old version not preserved

### Improve

#### Skill Routing
1. `scripts/skill-router.sh` injects `<skill-router>` routing table at agentSpawn
2. User request matches triggers → `fs_read` the skill immediately
3. Multiple skills may load; uncertain → wait for clearer signal

#### KB → Skill Feedback
1. Scan KB for unattributed entries → tag `[skill: <name>]` or `[skill: none]`
2. Merge into corresponding skill's SKILL.md
3. Mark KB entry `[merged to skill: <name>]`, notify user

#### Change Control

| Type | Action |
|------|--------|
| Minor (tip, wording, example) | Auto-apply, notify |
| Major (create/delete skill, triggers, restructure) | Propose first, wait for confirmation |

When applying a correction to a skill, record what triggered the change:
```
<!-- v1.1 (2026-04-09) — Fixed: X was wrong because Y. Triggered by: user correction on Z -->
```

#### Skill Discovery
- Same task 3+ times or user requests → Skill Candidate
- Overlap > 50% with existing → improve existing instead
- Standard: 5W2H structure, MECE, do/don't, instruction-style
- Quality gate: triggers cover common phrasings, no hardcoded paths
- Ensure frontmatter correct for `skill-router.sh`

#### Skill Quality Dimensions

When creating or reviewing skills, check:

| Dimension | Check |
|-----------|-------|
| Triggers | Cover common phrasings in both EN and ZH? |
| Scope | Clear boundary — no overlap > 50% with other skills? |
| Actionable | Instructions executable by AI, not just documentation? |
| Testable | Can verify if the skill was applied correctly? |
| Minimal | No redundant content that belongs in another skill? |

#### Periodic Review
Every 20 sessions or 7 days: recurring tag 3+ → Skill Candidate? Unused 30+ days → archive? 3+ pending → batch update? Overlap → merge?

#### Session Handoff

At session end (stop hook), if significant work was done:
- Capture unfinished items as `session-summary` with clear next-step
- Pending decisions → log as `decision` with options and context
- This ensures the next session can resume without re-explaining

## How much

- **do**: One LOG entry per event. Learn consumes all pending — no leftovers. Improve: ≥ 3 hits triggers skill mod; user corrects same behavior 2+ times → update skill. agentSpawn loads ≤ 20 pending entries.
- **don't**: No duplicates. Don't modify skills below threshold. Don't execute major changes without confirmation.
