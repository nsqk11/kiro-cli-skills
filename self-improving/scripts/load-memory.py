#!/usr/bin/env python3.12
# @hook agent-spawn
# @priority 20
# @description Load graduated memory and pending open entries
"""Call memory.py to output memory and pending logs."""

from _common import run_memory


def main() -> None:
    memory = run_memory("memory")
    if memory:
        print(f"\n<memory>\n{memory}\n</memory>")

    pending = run_memory("list", "--status", "open")
    if pending:
        count = len(pending.splitlines())
        print(f'\n<pending-logs count="{count}">\n{pending}\n</pending-logs>')


if __name__ == "__main__":
    main()
