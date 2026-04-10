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

## Data Store

Single file `.data/mem.json` managed by `$SKILL_DIR/scripts/mem.sh`. Entry lifecycle: `open → done → graduated`.

```
bash $SKILL_DIR/scripts/mem.sh add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
bash $SKILL_DIR/scripts/mem.sh resolve  -i ID [-r "resolution"]
bash $SKILL_DIR/scripts/mem.sh graduate -i ID -S "section" [-k "skill-name"]
bash $SKILL_DIR/scripts/mem.sh list     [--status S] [--skill S] [--type T]
bash $SKILL_DIR/scripts/mem.sh search   -k "keyword"
bash $SKILL_DIR/scripts/mem.sh memory   # graduated + skill:none → context loading
```

## Why

- **do**: Knowledge decays, operations fail, capabilities have gaps. The closed-loop captures events, distills knowledge, and feeds improvements back into skills.
- **don't**: Not for one-off tasks or scenarios where accumulated experience adds no value.

## What

- **do**: Three-module closed loop — Capture → Learn → Improve. Turns errors, corrections, and discoveries into persistent knowledge and concrete skill improvements.
- **don't**: Does not execute business logic, replace domain-specific skills, or modify its own files.

## Who

- **do**: Capture (detect & log events) → Learn (digest into graduated entries) → Improve (feed back into skills).
- **don't**: Capture does not process knowledge. Learn does not modify skills. Improve does not record events.

## When

- **do**:
  - Command/tool fails, user corrects, knowledge outdated, better approach, convention/decision → Capture
  - New session with pending entries → Learn (tiered by count: ≤5 silent, 6-15 suggest, >15 mandatory)
  - Same topic ≥ 3 hits → Improve
- **don't**: mem.sh auto-deduplicates by keyword. If duplicate detected, review existing entry instead.

## Where

- **do**: `.data/mem.json` (single data store) | `$SKILL_DIR/scripts/mem.sh` (CLI) | `data-template/` (template dir, not hidden)
- **don't**: Does not touch other skills' resource paths. Note: self-improving dir itself is a git repo — use sufficient maxdepth when searching for `.git`.

## How

```
Capture → Learn → Improve
   ↑                  │
   └──────────────────┘
```

Strictly sequential. Hook-driven: agentSpawn, postToolUse, userPromptSubmit, stop.

Proactive means independently thinking, exploring, and solving — not blind obedience.

### Capture

1. Detect event → `bash $SKILL_DIR/scripts/mem.sh add -t TYPE -k "keywords" -s "summary"`
2. mem.sh handles dedup automatically (exit 2 = duplicate found)
3. Do not chain commands — separate read and write calls

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

#### Indirect Signals

| User Says | Likely Meaning |
|-----------|---------------|
| "Is this right?" / "确定吗？" | Correction |
| "I remember it differently" / "我记得不是这样的" | Correction or knowledge-gap |
| "Is there another way?" / "有没有其他方式" | Feature-request or improvement |
| "Is that necessary?" / "有必要吗？" | Better approach |
| "Redo it" / "不对重来" | Previous approach wrong |

If you realize mid-conversation a correction/request wasn't captured — log the user's original words as `user-pattern`.

### Learn

1. `bash $SKILL_DIR/scripts/mem.sh list --status open` — review pending entries
2. Resolve entries: `bash $SKILL_DIR/scripts/mem.sh resolve -i ID -r "resolution"`
3. Graduate mature entries: `bash $SKILL_DIR/scripts/mem.sh graduate -i ID -S "section"` (skill:none by default)
4. If entry belongs to a skill: `bash $SKILL_DIR/scripts/mem.sh graduate -i ID -S "section" -k "skill-name"`

User correction always wins — overwrite without asking.

#### Graduation Criteria

- `correction` type (user explicit fix) → graduate immediately, no count/age gate
- All other types: same topic ≥ 2 times AND age ≥ 3 days
- Or: user explicitly confirms it's a rule/convention

### Improve

#### Skill Routing
1. `$SKILL_DIR/scripts/skill-router.sh` injects `<skill-router>` routing table at agentSpawn
2. User request matches triggers → `fs_read` the skill immediately
3. Multiple skills may load; uncertain → wait for clearer signal
4. Context lists a SKILL.md → read it proactively at conversation start, don't wait for user to trigger

#### Graduated → Skill Feedback
1. `bash $SKILL_DIR/scripts/mem.sh list --status graduated --skill none` — unattributed entries
2. Merge into corresponding skill's SKILL.md
3. Re-graduate with skill: `bash $SKILL_DIR/scripts/mem.sh graduate -i ID -S "section" -k "skill-name"`

#### Change Control

| Type | Action |
|------|--------|
| Minor (tip, wording, example) | Auto-apply, notify |
| Major (create/delete skill, triggers, restructure) | Propose first, wait for confirmation |
| Script/JSON change | Auto-apply, then update corresponding SKILL.md to document the change |

#### Skill Discovery
- Same task 3+ times or user requests → Skill Candidate
- Overlap > 50% with existing → improve existing instead
- Standard: 5W2H structure, MECE, do/don't, instruction-style
- Ensure frontmatter correct for `skill-router.sh`

#### Periodic Review
Every 20 sessions or 7 days: recurring keywords 3+ → graduate candidate? Open entries stale 7+ days → resolve or drop?

#### Session Handoff

At session end (stop hook), if significant work was done:
- Capture unfinished items with clear next-step
- Pending decisions → log as `decision` with options and context

## How much

- **do**: One entry per event. Learn tiered: ≤5 silent, 6-15 suggest, >15 mandatory — no leftovers. Graduation: correction → immediate; others → ≥2 hits + ≥3 days. Improve: ≥ 3 hits triggers skill mod. agentSpawn loads memory + pending.
- **don't**: No duplicates (mem.sh enforces). Don't modify skills below threshold. Don't execute major changes without confirmation.
