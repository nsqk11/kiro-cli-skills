<div align="center">

# ⚡ kiro-cli-skills

**Supercharge your [Kiro CLI](https://github.com/kirolabs/kiro) with custom skills.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash_4%2B-green.svg)](#prerequisites)
[![Skills](https://img.shields.io/badge/Skills-2-blueviolet.svg)](#skills)

*A modular collection of AI agent skills — each one a self-contained unit of capability that plugs into Kiro's skill system.*

</div>

---

## 🧩 Skills

### [Self-Improving](self-improving/)

A closed-loop learning system that makes your Kiro agent get smarter over time.

- **Capture** errors, corrections, and discoveries automatically via hooks
- **Learn** by reviewing and graduating entries at session start
- **Improve** by routing mature knowledge back into skill files

Single-file data store (`mem.json`) with full CLI. Hook-driven — activates automatically, no manual intervention.

### [Docx Toolkit](docx-toolkit/)

JSON-based surgical editing for `.docx` files — no Word required.

- **Scrape** — extract document body into flat JSON with stable indices
- **Patch** — apply targeted changes back to the original docx XML

Works with any `.docx`: reports, specs, templates. Preserves formatting, styles, and structure.

---

## 📋 Prerequisites

- [Kiro CLI](https://github.com/kirolabs/kiro) installed
- Bash ≥ 4.0
- `jq` ≥ 1.6
- Python 3.8+ (for docx-toolkit)

## 🚀 Installation

```bash
git clone https://github.com/nsqk11/kiro-cli-skills.git
cd kiro-cli-skills
bash install.sh                # → ~/.kiro/skills/kiro-cli-skills
```

## 📁 Structure

```
kiro-cli-skills/
├── hooks/
│   └── dispatch.sh         Hook dispatcher (scans @hook annotations)
├── self-improving/         Closed-loop learning system
│   ├── scripts/            memory.py, hook scripts, _common.py
│   ├── prompts/            proactive-agent.md, capture-check.md
│   └── examples/           agent config template
├── docx-toolkit/           docx ↔ JSON editing
│   └── scripts/            scrape.py, patch.py
├── prompts/                Shared skill design frameworks (5W2H, MECE)
├── install.sh
└── LICENSE
```

## 🛠️ Skill Design

All skills follow the **[5W2H](prompts/5w2h.md)** framework with **[MECE](prompts/mece.md)** coverage:

> **Why** · **What** · **Who** · **When** · **Where** · **How** · **How much**
>
> Each dimension has explicit `do` and `don't` boundaries.

See each skill's `SKILL.md` for the full specification.

## 📄 License

[MIT](LICENSE)
