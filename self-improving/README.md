# Self-Improving

A closed-loop learning system for Kiro CLI agents. Captures events during sessions, distills them into knowledge, and feeds improvements back into skills.

## How It Works

```
Capture ──▶ mem.json (open) ──▶ Learn (done) ──▶ Graduate ──▶ Improve ──▶ Skill files
   ▲                                                                        │
   └────────────────────────────────────────────────────────────────────────┘
```

| Module | What | When |
|--------|------|------|
| **Capture** | Detects errors, corrections, discoveries → adds to `mem.json` | During session via `postToolUse` and `userPromptSubmit` hooks |
| **Learn** | Reviews pending entries, resolves and graduates mature ones | Session start (tiered: ≤5 silent, 6-15 suggest, >15 mandatory) |
| **Improve** | Routes graduated knowledge back into skill files | When a topic accumulates ≥ 3 hits |

Entry lifecycle: `open → done → graduated`

## Setup

Add to your agent config (see [example](examples/agent-config.json)):

```jsonc
{
  "resources": [
    "file://<SKILL_PATH>/SKILL.md"   // file:// for preload, not skill://
  ],
  "hooks": {
    "agentSpawn":        [{ "command": "<SKILL_PATH>/hooks/agent-spawn.sh" }],
    "userPromptSubmit":  [{ "command": "<SKILL_PATH>/hooks/user-prompt-submit.sh" }],
    "postToolUse":       [{ "command": "<SKILL_PATH>/hooks/post-tool-use.sh" }],
    "stop":              [{ "command": "<SKILL_PATH>/hooks/stop.sh" }]
  }
}
```

Use `file://` so the full SKILL.md is preloaded at session start. The `agentSpawn` hook injects runtime data (memory, pending logs, review reminders).

## CLI

```bash
bash scripts/mem.sh add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
bash scripts/mem.sh resolve  -i ID [-r "resolution"]
bash scripts/mem.sh graduate -i ID -S "section" [-k "skill-name"]
bash scripts/mem.sh list     [--status S] [--skill S] [--type T]
bash scripts/mem.sh search   -k "keyword"
bash scripts/mem.sh memory   # graduated + skill:none → context loading
bash scripts/mem.sh clean    [--apply]  # remove graduated-in-skill + done>7d
```

See [SKILL.md](SKILL.md) for the full specification (event types, graduation criteria, change control, skill discovery).
