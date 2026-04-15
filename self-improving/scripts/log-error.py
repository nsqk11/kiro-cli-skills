#!/usr/bin/env python3.12
# @hook post-tool-use
# @priority 10
# @description Auto-log genuine tool errors via memory.py
"""Parse tool response from stdin, log errors to memory store."""

import json
import re
import sys

from _common import run_memory

ERROR_PATTERN = re.compile(r"error|fatal|denied|not found|no such", re.IGNORECASE)

# Tool names that report errors via exit status
EXIT_STATUS_TOOLS = {"execute_bash", "execute_cmd", "shell", "use_aws"}
# Tool names that report errors in response text
TEXT_ERROR_TOOLS = {"fs_write", "fs_read"}


def _extract_error(event: dict) -> str | None:
    """Extract error message from tool event, or None if no error."""
    tool = event.get("tool_name", "unknown")
    response = event.get("tool_response", "")
    if isinstance(response, dict):
        response = json.dumps(response)

    exit_status = None
    try:
        parsed = json.loads(response) if isinstance(response, str) else response
        exit_status = parsed.get("exit_status") if isinstance(parsed, dict) else None
    except (json.JSONDecodeError, AttributeError):
        pass

    if tool in EXIT_STATUS_TOOLS:
        if exit_status not in (None, 0, "0", "null"):
            match = ERROR_PATTERN.search(response)
            return match.group(0) if match else f"Command exited with status {exit_status}"

    if tool in TEXT_ERROR_TOOLS:
        for line in response.splitlines()[:3]:
            if ERROR_PATTERN.search(line):
                return line.strip()[:120]

    return None


def main() -> None:
    event = json.loads(sys.stdin.read()) if not sys.stdin.isatty() else {}
    if not event:
        return

    tool = event.get("tool_name", "unknown")
    error = _extract_error(event)
    if not error:
        return

    # Log to memory store; exit code 2 = duplicate (expected)
    out = run_memory("add", "-t", "error", "-k", tool, "-s", error[:120])

    if "DUPLICATE" in out:
        print(f"<error-detected>\nTool error from {tool} (duplicate): {error}\n</error-detected>")
    else:
        print(f"<error-detected>\n📝 {out}: {error}\n</error-detected>")


if __name__ == "__main__":
    main()
