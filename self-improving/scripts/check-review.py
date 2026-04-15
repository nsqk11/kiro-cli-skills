#!/usr/bin/env python3.12
# @hook agent-spawn
# @priority 30
# @description Check periodic review trigger (every 20 sessions or 7 days)
"""Manage review-state.json and emit reminder if threshold reached."""

import json
from datetime import datetime
from pathlib import Path

from _common import DATA_DIR

STATE_FILE = DATA_DIR / "review-state.json"


def _load_state() -> dict:
    """Load or initialize review state."""
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"sessions_since_review": 0, "last_review_date": datetime.now().strftime("%Y-%m-%d")}


def _save_state(state: dict) -> None:
    """Atomic write review state."""
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2) + "\n")
    tmp.rename(STATE_FILE)


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    state = _load_state()
    state["sessions_since_review"] = state.get("sessions_since_review", 0) + 1

    last_date = state.get("last_review_date", datetime.now().strftime("%Y-%m-%d"))
    days_since = (datetime.now() - datetime.strptime(last_date, "%Y-%m-%d")).days

    if state["sessions_since_review"] >= 20 or days_since >= 7:
        print("""
<review-reminder>
Periodic review triggered. Check:
- Repeated keywords 3+ → graduate candidate?
- Open entries stale 7+ days → resolve or drop?
After review, reset via: jq '.sessions_since_review=0|.last_review_date="TODAY"' review-state.json
</review-reminder>""")

    _save_state(state)


if __name__ == "__main__":
    main()
