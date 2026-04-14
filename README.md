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

## Structure

```
kiro-skills/
├── self-improving/     # Memory, learning, skill improvement
│   ├── SKILL.md
│   ├── scripts/
│   └── hooks/
├── docx-toolkit/       # docx ↔ JSON editing toolkit
│   ├── SKILL.md
│   └── scripts/
├── README.md
└── LICENSE
```
