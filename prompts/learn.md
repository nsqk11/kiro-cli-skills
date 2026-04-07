# Learn

Reference: [5W2H](5w2h.md) | [MECE](mece.md)

## Why

- **do**: Pending entries in log.md are raw events. They must be digested into structured, searchable knowledge before Improve or daily use can benefit from them.
- **don't**: One-off facts unlikely to recur — let them age naturally in log.md.

## What

- **do**: Consume all pending entries from log.md, distill them into knowledge.md, and mark them done.
- **don't**: Do not record events (Capture's job), modify skills (Improve's job), or assign skill attribution (Improve's job).

## Who

- **do**: Learn module. Uses `grep` for KB dedup; `knowledge update` to rebuild the index.
- **don't**: Does not do Capture's or Improve's job.

## When

- **do**: At new session start, after the agentSpawn hook loads pending entries. Consume all pending entries.
- **don't**: session-summary entries are not written to KB immediately — they go through cross-session pattern recognition (same topic ≥ 3 times before promotion).

## Where

- **do**:
  - Input: `.data/log.md` (pending entries)
  - Output: `.data/knowledge.md`
- **don't**: Do not write to project-specific KBs.

## How

- **do**:
  1. Read all pending entries
  2. For each entry, `grep -i "keyword"` against KB:
     - Exists and consistent → skip write, mark done
     - Exists but contradicts → overwrite with latest content (user correction takes priority)
     - Does not exist → append to the corresponding section
  3. `knowledge update` to rebuild index
  4. Mark entry `Status: done`
  5. Cross-session pattern recognition: scan session-summaries — same topic ≥ 3 times → distill into a KB entry and mark done
- **don't**: Do not modify skill files, assign skill attribution, or re-write content that already exists and is consistent.

## How much

- **do**: Consume all pending entries each run — no leftovers. On contradiction, latest user correction wins.
- **don't**: Do not promote session-summaries below the 3-hit threshold. Do not write vague or unverified knowledge to KB.
