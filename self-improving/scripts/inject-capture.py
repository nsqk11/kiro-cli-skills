#!/usr/bin/env python3.12
# @hook user-prompt-submit
# @priority 10
# @description Inject proactive-agent and capture-check on every user message
"""Read prompt templates and inject into user message context."""

import json
import sys

from _common import read_prompt


def main() -> None:
    event = json.loads(sys.stdin.read()) if not sys.stdin.isatty() else {}
    if not event.get("prompt"):
        return

    print(f"\n<proactive-agent>\n{read_prompt('proactive-agent.md')}\n</proactive-agent>")
    print(f"\n<capture-check>\n{read_prompt('capture-check.md')}\n</capture-check>")


if __name__ == "__main__":
    main()
