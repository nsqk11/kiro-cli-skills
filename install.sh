#!/bin/bash
# kiro-cli-skills — Installer
# Usage: bash install.sh [target-directory]
#   Default target: ~/.kiro/skills/kiro-cli-skills
set -euo pipefail

# --- Config ---
PYTHON="python3.12"
REQUIRED_CMDS=(bash jq "$PYTHON")

# --- Colors (disabled if not a terminal) ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-${KIRO_HOME:-$HOME/.kiro}/skills/kiro-cli-skills}"

# --- Functions ---

check_commands() {
  local missing=""
  for cmd in "${REQUIRED_CMDS[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
  done
  if [ -n "$missing" ]; then
    printf "${RED}Missing required tools:%s${NC}\n" "$missing"
    exit 1
  fi
}

install_python_deps() {
  # module:package — module is the import name, package is the pip name
  local deps=("docx:python-docx")
  local missing=""
  for dep in "${deps[@]}"; do
    local mod="${dep%%:*}" pkg="${dep##*:}"
    $PYTHON -c "import $mod" 2>/dev/null || missing="$missing $pkg"
  done
  if [ -n "$missing" ]; then
    printf "Installing Python packages:%s\n" "$missing"
    $PYTHON -m pip install --quiet $missing
  fi
}

is_skill_dir() {
  # A skill directory contains SKILL.md
  [ -f "$1/SKILL.md" ]
}

install_root_files() {
  mkdir -p "$TARGET"
  # Copy everything at root level except skill dirs, hidden dirs, and .git
  find "$SRC_DIR" -maxdepth 1 -mindepth 1 \
    -not -name '.git' -not -name '.data' -not -name '.*' \
    | while read -r item; do
    name="$(basename "$item")"
    # Skip skill directories (handled separately)
    [ -d "$item" ] && is_skill_dir "$item" && continue
    cp -rf "$item" "$TARGET/"
  done
}

install_skill() {
  local skill_dir="$1"
  local skill="$(basename "$skill_dir")"

  printf "  Installing skill: %s\n" "$skill"
  mkdir -p "$TARGET/$skill"

  # Copy all files except runtime data
  find "$skill_dir" -mindepth 1 -maxdepth 1 \
    -not -name '.data' -not -name '.git' -not -name '__pycache__' \
    | while read -r item; do
    cp -rf "$item" "$TARGET/$skill/"
  done

  # Initialize .data from template (don't overwrite existing)
  if [ -d "$skill_dir/data-template" ]; then
    mkdir -p "$TARGET/$skill/.data"
    for f in "$skill_dir/data-template"/*; do
      [ -e "$f" ] || continue
      local base="$(basename "$f")"
      [ -e "$TARGET/$skill/.data/$base" ] || cp -f "$f" "$TARGET/$skill/.data/$base"
    done
  fi
}

install_skills() {
  printf "Installing skills:\n"
  for skill_dir in "$SRC_DIR"/*/; do
    is_skill_dir "$skill_dir" && install_skill "$skill_dir"
  done
}

# --- Main ---

printf "${YELLOW}kiro-cli-skills Installer${NC}\n\n"
printf "Source:  %s\n" "$SRC_DIR"
printf "Target:  %s\n\n" "$TARGET"

check_commands
install_python_deps
install_root_files
install_skills

find "$TARGET" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

printf "\n${GREEN}✅ Installed to %s${NC}\n\n" "$TARGET"
printf "Next steps:\n"
printf "  1. Add hooks to your agent config (see README.md)\n"
printf "  2. See each skill's README for details\n"
