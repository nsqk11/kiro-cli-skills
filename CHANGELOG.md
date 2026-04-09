# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2026-04-09

### Changed
- Merge 3 separate module prompts (capture.md, learn.md, improve.md) into single SKILL.md
- Migrate data store from log.md/knowledge.md to unified `mem.json` + `mem.sh` CLI
- Rename `si.sh` → `mem.sh`
- Resource protocol: `skill://` → `file://` for SKILL.md (ensures auto-injection into context)
- Rename `.data-template/` → `data-template/`
- Remove unused `knowledge.md` from agent resources

### Fixed
- Isolate test data from production mem.json
- Replace sed with jq for review-state.json update in agent-spawn hook

## [0.3.0] - 2026-04-08

### Added
- `userPromptSubmit` hook for correction detection

### Changed
- Extract shared regex patterns and functions into lib.sh

## [0.2.0] - 2026-04-07

### Added
- `install.sh` — one-click installer with dependency check
- `data-template/` — initial data files for new installations
- `examples/agent-config.json` — ready-to-use agent configuration template
- `CONTRIBUTING.md` — contribution guidelines

### Changed
- Reorganize prompts and scripts into `hooks/` structure
- SKILL.md and README translated to English
- Path-agnostic install instructions (no hardcoded paths)
- `extract-skill.sh` accepts any category

### Fixed
- error-detector pipefail crash on grep no-match

## [0.1.0] - 2026-04-02

### Added
- Initial release: Capture → Learn → Improve closed-loop system
- Three agent hooks: `agentSpawn`, `postToolUse`, `stop`
- 5W2H + MECE skill design framework
- `skill-router.sh` — auto-discovers skills via YAML frontmatter
- `extract-skill.sh` — scaffolds new skills

### Changed
- Unified 5W2H structure with do/don't
- Move personal data to `.data/`, unify naming to kebab-case
