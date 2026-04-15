#!/usr/bin/env python3.12
# @hook agent-spawn
# @priority 10
# @description Inject SKILL_DIR and proactive-agent prompt
"""Output static context block at session start."""

from _common import SKILL_DIR, read_prompt


def main() -> None:
    prompt = read_prompt("proactive-agent.md")
    print(f"<self-improving-context>\nSKILL_DIR={SKILL_DIR}\n</self-improving-context>")
    print(f"\n<proactive-agent>\n{prompt}\n</proactive-agent>")


if __name__ == "__main__":
    main()
