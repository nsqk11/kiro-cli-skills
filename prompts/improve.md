# Improve

Reference: [5W2H](5w2h.md) | [MECE](mece.md)

## Why

- **do**: Knowledge sitting in KB only changes behavior once it's fed back into skills. Improve turns accumulated knowledge into concrete skill improvements.
- **don't**: One-off issues — wait for recurrence to confirm a pattern before modifying skills.

## What

- **do**: Based on KB entries and periodic review signals: assign skill attribution, improve existing skills, create new skills, manage skill routing.
- **don't**: Do not record events (Capture's job), manage KB (Learn's job), read log.md, or modify self-improving's own files.

## Who

- **do**: Improve module. Uses `fs_read` to load skills, `str_replace` to modify them, `scripts/extract-skill.sh` to scaffold new skills.
- **don't**: Does not do Capture's or Learn's job.

## When

- **do**:
  - At session start (after Learn completes): scan KB for `[skill: <name>]` entries and merge them into corresponding skills
  - When user's topic matches a skill's triggers: load the skill on demand
  - When a small gap is found while using a skill: fix immediately
  - Periodic review (every 20 sessions or 7 days)
  - When user explicitly asks to "make it a skill": create immediately
- **don't**: Do not modify skills when the same topic has < 3 hits in KB. Do not auto-execute proposals the user hasn't approved.

## Where

- **do**:
  - Input: `.data/knowledge.md` (entries with skill tags)
  - Output: The target skill's `SKILL.md` (path depends on where the user installed their skills — no fixed location)
- **don't**: Do not write to log.md or KB.

## How

- **do**:

  ### Skill Routing
  1. At agentSpawn, `scripts/skill-router.sh` scans all `SKILL.md` frontmatter and injects a `<skill-router>` routing table into context
  2. User request → match against each skill's `triggers` in the routing table
  3. Match found → immediately `fs_read` the skill, no confirmation needed
  4. One request may trigger multiple skills; loaded skills stay active for the session
  5. Uncertain → do not load, wait for a clearer signal

  ### KB → Skill Feedback
  1. Scan KB for entries without skill attribution
  2. Determine attribution, tag as `[skill: <name>]` or `[skill: none]`
  3. Merge `[skill: <name>]` entries into the relevant section of the corresponding skill
  4. Mark KB entry as `[merged to skill: <name>]`
  5. Notify user

  ### Change Control
  | Type | Examples | Action |
  |------|----------|--------|
  | Minor | Add tip, fix wording, add example | Auto-apply, notify user |
  | Major | Create/delete skill, change triggers, restructure | Propose first, wait for user confirmation |

  ### Skill Discovery & Creation
  - Same type of task repeats 3+ times / user explicitly requests → generate Skill Candidate
  - Before creating: check overlap with existing skills > 50% → suggest improving the existing skill instead
  - All skills follow a unified standard:
    - [5W2H](5w2h.md) 7-dimension structure
    - [MECE](mece.md) between dimensions
    - do/don't for each dimension
    - Instruction-style for AI execution, not human-readable documentation
    - Reference line: `Reference: [5W2H](5w2h.md) | [MECE](mece.md)`
  - Quality gate: triggers cover common phrasings, description is understandable without context, no hardcoded paths
  - After creation, ensure frontmatter is correct so `skill-router.sh` picks it up automatically

  ### Periodic Review
  Every 20 sessions or 7 days, auto-prompt: recurring tag 3+ → Skill Candidate? Unused 30+ days → archive? 3+ pending improvements → batch update? Overlapping scope → merge?

- **don't**: Do not create skills for one-off tasks. Do not duplicate skills that already cover the topic. Skip cosmetic changes with no functional impact.

## How much

- **do**:
  - Feedback: process every `[skill: <name>]` entry — no leftovers
  - Discovery threshold: same topic 3+ times before proposing a new skill
  - User corrects the same behavior 2+ times → update the skill
  - Immediate fixes are limited to minor changes
- **don't**: Do not modify skills for patterns below threshold. Do not execute major changes without user confirmation.
