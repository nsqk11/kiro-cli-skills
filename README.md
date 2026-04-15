# kiro-skills

A collection of custom skills for Kiro CLI.

## Skills

| Skill | Description |
|-------|-------------|
| [self-improving](self-improving/) | Closed-loop system (Capture → Learn → Improve) for continuous self-improvement |
| [docx-toolkit](docx-toolkit/) | JSON-based docx editing — extract to JSON, edit via change instructions, apply back to docx |

## Installation

```bash
git clone <repo-url> ~/.kiro/skills/kiro-cli-skills
```

## Recent Changes

- **self-improving**: Added `mem.sh clean` command (remove graduated-in-skill + stale done entries); added "Design/implementation" change control rule; removed `skill-router.sh` (no longer needed)

## Structure

```
kiro-cli-skills/
├── self-improving/
│   ├── SKILL.md
│   ├── README.md
│   ├── scripts/
│   │   ├── mem.sh              # Memory CLI (add/resolve/graduate/list/search/memory/clean)
│   │   ├── extract-skill.sh
│   │   └── tests/
│   │       └── mem-test.sh
│   ├── hooks/
│   │   ├── agent-spawn.sh
│   │   ├── post-tool-use.sh
│   │   ├── stop.sh
│   │   └── user-prompt-submit.sh
│   ├── prompts/
│   │   ├── 5w2h.md
│   │   └── mece.md
│   └── examples/
│       └── agent-config.json
├── docx-toolkit/
│   ├── SKILL.md
│   ├── README.md
│   └── scripts/
│       ├── scrape.py
│       └── patch.py
├── install.sh
├── CONTRIBUTING.md
├── README.md
└── LICENSE
```
