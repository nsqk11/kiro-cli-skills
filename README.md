# kiro-skills

Reusable skill modules for Kiro AI assistants.

## What are Skills?

Skills are modular, drop-in behavior packages for Kiro. Each skill is a self-contained directory with a `SKILL.md` defining its purpose, triggers, and rules using a structured 5W2H framework.

## Skills

| Skill | Description |
|-------|-------------|
| [analysis-method](skills/common/analysis-method/) | Structured thinking framework (5W2H) — meta-standard for skill design |
| [self-improving](skills/common/self-improving/) | Closed-loop self-improvement: Capture → Learn → Improve |

## Structure

```
skills/
└── common/
    ├── analysis-method/
    └── self-improving/
```

## Usage

Copy skills into `$KIRO_HOME/skills/`. The `skill-router.sh` script auto-discovers skills via `SKILL.md` frontmatter and activates them when user messages match their triggers.

## License

MIT
