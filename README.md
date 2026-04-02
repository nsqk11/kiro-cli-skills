# self-improving-skill

A three-module closed-loop system for continuous self-improvement in Kiro AI assistants.

## What It Does

Captures errors, corrections, and discoveries during conversations → distills them into knowledge → feeds improvements back into skills. The system gets better the more you use it.

```
Capture → Learn → Improve
   ↑                  │
   └──────────────────┘
```

## Structure

```
├── SKILL.md           # Main skill definition (5W2H)
├── capture.md         # Event detection and logging
├── learn.md           # Knowledge distillation
├── improve.md         # Skill improvement and routing
├── prompts/
│   ├── 5W2H-prompt.md # 7-dimension analysis framework
│   └── MECE-prompt.md # Mutual exclusivity / exhaustiveness checks
└── scripts/
    ├── activator.sh       # agentSpawn hook — loads pending learnings
    ├── error-detector.sh  # postToolUse hook — auto-logs errors
    ├── stop-review.sh     # stop hook — session-end review
    ├── cleanup.sh         # archives done LOG entries
    ├── skill-router.sh    # auto-discovers skills via frontmatter
    ├── extract-skill.sh   # scaffolds new skills
    └── stats.sh           # learning statistics
```

## Prompts

The `prompts/` directory contains reusable analysis frameworks:

- **5W2H-prompt.md** — 7 dimensions (Why, What, Who, When, Where, How, How much) with do/don't for each. All skills follow this structure.
- **MECE-prompt.md** — Independence and exhaustiveness checks for any classification or decomposition.

Other skills reference these prompts via GitHub URL:
```markdown
规则参考：[5W2H](https://github.com/nsqk11/self-improving-skill/blob/main/prompts/5W2H-prompt.md) | [MECE](https://github.com/nsqk11/self-improving-skill/blob/main/prompts/MECE-prompt.md)
```

## Usage

1. Copy into `$KIRO_HOME/skills/common/self-improving/`
2. Hook scripts auto-activate via Kiro's agent hooks (agentSpawn, postToolUse, stop)
3. The skill-router auto-discovers all skills via `SKILL.md` frontmatter

## Skill Design Standard

All skills must follow:
- [5W2H](prompts/5W2H-prompt.md) 7-dimension structure
- [MECE](prompts/MECE-prompt.md) between dimensions
- do/don't for each dimension
- Instruction-style writing for AI execution, not human documentation

## License

MIT
