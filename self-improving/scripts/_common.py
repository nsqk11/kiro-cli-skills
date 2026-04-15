"""Shared utilities for self-improving hook scripts."""

import subprocess
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPTS_DIR.parent
PROMPTS_DIR = SKILL_DIR / "prompts"
DATA_DIR = SKILL_DIR / ".data"
MEMORY_PY = SCRIPTS_DIR / "memory.py"
PYTHON = "python3.12"


def read_prompt(name: str) -> str:
    """Read a prompt template file from prompts/ directory."""
    return (PROMPTS_DIR / name).read_text().strip()


def run_memory(*args: str) -> str:
    """Run a memory.py subcommand, return stdout. Empty string on failure."""
    result = subprocess.run(
        [PYTHON, str(MEMORY_PY), *args],
        capture_output=True, text=True,
    )
    return result.stdout.strip()
