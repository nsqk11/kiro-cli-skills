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
- 🧩 **Single-file spec** — All three modules defined in one SKILL.md (5W2H format), always in context
- 📊 **Pattern detection** — Recurring issues (≥ 3 hits) auto-surface as skill improvements
- 🗂️ **Skill router** — Auto-discovers all skills via YAML frontmatter scanning
- 🔁 **Knowledge lifecycle** — Entries flow through `new → active → promoted → archived` with auto-compaction
- 📋 **Session handoff** — Unfinished items captured at session end for seamless continuation

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
Capture ──▶ log.md ──▶ Learn ──▶ knowledge.md ──▶ Improve ──▶ Skill files
   ▲                                                              │
   └──────────────────────────────────────────────────────────────┘
```

All three modules are defined in [SKILL.md](SKILL.md) under the `How` section:

| Module | What it does | When |
|--------|-------------|------|
| **Capture** | Detects events (errors, corrections, discoveries) and writes to `log.md` | During session, via `postToolUse` and `userPromptSubmit` hooks |
| **Learn** | Distills pending log entries into structured knowledge | Session start, via `agentSpawn` hook |
| **Improve** | Routes knowledge back into skill files | When a topic accumulates ≥ 3 hits |

### Knowledge Lifecycle

```
new → active → promoted → archived
```

- **new**: Just distilled from LOG
- **active**: Attributed to a skill (`[skill: <name>]`)
- **promoted**: Merged into the skill's SKILL.md
- **archived**: Superseded, obsolete, or compacted

### Skill Quality Dimensions

New skills are checked against 5 dimensions: trigger coverage (EN/ZH), scope boundary, actionability, testability, and minimality.

See [SKILL.md](SKILL.md) for the full specification.

## Project Structure

```
self-improving/
├── SKILL.md                 # Skill definition — all 3 modules in one file (5W2H)
├── install.sh               # Installer
├── prompts/                 # Shared frameworks
│   ├── 5w2h.md              # Skill design framework
│   └── mece.md              # Exhaustiveness checks
├── hooks/                   # Kiro agent lifecycle hooks
│   ├── agent-spawn.sh       # Loads pending logs, skill router, periodic review
│   ├── user-prompt-submit.sh # Detects correction signals
│   ├── post-tool-use.sh     # Auto-logs tool errors
│   └── stop.sh              # Session review & cleanup trigger
├── scripts/                 # Utilities
│   ├── lib.sh               # Shared patterns & functions
│   ├── cleanup.sh           # Archives old log entries & compacts KB
│   ├── skill-router.sh      # Auto-discovers skills via frontmatter
│   ├── extract-skill.sh     # Scaffolds new skills
│   └── stats.sh             # Learning statistics dashboard
├── examples/
│   └── agent-config.json    # Agent config template
└── .data/                   # Runtime data (git-ignored)
    ├── log.md               # Event buffer
    ├── knowledge.md          # Distilled knowledge
    ├── archive.md           # Archived entries
    └── review-state.json    # Periodic review tracker
```

## Requirements

- Kiro CLI with hook support (`agentSpawn`, `userPromptSubmit`, `postToolUse`, `stop`)
- Bash 4.0+
- `grep`, `sed`, `awk`
- macOS users: install `gnu-sed` via Homebrew

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 nsqk11
