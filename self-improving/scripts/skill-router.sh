#!/bin/bash
# Self-Improving — Skill Router
# Scans all SKILL.md frontmatter, outputs routing table for LLM context
set -euo pipefail

SKILLS_ROOT="${KIRO_HOME:-$HOME/.kiro}/skills"
SKIP="self-improving"

printf '<skill-router>\n'
printf 'Auto-loaded routing table. When user message matches triggers, fs_read the SKILL.md path.\n\n'

for file in "$SKILLS_ROOT"/*/SKILL.md "$SKILLS_ROOT"/*/*/SKILL.md "$SKILLS_ROOT"/*/*/*/SKILL.md; do
  [ -f "$file" ] || continue
  awk -v file="$file" -v skip="$SKIP" '
    BEGIN { in_fm=0; name=""; desc=""; triggers="" }
    NR==1 && /^---$/ { in_fm=1; next }
    in_fm && /^---$/ { in_fm=0; next }
    in_fm && /^name:/ { name=$0; sub(/^name: */, "", name); gsub(/"/, "", name) }
    in_fm && /^description:/ { desc=$0; sub(/^description: */, "", desc); gsub(/"/, "", desc) }
    in_fm && /^  - / { t=$0; sub(/^  - */, "", t); gsub(/"/, "", t); triggers = triggers ? triggers ", " t : t }
    END {
      if (name != skip && name != "")
        printf "- **%s**: %s\n  triggers: [%s]\n  path: %s\n", name, desc, triggers, file
    }
  ' "$file"
done

printf '</skill-router>\n'
