#!/usr/bin/env python3.12
# @hook stop
# @priority 10
# @description Prompt session-end review for uncaptured events
"""Output session review reminder with open entry count."""

from _common import SKILL_DIR, run_memory


def main() -> None:
    pending = run_memory("list", "--status", "open")
    count = len(pending.splitlines()) if pending else 0

    print(f"""<session-review>
Session ending. Quick review:
1. Any uncaptured events this session? (error/correction/gotcha/convention)
   → python3.12 {SKILL_DIR}/scripts/memory.py add -t TYPE -k "kw" -s "summary"
2. Open entries: {count}
3. Any entry ready to graduate?
   → python3.12 {SKILL_DIR}/scripts/memory.py graduate -i ID -S "section"
Skip silently if conversation was trivial.
</session-review>""")


if __name__ == "__main__":
    main()
