#!/bin/bash
# kiro-cli-skills — Installer
# Usage: ./install.sh [target-directory]
#   Default target: ~/.kiro/skills/kiro-cli-skills
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
[ ! -t 1 ] && GREEN='' && YELLOW='' && RED='' && NC=''

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-${KIRO_HOME:-$HOME/.kiro}/skills/kiro-cli-skills}"

printf "${YELLOW}kiro-cli-skills Installer${NC}\n\n"
printf "Source:  %s\n" "$SRC_DIR"
printf "Target:  %s\n\n" "$TARGET"

# Check dependencies
MISSING=""
for cmd in bash jq grep sed awk; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
  printf "${RED}Missing required tools:%s${NC}\n" "$MISSING"
  exit 1
fi

mkdir -p "$TARGET"

# Copy root files
for item in README.md LICENSE CONTRIBUTING.md install.sh .gitignore; do
  [ -e "$SRC_DIR/$item" ] && cp -f "$SRC_DIR/$item" "$TARGET/"
done

# Install each skill directory
for skill_dir in "$SRC_DIR"/*/; do
  skill="$(basename "$skill_dir")"
  # Skip hidden dirs
  [[ "$skill" == .* ]] && continue
  [ -f "$skill_dir/SKILL.md" ] || continue

  printf "Installing skill: %s\n" "$skill"
  mkdir -p "$TARGET/$skill"

  # Copy all skill files except .data and .git
  find "$skill_dir" -mindepth 1 -maxdepth 1 -not -name '.data' -not -name '.git' | while read -r item; do
    cp -rf "$item" "$TARGET/$skill/"
  done

  # Initialize .data from template if exists
  if [ -d "$skill_dir/data-template" ]; then
    mkdir -p "$TARGET/$skill/.data"
    for f in "$skill_dir/data-template"/*; do
      [ -e "$f" ] || continue
      base="$(basename "$f")"
      [ -e "$TARGET/$skill/.data/$base" ] || cp -f "$f" "$TARGET/$skill/.data/$base"
    done
  fi
done

# Set executable permissions
find "$TARGET" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

printf "\n${GREEN}✅ Installed to %s${NC}\n\n" "$TARGET"
printf "Next steps:\n"
printf "  1. Add skills + hooks to your agent config\n"
printf "  2. See each skill's README for configuration details\n"
