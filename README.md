<div align="center">

# 🧠 Self-Improving Skill

**A closed-loop system that makes your Kiro AI assistant learn from every session.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Kiro Skill](https://img.shields.io/badge/Kiro-Skill-blueviolet)](#)

Captures errors, corrections, and discoveries → distills them into knowledge → feeds improvements back into skills.

</div>

---

## Features

- 🔄 **Closed-loop learning** — Capture → Learn → Improve, fully automatic
- 🪝 **Hook-driven** — Activates via Kiro's `agentSpawn`, `userPromptSubmit`, `postToolUse`, `stop` hooks
- 🧩 **Single-file data store** — All entries in one `mem.json`, managed by `mem.sh` CLI
- 📊 **Pattern detection** — Recurring issues auto-surface as skill improvements
- 🗂️ **Skill router** — Auto-discovers all skills via YAML frontmatter scanning
- 🔁 **Entry lifecycle** — `open → done → graduated` with auto-dedup
- 📋 **Session handoff** — Unfinished items captured at session end for seamless continuation

## Quick Start

### Install

```bash
git clone https://github.com/nsqk11/self-improving-skill.git
cd self-improving-skill
bash install.sh              # installs to ~/.kiro/skills/self-improving
```

### Configure

Copy [`examples/agent-config.json`](examples/agent-config.json) into your agent config and replace `<SKILL_PATH>` with the install path:

```jsonc
{
  "hooks": {
    "agentSpawn":        [{ "command": "<SKILL_PATH>/hooks/agent-spawn.sh" }],
    "userPromptSubmit":  [{ "command": "<SKILL_PATH>/hooks/user-prompt-submit.sh" }],
    "postToolUse":       [{ "command": "<SKILL_PATH>/hooks/post-tool-use.sh" }],
    "stop":              [{ "command": "<SKILL_PATH>/hooks/stop.sh" }]
  }
}
```

> SKILL.md is not added to `resources`. The `agentSpawn` hook inlines SKILL.md content directly into the context, ensuring 100% reliable loading without requiring the agent to make a tool call.

### Use

Start a Kiro session — the system activates automatically. No manual intervention needed.

## How It Works

```
Capture ──▶ mem.json (open) ──▶ Learn (done) ──▶ Graduate ──▶ Improve ──▶ Skill files
   ▲                                                                        │
   └────────────────────────────────────────────────────────────────────────┘
```

### Data Store

Single file `.data/mem.json` managed by `scripts/mem.sh`:

```bash
bash scripts/mem.sh add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
bash scripts/mem.sh resolve  -i ID [-r "resolution"]
bash scripts/mem.sh graduate -i ID -S "section" [-k "skill-name"]
bash scripts/mem.sh list     [--status S] [--skill S] [--type T]
bash scripts/mem.sh search   -k "keyword"
bash scripts/mem.sh memory   # graduated + skill:none → context loading
```

### Modules

| Module | What it does | When |
|--------|-------------|------|
| **Capture** | Detects events (errors, corrections, discoveries) and adds to `mem.json` | During session, via `postToolUse` and `userPromptSubmit` hooks |
| **Learn** | Reviews pending entries, resolves and graduates mature ones | Session start, via `agentSpawn` hook |
| **Improve** | Routes graduated knowledge back into skill files | When a topic accumulates ≥ 3 hits |

### Entry Lifecycle

```
open → done → graduated
```

- **open**: Just captured, pending review
- **done**: Reviewed and resolved
- **graduated**: Distilled into persistent knowledge; `skill:none` entries loaded as memory at session start, skill-bound entries managed by their respective skills

See [SKILL.md](SKILL.md) for the full specification.

## Project Structure

```
self-improving/
├── SKILL.md                 # Skill definition — all 3 modules (5W2H)
├── install.sh               # Installer
├── prompts/                 # Shared frameworks
│   ├── 5w2h.md              # Skill design framework
│   └── mece.md              # Exhaustiveness checks
├── hooks/                   # Kiro agent lifecycle hooks
│   ├── agent-spawn.sh       # Loads memory + pending, skill router, periodic review
│   ├── user-prompt-submit.sh # Detects correction signals
│   ├── post-tool-use.sh     # Auto-logs tool errors
│   └── stop.sh              # Session review prompt
├── scripts/                 # Utilities
│   ├── mem.sh                # Data store CLI (add/resolve/graduate/list/search/memory)
│   ├── skill-router.sh      # Auto-discovers skills via frontmatter
│   ├── extract-skill.sh     # Scaffolds new skills
│   └── tests/
│       └── mem-test.sh       # mem.sh test suite (20 assertions)
├── examples/
│   └── agent-config.json    # Agent config template
└── .data/                   # Runtime data (git-ignored)
    ├── mem.json              # Single data store
    └── review-state.json    # Periodic review tracker
```

## Requirements

- Kiro CLI with hook support (`agentSpawn`, `userPromptSubmit`, `postToolUse`, `stop`)
- Bash 4.0+
- `jq` 1.6+

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 nsqk11
