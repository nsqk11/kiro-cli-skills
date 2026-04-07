<div align="center">

# 🧠 Self-Improving Skill

**A three-module closed-loop system for continuous self-improvement in Kiro AI assistants.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Kiro Skill](https://img.shields.io/badge/Kiro-Skill-blueviolet)](#)
[![Modules](https://img.shields.io/badge/Modules-3-green)](#architecture)
[![Hooks](https://img.shields.io/badge/Hooks-3-orange)](#hooks)

*Captures errors, corrections, and discoveries → distills them into knowledge → feeds improvements back into skills.*
*The system gets better the more you use it.*

</div>

---

## ✨ Highlights

| | Feature | Description |
|---|---------|-------------|
| 🔄 | **Closed-Loop** | Capture → Learn → Improve → repeat |
| 🪝 | **Hook-Driven** | Fully automatic via `agentSpawn`, `postToolUse`, `stop` hooks |
| 🧩 | **Modular** | Three modules with strict separation of concerns |
| 📊 | **Pattern Detection** | Recurring issues (Hits ≥ 3) auto-surface as skill candidates |
| 🗂️ | **Skill Router** | Auto-discovers all skills via YAML frontmatter |
| 📐 | **5W2H + MECE** | Standardized skill design framework |

---

## 🏗️ Architecture

```
                    ┌─────────────────────────────────────────┐
                    │          Self-Improving System           │
                    └─────────────────────────────────────────┘

                         ┌──────────────┐
                  ┌─────▶│   Capture    │──────┐
                  │      │  detect &    │      │
                  │      │  log events  │      ▼
            ┌─────┴──┐   └──────────────┘   ┌──────────┐
            │Improve │                      │ log.md  │
            │ refine │                      │ (buffer) │
            │ skills │                      └────┬─────┘
            └─────┬──┘                           │
                  ▲      ┌──────────────┐        │
                  │      │    Learn     │◀───────┘
                  └──────│  distill to  │
                         │  knowledge   │
                         └──────────────┘
```

### Module Responsibilities

> [!NOTE]
> Each module has a single responsibility. They communicate exclusively through `log.md` and the knowledge base.

| Module | Input | Output | Responsibility |
|--------|-------|--------|----------------|
| [**Capture**](prompts/capture.md) | Conversation events | `log.md` entries | Detect & record events (errors, corrections, discoveries) |
| [**Learn**](prompts/learn.md) | `log.md` pending entries | Knowledge base | Distill events into structured, searchable knowledge |
| [**Improve**](prompts/improve.md) | KB entries with skill tags | Skill files | Route knowledge back into skills, create new skills |

---

## 🪝 Hooks

The system is fully automated through Kiro's agent hook mechanism:

```
Session Start                During Session              Session End
     │                            │                          │
     ▼                            ▼                          ▼
┌────────────┐            ┌────────────────┐         ┌────────────┐
│agent-spawn │            │post-tool-use   │         │  stop      │
│   .sh      │            │     .sh        │         │    .sh     │
└────┬───────┘            └──────┬─────────┘         └─────┬──────┘
     │                           │                         │
     ├─ Load pending LOGs        ├─ Auto-detect errors     ├─ Session review
     ├─ Inject skill-router      │  from tool output       ├─ Capture insights
     └─ Trigger Learn            └─ Write to log.md        └─ Auto-cleanup
```

| Hook | Script | Trigger | Action |
|------|--------|---------|--------|
| `agentSpawn` | `hooks/agent-spawn.sh` | Session start | Load pending LOGs, build skill-router, trigger Learn |
| `postToolUse` | `hooks/post-tool-use.sh` | After each tool call | Auto-detect and log genuine errors |
| `stop` | `hooks/stop.sh` | Session end | Prompt session-end review + auto-cleanup |

---

## 📁 Project Structure

```
self-improving/
├── 📄 SKILL.md                    # Main skill definition (5W2H structure)
├── 📄 README.md
├── 📄 LICENSE
│
├── 📂 prompts/                    # All LLM-consumed content
│   ├── 📄 capture.md              # Event detection and logging rules
│   ├── 📄 learn.md                # Knowledge distillation rules
│   ├── 📄 improve.md              # Skill improvement and routing rules
│   ├── 📄 5w2h.md                 # 7-dimension analysis framework
│   └── 📄 mece.md                 # Mutual exclusivity / exhaustiveness checks
│
├── 📂 hooks/                      # Agent lifecycle hooks
│   ├── 🔧 agent-spawn.sh         # agentSpawn hook — loads pending learnings
│   ├── 🔧 post-tool-use.sh       # postToolUse hook — auto-logs errors
│   └── 🔧 stop.sh                # stop hook — session-end review + auto-cleanup
│
├── 📂 scripts/                    # Tool scripts + shared libs
│   ├── 🔧 cleanup.sh             # Archives done LOG entries (>30)
│   ├── 🔧 extract-skill.sh       # Scaffolds new skills
│   ├── 🔧 skill-router.sh        # Auto-discovers skills via frontmatter
│   └── 🔧 stats.sh               # Learning statistics dashboard
│
├── 📂 .data/                      # Personal data (git-ignored)
│   ├── 📄 log.md                  # Event buffer (pending / done entries)
│   ├── 📄 archive.md              # Archived done entries
│   ├── 📄 knowledge.md            # Distilled knowledge
│   ├── 📄 dedup-counts.txt        # Dedup hit counters
│   ├── 📄 review-state.json       # Periodic review tracker
│   └── 📄 hook-state.txt          # Hook runtime state
```

---

## 🔍 Event Types

Capture detects a wide range of events, each tagged with a type:

| Type | Trigger |
|------|---------|
| `error` | Command or tool execution fails |
| `correction` | User corrects the assistant |
| `knowledge-gap` | Knowledge was wrong or outdated |
| `improvement` | Better approach discovered |
| `feature-request` | User requests missing capability |
| `decision` | Design or architecture decision made |
| `convention` | Naming, format, or process convention established |
| `workflow` | Task processing pattern observed |
| `user-pattern` | User communication pattern detected |
| `gotcha` | Non-obvious pitfall found |
| `environment` | Environment config or limitation hit |
| `deprecation` | Deprecated functionality referenced |

---

## 📐 Skill Design Standard

All skills created or improved by this system follow a unified standard:

```
┌─────────────────────────────────────────────┐
│              5W2H Framework                  │
├──────────┬──────────────────────────────────┤
│  Why     │  Purpose and non-purpose         │
│  What    │  Scope and boundaries            │
│  Who     │  Actors and responsibilities     │
│  When    │  Triggers and conditions         │
│  Where   │  I/O paths and data flow         │
│  How     │  Step-by-step procedure          │
│  How much│  Thresholds and limits           │
├──────────┴──────────────────────────────────┤
│  ✅ do / ❌ don't for each dimension        │
│  📐 MECE between dimensions                │
│  🤖 Instruction-style for AI execution     │
└─────────────────────────────────────────────┘
```

- [5W2H Prompt](prompts/5w2h.md) — 7 dimensions with do/don't for each
- [MECE Prompt](prompts/mece.md) — Independence and exhaustiveness checks

---

## 🚀 Quick Start

### 1. Install the skill

```bash
cp -rf self-improving/ $KIRO_HOME/skills/common/self-improving/
mkdir -p $KIRO_HOME/skills/common/self-improving/.data
```

### 2. Configure agent hooks

Add the following to your agent JSON config (e.g. `$KIRO_HOME/agents/your-agent.json`):

```jsonc
{
  "name": "your-agent",
  // ... other fields ...

  "resources": [
    "skill://$KIRO_HOME/skills/common/self-improving/SKILL.md",
    "file://$KIRO_HOME/skills/common/self-improving/.data/knowledge.md"
  ],

  "hooks": {
    "agentSpawn": [
      {
        "command": "$KIRO_HOME/skills/common/self-improving/hooks/agent-spawn.sh",
        "description": "Load pending log entries into context"
      }
    ],
    "postToolUse": [
      {
        "command": "$KIRO_HOME/skills/common/self-improving/hooks/post-tool-use.sh",
        "description": "Detect errors from any tool and remind to log"
      }
    ],
    "stop": [
      {
        "command": "$KIRO_HOME/skills/common/self-improving/hooks/stop.sh",
        "description": "Trigger session-end review"
      }
    ]
  }
}
```

> [!IMPORTANT]
> Replace `$KIRO_HOME` with your actual Kiro root path (e.g. `~/.kiro`).

### 3. Done

The `skill-router.sh` auto-discovers all skills by scanning `SKILL.md` frontmatter — no additional routing config needed.

---

## 📊 Data Flow

```
  Conversation Events
         │
         ▼
  ┌──────────────┐     ┌─────────────────────┐
  │   Capture    │────▶│  .data/log.md        │
  │              │     │  (event buffer)      │
  └──────────────┘     └──────────┬──────────┘
                                  │
                                  ▼
                       ┌──────────────────────┐
                       │       Learn          │
                       │  (next session start)│
                       └──────────┬───────────┘
                                  │
                                  ▼
                       ┌──────────────────────┐     ┌──────────────────┐
                       │  .data/              │────▶│     Improve      │
                       │  knowledge.md        │     │  (≥3 hits →      │
                       └──────────────────────┘     │   update skill)  │
                                                    └────────┬─────────┘
                                                             │
                                                             ▼
                                                    ┌──────────────────┐
                                                    │  Skill Files     │
                                                    │  (SKILL.md)      │
                                                    └──────────────────┘
```

---

## ⚙️ Thresholds & Limits

| Parameter | Value | Description |
|-----------|-------|-------------|
| Pending load limit | 20 entries | Max entries loaded per `agentSpawn` |
| Skill creation threshold | ≥ 3 hits | Same topic must recur 3+ times |
| Skill update threshold | ≥ 2 corrections | User corrects same behavior 2+ times |
| Archive trigger | > 30 entries | `cleanup.sh` archives done entries |
| Periodic review | 20 sessions / 7 days | Whichever comes first |

---

## 🛡️ Change Control

| Change Type | Examples | Action |
|-------------|----------|--------|
| **Minor** ✅ | Add tip, fix wording, add example | Auto-apply, notify user |
| **Major** ⚠️ | New/delete skill, change triggers, restructure | Propose first, wait for confirmation |

---

## 📄 License

[MIT](LICENSE) © 2026 nsqk11
