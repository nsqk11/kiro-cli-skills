# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-04-07

### Added
- `install.sh` — one-click installer with dependency check
- `.data-template/` — initial data files for new installations
- `examples/agent-config.json` — ready-to-use agent configuration template
- `CONTRIBUTING.md` — contribution guidelines
- This `CHANGELOG.md`

### Changed
- Reorganized prompts: `capture.md`, `improve.md`, `learn.md` moved into `prompts/`
- Reorganized hooks: `activator.sh` → `hooks/agent-spawn.sh`, `error-detector.sh` → `hooks/post-tool-use.sh`, `stop-review.sh` → `hooks/stop.sh`
- Prompt filenames normalized to lowercase (`5W2H-prompt.md` → `5w2h.md`, `MECE-prompt.md` → `mece.md`)
- `SKILL.md` translated to English
- README updated: removed hardcoded paths, added compatibility section, path-agnostic install instructions
- `extract-skill.sh` now accepts any category (removed `common|work|personal` restriction)
- `improve.md` path references made generic

## [0.1.0] - 2026-04-02

### Added
- Initial release: Capture → Learn → Improve closed-loop system
- Three agent hooks: `agentSpawn`, `postToolUse`, `stop`
- 5W2H + MECE skill design framework
- `skill-router.sh` — auto-discovers skills via YAML frontmatter
- `extract-skill.sh` — scaffolds new skills
- `cleanup.sh` — archives old log entries
- `stats.sh` — learning statistics dashboard
