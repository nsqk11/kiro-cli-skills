#!/usr/bin/env python3.12
"""memory — self-improving memory CLI.

Data: .data/mem.json  |  Lifecycle: open → done → graduated

Usage:
    python3.12 memory.py add      -t TYPE -k "kw,..." -s "summary" [-d "detail"]
    python3.12 memory.py resolve  -i ID [-r "resolution"]
    python3.12 memory.py graduate -i ID -S "section" [-k "skill-name"]
    python3.12 memory.py list     [--status S] [--skill S] [--type T]
    python3.12 memory.py search   -q "term"
    python3.12 memory.py memory
    python3.12 memory.py clean    [--apply]
"""

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Entry:
    """A single memory entry."""

    id: str
    date: str
    type: str
    status: str  # open | done | graduated
    keywords: list[str] = field(default_factory=list)
    summary: str = ""
    detail: str = ""
    resolution: Optional[str] = None
    section: Optional[str] = None    # set on graduation
    skill: Optional[str] = None      # "none" = global memory

    def fmt(self) -> str:
        return f"[{self.id}] {self.status} {self.type}: {self.summary}"

    @classmethod
    def from_dict(cls, d: dict) -> "Entry":
        # Accept unknown keys gracefully (forward compat)
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


# ---------------------------------------------------------------------------
# Store — all file I/O in one place
# ---------------------------------------------------------------------------

class Store:
    """JSON-backed entry store with atomic writes."""

    def __init__(self) -> None:
        # MEM_DATA env var overrides path for testing isolation
        override = os.environ.get("MEM_DATA")
        self.path = Path(override) if override else Path(__file__).resolve().parent.parent / ".data" / "mem.json"
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self.path.write_text("[]")
        self.entries: list[Entry] = [Entry.from_dict(d) for d in json.loads(self.path.read_text())]

    def save(self) -> None:
        """Atomic write: write to tmp then rename."""
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps([asdict(e) for e in self.entries], ensure_ascii=False, indent=2) + "\n")
        tmp.rename(self.path)

    def find(self, entry_id: str) -> Entry:
        """Find entry by ID or exit with error."""
        for e in self.entries:
            if e.id == entry_id:
                return e
        print(f"ERR: entry '{entry_id}' not found")
        sys.exit(1)

    def next_id(self) -> str:
        """Date-based sequential ID: YYYYMMDD + 3-digit seq (e.g. 20260415003)."""
        today = datetime.now().strftime("%Y%m%d")
        count = sum(1 for e in self.entries if e.id.startswith(today))
        return f"{today}{count + 1:03d}"


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_add(args: argparse.Namespace, store: Store) -> None:
    """Add entry with keyword-based duplicate detection."""
    keywords = [k.strip() for k in args.keywords.split(",") if k.strip()] if args.keywords else []

    if keywords and not args.force:
        for kw in keywords:
            hits = [e for e in store.entries if any(kw.lower() in k.lower() for k in e.keywords)]
            if hits:
                print(f"DUPLICATE: keyword '{kw}' found in {len(hits)} existing entries:")
                for e in hits:
                    print(f"  {e.fmt()}")
                print("Use --force or different keywords.")
                sys.exit(2)

    entry = Entry(
        id=store.next_id(),
        date=datetime.now().strftime("%Y-%m-%d"),
        type=args.type,
        status="open",
        keywords=keywords,
        summary=args.summary,
        detail=args.detail or "",
    )
    store.entries.append(entry)
    store.save()
    print(f"OK: added {entry.id}")


def cmd_resolve(args: argparse.Namespace, store: Store) -> None:
    """Mark entry as done."""
    entry = store.find(args.id)
    entry.status = "done"
    if args.resolution:
        entry.resolution = args.resolution
    store.save()
    print(f"OK: {args.id} → done")


def cmd_graduate(args: argparse.Namespace, store: Store) -> None:
    """Graduate entry. skill='none' keeps it in global memory."""
    entry = store.find(args.id)
    entry.status = "graduated"
    entry.section = args.section
    entry.skill = args.skill or "none"
    store.save()
    print(f"OK: {args.id} → graduated [section={entry.section}, skill={entry.skill}]")


def cmd_list(args: argparse.Namespace, store: Store) -> None:
    """List entries, optionally filtered by status/skill/type."""
    for e in store.entries:
        if args.status and e.status != args.status:
            continue
        if args.skill and e.skill != args.skill:
            continue
        if args.type and e.type != args.type:
            continue
        print(e.fmt())


def cmd_search(args: argparse.Namespace, store: Store) -> None:
    """Case-insensitive substring search across keywords and summary."""
    q = args.query.lower()
    for e in store.entries:
        if any(q in k.lower() for k in e.keywords) or q in e.summary.lower():
            print(e.fmt())


def cmd_memory(_args: argparse.Namespace, store: Store) -> None:
    """Output graduated unbound entries for agent context injection."""
    for e in store.entries:
        if e.status == "graduated" and e.skill == "none":
            print(f"[{e.section}] {e.summary}")


def cmd_clean(args: argparse.Namespace, store: Store) -> None:
    """Remove graduated-in-skill + done older than 7 days. Dry run by default."""
    cutoff = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")

    skilled = [e for e in store.entries if e.status == "graduated" and (e.skill or "none") != "none"]
    stale = [e for e in store.entries if e.status == "done" and (e.date or "") <= cutoff]
    total = len(skilled) + len(stale)

    print(f"Cleanable: {len(skilled)} graduated (in skill) + {len(stale)} done (>7d) = {total}")
    if not args.apply:
        print("(dry run — pass --apply to execute)")
        return

    remove_ids = {e.id for e in skilled + stale}
    store.entries = [e for e in store.entries if e.id not in remove_ids]
    store.save()
    print(f"OK: cleaned. {len(store.entries)} entries remaining.")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

COMMANDS = {
    "add": cmd_add,
    "resolve": cmd_resolve,
    "graduate": cmd_graduate,
    "list": cmd_list,
    "search": cmd_search,
    "memory": cmd_memory,
    "clean": cmd_clean,
}


def main() -> None:
    parser = argparse.ArgumentParser(prog="memory", description="self-improving memory CLI")
    sub = parser.add_subparsers(dest="cmd")

    p = sub.add_parser("add", help="Add a new entry")
    p.add_argument("-t", "--type", required=True)
    p.add_argument("-k", "--keywords", default="", help="comma-separated")
    p.add_argument("-s", "--summary", required=True)
    p.add_argument("-d", "--detail", default="")
    p.add_argument("--force", action="store_true")

    p = sub.add_parser("resolve", help="Mark entry as done")
    p.add_argument("-i", "--id", required=True)
    p.add_argument("-r", "--resolution", default="")

    p = sub.add_parser("graduate", help="Graduate entry")
    p.add_argument("-i", "--id", required=True)
    p.add_argument("-S", "--section", required=True)
    p.add_argument("-k", "--skill", default="none")

    p = sub.add_parser("list", help="List entries")
    p.add_argument("--status")
    p.add_argument("--skill")
    p.add_argument("--type")

    p = sub.add_parser("search", help="Search entries")
    p.add_argument("-q", "--query", required=True)

    sub.add_parser("memory", help="Graduated unbound entries")

    p = sub.add_parser("clean", help="Remove stale entries")
    p.add_argument("--apply", action="store_true")

    args = parser.parse_args()
    if not args.cmd:
        parser.print_help()
        sys.exit(0)

    COMMANDS[args.cmd](args, Store())


if __name__ == "__main__":
    main()
