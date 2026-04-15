<div align="center">

# ⚡ kiro-cli-skills

**Supercharge your [Kiro CLI](https://github.com/kirolabs/kiro) with custom skills.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.12-blue.svg)](#prerequisites)
[![Skills](https://img.shields.io/badge/Skills-2-blueviolet.svg)](#-skills)

*A modular collection of AI agent skills — each skill is a self-contained unit that plugs into Kiro's skill system via a unified hook dispatcher.*

</div>

---

## 🧩 Skills

### [Self-Improving](self-improving/)

A closed-loop learning system that makes your Kiro agent get smarter over time.

- **Capture** errors, corrections, and discoveries automatically via hooks
- **Learn** by reviewing and graduating entries at session start
- **Improve** by routing mature knowledge back into skill files

Single-file data store (`mem.json`) with full Python CLI. Hook-driven — activates automatically, no manual intervention.

### [Docx Toolkit](docx-toolkit/)

JSON-based surgical editing for `.docx` files — no Word required.

- **Scrape** — extract document body into flat JSON with stable indices
- **Patch** — apply targeted changes back to the original docx XML

Works with any `.docx`: reports, specs, templates. Preserves formatting, styles, and structure.

---

## 🔌 Hook Dispatcher

All hooks are managed by a single dispatcher (`hooks/dispatch.sh`). Skills register their hook scripts using three annotations:

```python
# @hook agent-spawn
# @priority 10
# @description Load memory and pending entries
```

All three annotations must be present — missing any one means the script is skipped.

The dispatcher scans the repo for matching scripts, sorts by priority, and executes them in order. Agent config only needs one entry per hook type:

```jsonc
{
  "hooks": {
    "agentSpawn":        [{ "command": "bash hooks/dispatch.sh agent-spawn" }],
    "userPromptSubmit":  [{ "command": "bash hooks/dispatch.sh user-prompt-submit" }],
    "preToolUse":        [{ "command": "bash hooks/dispatch.sh pre-tool-use" }],
    "postToolUse":       [{ "command": "bash hooks/dispatch.sh post-tool-use" }],
    "stop":              [{ "command": "bash hooks/dispatch.sh stop" }]
  }
}
```

Adding a new hook script to any skill is zero-config — just add the annotations and the dispatcher picks it up.

---

## 📋 Prerequisites

- [Kiro CLI](https://github.com/kirolabs/kiro)
- Python 3.12+
- Bash ≥ 4.0
- `jq` ≥ 1.6

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
│   └── dispatch.sh             Unified hook dispatcher
├── self-improving/
│   ├── SKILL.md                Skill definition (5W2H)
│   ├── scripts/
│   │   ├── memory.py           Data CLI (add/resolve/graduate/list/search/clean)
│   │   ├── _common.py          Shared utilities for hook scripts
│   │   ├── inject-context.py   @hook agent-spawn     p10
│   │   ├── load-memory.py      @hook agent-spawn     p20
│   │   ├── check-review.py     @hook agent-spawn     p30
│   │   ├── inject-capture.py   @hook user-prompt-submit p10
│   │   ├── log-error.py        @hook post-tool-use   p10
│   │   └── session-review.py   @hook stop            p10
│   ├── prompts/                Injection templates (proactive-agent, capture-check)
│   └── examples/               Agent config template
├── docx-toolkit/
│   ├── SKILL.md
│   └── scripts/                scrape.py, patch.py
├── prompts/                    Shared design frameworks (5W2H, MECE)
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
