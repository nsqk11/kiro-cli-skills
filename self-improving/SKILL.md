---
name: self-improving
description: "Closed-loop system (Capture → Learn → Improve) for continuous self-improvement. Use when a command fails, user corrects a mistake, knowledge is outdated, a missing capability is discovered, a better approach is found, a convention or decision is established, or there are pending learnings to review. Also triggers at session start to load memory and process graduated entries."
---

# Self-Improving

Reference: [5W2H](../prompts/5w2h.md) | [MECE](../prompts/mece.md)

## Data Store

Single file `.data/mem.json` managed by `$SKILL_DIR/scripts/memory.py`. Entry lifecycle: `open → done → graduated`.

```
python3.12 $SKILL_DIR/scripts/memory.py add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
python3.12 $SKILL_DIR/scripts/memory.py resolve  -i ID [-r "resolution"]
python3.12 $SKILL_DIR/scripts/memory.py graduate -i ID -S "section" [-k "skill-name"]
python3.12 $SKILL_DIR/scripts/memory.py list     [--status S] [--skill S] [--type T]
python3.12 $SKILL_DIR/scripts/memory.py search   -q "keyword"
python3.12 $SKILL_DIR/scripts/memory.py memory   # graduated + skill:none → context loading
python3.12 $SKILL_DIR/scripts/memory.py clean    [--apply]  # remove graduated-in-skill + done>7d
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
- **don't**: memory.py auto-deduplicates by keyword. If duplicate detected, review existing entry instead.

## Where

- **do**: `.data/mem.json` (single data store) | `$SKILL_DIR/scripts/memory.py` (CLI) | `data-template/` (template dir, not hidden)
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

1. Detect event → `python3.12 $SKILL_DIR/scripts/memory.py add -t TYPE -k "keywords" -s "summary"`
2. memory.py handles dedup automatically (exit 2 = duplicate found)
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

1. `python3.12 $SKILL_DIR/scripts/memory.py list --status open` — review pending entries
2. Resolve entries: `python3.12 $SKILL_DIR/scripts/memory.py resolve -i ID -r "resolution"`
3. Graduate mature entries: `python3.12 $SKILL_DIR/scripts/memory.py graduate -i ID -S "section"` (skill:none by default)
4. If entry belongs to a skill: `python3.12 $SKILL_DIR/scripts/memory.py graduate -i ID -S "section" -k "skill-name"`

User correction always wins — overwrite without asking.

#### Graduation Criteria

- `correction` type (user explicit fix) → graduate immediately, no count/age gate
- All other types: same topic ≥ 2 times AND age ≥ 3 days
- Or: user explicitly confirms it's a rule/convention

### Improve

#### Skill Routing
1. Most skills are loaded via `skill://` resources (lazy-loading by description match)
2. self-improving uses `file://` resource in agent config → preloaded at session start, no lazy-load
3. agentSpawn hook injects memory + pending-logs into context; `file://` provides the full SKILL.md

#### Graduated → Skill Feedback
1. `python3.12 $SKILL_DIR/scripts/memory.py list --status graduated --skill none` — unattributed entries
2. Merge into corresponding skill's SKILL.md
3. Re-graduate with skill: `python3.12 $SKILL_DIR/scripts/memory.py graduate -i ID -S "section" -k "skill-name"`
4. `python3.12 $SKILL_DIR/scripts/memory.py clean --apply` — remove graduated-in-skill + stale done entries

#### Change Control

| Type | Action |
|------|--------|
| Minor (tip, wording, example) | Auto-apply, notify |
| Major (create/delete skill, triggers, restructure) | Propose first, wait for confirmation |
| Design/implementation | Design discussion must reach consensus before writing code |
| Script/JSON change | Auto-apply, then update corresponding SKILL.md to document the change |

#### Skill Discovery
- Same task 3+ times or user requests → Skill Candidate
- Overlap > 50% with existing → improve existing instead
- Standard: 5W2H structure, MECE, do/don't, instruction-style
- Ensure frontmatter `name` + `description` are rich enough for `skill://` lazy-loading match

#### Periodic Review
Every 20 sessions or 7 days: recurring keywords 3+ → graduate candidate? Open entries stale 7+ days → resolve or drop?

#### Session Handoff

At session end (stop hook), if significant work was done:
- Capture unfinished items with clear next-step
- Pending decisions → log as `decision` with options and context

## How much

- **do**: One entry per event. Learn tiered: ≤5 silent, 6-15 suggest, >15 mandatory — no leftovers. Graduation: correction → immediate; others → ≥2 hits + ≥3 days. Improve: ≥ 3 hits triggers skill mod. agentSpawn loads memory + pending.
- **don't**: No duplicates (memory.py enforces). Don't modify skills below threshold. Don't execute major changes without confirmation.
