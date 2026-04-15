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
| **Capture** | Detects errors, corrections, discoveries → adds to `mem.json` | During session via `post-tool-use` and `user-prompt-submit` hooks |
| **Learn** | Reviews pending entries, resolves and graduates mature ones | Session start (tiered: ≤5 silent, 6-15 suggest, >15 mandatory) |
| **Improve** | Routes graduated knowledge back into skill files | When a topic accumulates ≥ 3 hits |

Entry lifecycle: `open → done → graduated`

## Setup

Hook scripts use `@hook` / `@priority` / `@description` annotations. The root-level `hooks/dispatch.sh` discovers and runs them automatically.

Agent config only needs the dispatcher:

```jsonc
{
  "resources": [
    "file://<SKILL_PATH>/SKILL.md"
  ],
  "hooks": {
    "agentSpawn":        [{ "command": "<REPO_ROOT>/hooks/dispatch.sh agent-spawn" }],
    "userPromptSubmit":  [{ "command": "<REPO_ROOT>/hooks/dispatch.sh user-prompt-submit" }],
    "postToolUse":       [{ "command": "<REPO_ROOT>/hooks/dispatch.sh post-tool-use" }],
    "stop":              [{ "command": "<REPO_ROOT>/hooks/dispatch.sh stop" }]
  }
}
```

## Hook Scripts

| Script | Hook | Priority | Description |
|--------|------|----------|-------------|
| `inject-context.py` | agent-spawn | 10 | SKILL_DIR + proactive-agent prompt |
| `load-memory.py` | agent-spawn | 20 | Graduated memory + pending open entries |
| `check-review.py` | agent-spawn | 30 | Periodic review reminder |
| `inject-capture.py` | user-prompt-submit | 10 | Proactive-agent + capture-check directives |
| `log-error.py` | post-tool-use | 10 | Auto-log tool errors |
| `session-review.py` | stop | 10 | Session-end review prompt |

## CLI

```bash
python3.12 scripts/memory.py add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
python3.12 scripts/memory.py resolve  -i ID [-r "resolution"]
python3.12 scripts/memory.py graduate -i ID -S "section" [-k "skill-name"]
python3.12 scripts/memory.py list     [--status S] [--skill S] [--type T]
python3.12 scripts/memory.py search   -q "term"
python3.12 scripts/memory.py memory
python3.12 scripts/memory.py clean    [--apply]
```

See [SKILL.md](SKILL.md) for the full specification.
