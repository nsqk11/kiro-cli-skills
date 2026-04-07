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

- **do**: Knowledge decays, operations fail, capabilities have gaps. The closed-loop mechanism automatically captures these events, distills them into knowledge, and feeds improvements back into skills.
- **don't**: Not for one-off tasks or scenarios where accumulated experience adds no value.

## What

- **do**: Three-module closed loop — Capture (detect events) → Learn (distill knowledge) → Improve (refine skills). Turns errors, corrections, and discoveries into persistent knowledge and concrete skill improvements.
- **don't**: Does not execute business logic, does not replace domain-specific skills, does not modify its own files.

## Who

- **do**: Three sub-modules, each with a single responsibility:
  - [Capture](prompts/capture.md): Detect and log events
  - [Learn](prompts/learn.md): Digest events into knowledge
  - [Improve](prompts/improve.md): Feed knowledge back into skills
- **don't**: Capture does not process knowledge. Learn does not modify skills. Improve does not record events.

## When

- **do**:
  - Command/tool execution fails → Capture
  - User corrects the assistant → Capture
  - Knowledge is outdated or missing → Capture
  - Better approach discovered → Capture
  - User establishes a convention or decision → Capture
  - New session starts with pending entries → Learn
  - Same topic accumulates ≥ 3 hits in KB → Improve
- **don't**: Always deduplicate before capturing: `grep -i "keyword" .data/log.md` — skip if already logged.

## Where

- **do**:
  - Event buffer: `.data/log.md`
  - Knowledge store: `.data/knowledge.md`
  - Archive: `.data/archive.md`
- **don't**: Does not touch other skills' resource paths (Improve only modifies skill definition files).

## How

- **do**: Three-module sequential pipeline communicating through log.md:
  ```
  Capture → Learn → Improve
     ↑                  │
     └──────────────────┘
  ```
  - Capture → Learn: Events are written to log.md. At next session start, Learn consumes pending entries, distills them into KB, and marks them done.
  - Learn → Improve: Scans KB for entries without skill attribution, assigns `[skill: <name>]` tags, and merges them into the corresponding skill files.
  - Improve → Capture: Improved skills go into use; new issues continue to be captured.
  - Hook-driven: agentSpawn (`hooks/agent-spawn.sh`), postToolUse (`hooks/post-tool-use.sh`), stop (`hooks/stop.sh`)
  - When log.md exceeds 30 done entries, `scripts/cleanup.sh` archives them (triggered automatically by the stop hook).
- **don't**: Modules run strictly in sequence — never in parallel. Each module does only its own job. Read and write in separate calls. Never skip Learn to go directly from LOG to Skill — Improve's input is KB, not LOG.

## How much

- **do**:
  - Capture: One LOG entry per event
  - Learn: Consume all pending entries each run — no leftovers
  - Improve: Same topic ≥ 3 hits triggers skill modification; small gaps may be fixed immediately
  - agentSpawn loads at most 20 pending entries per session
- **don't**: No duplicates after dedup. Don't rush to modify skills for patterns below threshold.
