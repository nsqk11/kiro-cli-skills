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
- 🪝 **Hook-driven** — Activates via Kiro's `agentSpawn`, `postToolUse`, `stop` hooks
- 🧩 **Modular** — Three modules with strict separation of concerns
- 📊 **Pattern detection** — Recurring issues (≥ 3 hits) auto-surface as skill improvements
- 🗂️ **Skill router** — Auto-discovers all skills via YAML frontmatter scanning

## Quick Start

### Install

```bash
git clone https://github.com/nsqk11/self-improving-skill.git
cd self-improving-skill
bash install.sh              # installs to ~/.kiro/skills/self-improving
```

Or specify a custom path:

```bash
bash install.sh /path/to/your/target
```

### Configure

Copy [`examples/agent-config.json`](examples/agent-config.json) into your agent config and replace `<SKILL_PATH>` with the install path:

```jsonc
{
  "resources": [
    "skill://<SKILL_PATH>/SKILL.md",
    "file://<SKILL_PATH>/.data/knowledge.md"
  ],
  "hooks": {
    "agentSpawn":   [{ "command": "<SKILL_PATH>/hooks/agent-spawn.sh" }],
    "postToolUse":  [{ "command": "<SKILL_PATH>/hooks/post-tool-use.sh" }],
    "stop":         [{ "command": "<SKILL_PATH>/hooks/stop.sh" }]
  }
}
```

### Use

Start a Kiro session — the system activates automatically. No manual intervention needed.

## How It Works

```
Capture ──▶ log.md ──▶ Learn ──▶ knowledge.md ──▶ Improve ──▶ Skill files
   ▲                                                              │
   └──────────────────────────────────────────────────────────────┘
```

| Module | What it does | When |
|--------|-------------|------|
| [Capture](prompts/capture.md) | Detects events (errors, corrections, discoveries) and writes to `log.md` | During session, via `postToolUse` hook |
| [Learn](prompts/learn.md) | Distills pending log entries into structured knowledge | Session start, via `agentSpawn` hook |
| [Improve](prompts/improve.md) | Routes knowledge back into skill files | When a topic accumulates ≥ 3 hits |

See [SKILL.md](SKILL.md) for the full specification.

## Project Structure

```
self-improving/
├── SKILL.md                 # Skill definition (5W2H format)
├── install.sh               # Installer
├── prompts/                 # LLM prompt modules
│   ├── capture.md
│   ├── learn.md
│   ├── improve.md
│   ├── 5w2h.md              # Skill design framework
│   └── mece.md              # Exhaustiveness checks
├── hooks/                   # Kiro agent lifecycle hooks
│   ├── agent-spawn.sh
│   ├── post-tool-use.sh
│   └── stop.sh
├── scripts/                 # Utilities
│   ├── cleanup.sh           # Archives old log entries
│   ├── skill-router.sh      # Auto-discovers skills
│   ├── extract-skill.sh     # Scaffolds new skills
│   └── stats.sh             # Learning statistics
├── examples/
│   └── agent-config.json    # Agent config template
└── .data/                   # Runtime data (git-ignored)
    ├── log.md               # Event buffer
    ├── knowledge.md          # Distilled knowledge
    └── archive.md           # Archived entries
```

## Requirements

- Kiro CLI with hook support (`agentSpawn`, `postToolUse`, `stop`)
- Bash 4.0+
- `grep`, `sed`, `awk`
- macOS users: install `gnu-sed` via Homebrew

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 nsqk11
