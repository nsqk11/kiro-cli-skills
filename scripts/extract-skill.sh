#!/bin/bash
# Skill Extraction Helper — creates skill scaffold from template
# Usage: ./extract-skill.sh <category> <skill-name> [--dry-run]
set -euo pipefail

SKILLS_ROOT="${KIRO_HOME:-$HOME/.kiro}/skills"

# Color detection
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

usage() {
  cat << EOF
Usage: $(basename "$0") <category> <skill-name> [--dry-run]

Categories: common, work, personal
Skill name: lowercase, hyphens only (e.g. docker-fixes)

Examples:
  $(basename "$0") common api-patterns
  $(basename "$0") work nds-review --dry-run
EOF
  exit 1
}

[ $# -lt 2 ] && usage

CATEGORY="$1"; SKILL_NAME="$2"; DRY_RUN=false
[ "${3:-}" = "--dry-run" ] && DRY_RUN=true

# Validate
case "$CATEGORY" in common|work|personal) ;; *) printf "${RED}Invalid category: %s${NC}\n" "$CATEGORY"; usage ;; esac
[[ "$SKILL_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { printf "${RED}Invalid name. Use lowercase + hyphens.${NC}\n"; exit 1; }

SKILL_PATH="$SKILLS_ROOT/$CATEGORY/$SKILL_NAME"
[ -d "$SKILL_PATH" ] && { printf "${RED}Already exists: %s${NC}\n" "$SKILL_PATH"; exit 1; }

TITLE=$(printf '%s' "$SKILL_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

CONTENT="---
name: $SKILL_NAME
description: \"[TODO]\"
triggers:
  - \"[TODO]\"
---

# $TITLE

## Why

- **do**: [TODO]
- **don't**: [TODO]

## What

- **do**: [TODO]
- **don't**: [TODO]

## Who

- **do**: [TODO]
- **don't**: [TODO]

## When

- **do**: [TODO]
- **don't**: [TODO]

## Where

- **do**: [TODO]
- **don't**: [TODO]

## How

- **do**: [TODO]
- **don't**: [TODO]

## How much

- **do**: [TODO]
- **don't**: [TODO]"

if $DRY_RUN; then
  printf "${YELLOW}[DRY RUN]${NC} Would create:\n"
  printf "  %s/SKILL.md\n\n" "$SKILL_PATH"
  printf '%s\n' "$CONTENT"
else
  mkdir -p "$SKILL_PATH"
  printf '%s\n' "$CONTENT" > "$SKILL_PATH/SKILL.md"
  printf "${GREEN}✅ Created${NC} %s/SKILL.md\n\n" "$SKILL_PATH"
  printf 'Next: edit SKILL.md, fill TODOs, run quality check.\n'
fi
