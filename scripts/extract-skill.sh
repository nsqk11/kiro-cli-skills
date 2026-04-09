#!/bin/bash
# Skill Extraction Helper — creates skill scaffold from template
# Usage: ./extract-skill.sh <target-dir> <skill-name> [--dry-run]
set -euo pipefail

if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

usage() {
  cat << EOF
Usage: $(basename "$0") <target-dir> <skill-name> [--dry-run]

target-dir:  Parent directory where the skill folder will be created
skill-name:  Lowercase, hyphens only (e.g. docker-fixes)

Examples:
  $(basename "$0") ~/.kiro/skills api-patterns
  $(basename "$0") /opt/kiro/skills/work my-skill --dry-run
EOF
  exit 1
}

[ $# -lt 2 ] && usage

TARGET_DIR="$1"; SKILL_NAME="$2"; DRY_RUN=false
[ "${3:-}" = "--dry-run" ] && DRY_RUN=true

[[ "$SKILL_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { printf "${RED}Invalid name. Use lowercase + hyphens.${NC}\n"; exit 1; }

SKILL_PATH="$TARGET_DIR/$SKILL_NAME"
[ -d "$SKILL_PATH" ] && { printf "${RED}Already exists: %s${NC}\n" "$SKILL_PATH"; exit 1; }

TITLE=$(printf '%s' "$SKILL_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

CONTENT="---
name: $SKILL_NAME
description: \"[TODO]\"
triggers:
  - \"[TODO]\"
---

# $TITLE

Reference: [5W2H](5w2h.md) | [MECE](mece.md)

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
