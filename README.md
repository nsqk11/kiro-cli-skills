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
- 🧩 **Single-file data store** — All entries in one `si.json`, managed by `si.sh` CLI
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
  "resources": [
    "skill://<SKILL_PATH>/SKILL.md"
  ],
  "hooks": {
    "agentSpawn":        [{ "command": "<SKILL_PATH>/hooks/agent-spawn.sh" }],
    "userPromptSubmit":  [{ "command": "<SKILL_PATH>/hooks/user-prompt-submit.sh" }],
    "postToolUse":       [{ "command": "<SKILL_PATH>/hooks/post-tool-use.sh" }],
    "stop":              [{ "command": "<SKILL_PATH>/hooks/stop.sh" }]
  }
}
```

### Use

Start a Kiro session — the system activates automatically. No manual intervention needed.

## How It Works

```
Capture ──▶ si.json (open) ──▶ Learn (done) ──▶ Graduate ──▶ Improve ──▶ Skill files
   ▲                                                                        │
   └────────────────────────────────────────────────────────────────────────┘
```

### Data Store

Single file `.data/si.json` managed by `scripts/si.sh`:

```bash
bash scripts/si.sh add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
bash scripts/si.sh resolve  -i ID [-r "resolution"]
bash scripts/si.sh graduate -i ID -S "section" [-k "skill-name"]
bash scripts/si.sh list     [--status S] [--skill S] [--type T]
bash scripts/si.sh search   -k "keyword"
bash scripts/si.sh memory   # graduated + skill:none → context loading
```

### Modules

| Module | What it does | When |
|--------|-------------|------|
| **Capture** | Detects events (errors, corrections, discoveries) and adds to `si.json` | During session, via `postToolUse` and `userPromptSubmit` hooks |
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
│   ├── si.sh                # Data store CLI (add/resolve/graduate/list/search/memory)
│   ├── skill-router.sh      # Auto-discovers skills via frontmatter
│   ├── extract-skill.sh     # Scaffolds new skills
│   └── tests/
│       └── si-test.sh       # si.sh test suite (18 assertions)
├── examples/
│   └── agent-config.json    # Agent config template
└── .data/                   # Runtime data (git-ignored)
    ├── si.json              # Single data store
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
