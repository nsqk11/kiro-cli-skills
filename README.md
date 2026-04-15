# kiro-cli-skills

A collection of custom skills for [Kiro CLI](https://github.com/kirolabs/kiro).

## Skills

| Skill | Description |
|-------|-------------|
| [self-improving](self-improving/) | Closed-loop system (Capture → Learn → Improve) for continuous self-improvement |
| [docx-toolkit](docx-toolkit/) | JSON-based docx editing — extract to JSON, edit via change instructions, apply back to docx |

## Prerequisites

- bash ≥ 4.0
- jq
- [Kiro CLI](https://github.com/kirolabs/kiro) installed

## Installation

```bash
git clone https://github.com/nsqk11/kiro-cli-skills.git
cd kiro-cli-skills
bash install.sh            # installs to ~/.kiro/skills/kiro-cli-skills
```

## Quick Start

**self-improving** — add to your agent config (see [example](self-improving/examples/agent-config.json)), then start a Kiro session. The system activates automatically via hooks.

**docx-toolkit** — extract and patch docx files:

```bash
python3 docx-toolkit/scripts/scrape.py input.docx -o content.json
# edit content.json ...
python3 docx-toolkit/scripts/patch.py input.docx changes.json -o output.docx
```

## Structure

```
kiro-cli-skills/
├── self-improving/     # Memory, learning, skill improvement
│   ├── scripts/        # mem.sh, extract-skill.sh
│   ├── hooks/          # agent-spawn, post-tool-use, stop, user-prompt-submit
│   ├── prompts/        # 5w2h.md, mece.md
│   └── examples/       # agent-config.json
├── docx-toolkit/       # docx ↔ JSON editing toolkit
│   └── scripts/        # scrape.py, patch.py
├── install.sh
├── CONTRIBUTING.md
└── LICENSE
```

## License

[MIT](LICENSE)
