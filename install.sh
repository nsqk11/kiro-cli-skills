#!/bin/bash
# Self-Improving Skill — Installer
# Usage: ./install.sh [target-directory]
#   Default target: ~/.kiro/skills/self-improving
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
[ ! -t 1 ] && GREEN='' && YELLOW='' && RED='' && NC=''

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-${KIRO_HOME:-$HOME/.kiro}/skills/self-improving}"

printf "${YELLOW}Self-Improving Skill Installer${NC}\n\n"
printf "Source:  %s\n" "$SRC_DIR"
printf "Target:  %s\n\n" "$TARGET"

# Check dependencies
MISSING=""
for cmd in bash grep sed awk; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
  printf "${RED}Missing required tools:%s${NC}\n" "$MISSING"
  exit 1
fi

# Copy skill files (exclude .data, .git)
mkdir -p "$TARGET"
for item in SKILL.md README.md LICENSE CONTRIBUTING.md CHANGELOG.md install.sh prompts hooks scripts examples; do
  [ -e "$SRC_DIR/$item" ] && cp -rf "$SRC_DIR/$item" "$TARGET/"
done

# Initialize .data from template
if [ -d "$SRC_DIR/data-template" ]; then
  mkdir -p "$TARGET/.data"
  for f in "$SRC_DIR/data-template"/*; do
    base="$(basename "$f")"
    [ -e "$TARGET/.data/$base" ] || cp -f "$f" "$TARGET/.data/$base"
  done
fi

# Ensure .gitignore
[ -f "$TARGET/.gitignore" ] || printf '.data/\n' > "$TARGET/.gitignore"

# Set executable permissions on scripts
chmod +x "$TARGET"/hooks/*.sh "$TARGET"/scripts/*.sh 2>/dev/null || true

printf "\n${GREEN}✅ Installed to %s${NC}\n\n" "$TARGET"
printf "Next steps:\n"
printf "  1. Add skill + hooks to your agent config (see examples/agent-config.json)\n"
printf "  2. Start a Kiro session — the system activates automatically\n"
