# docx-toolkit

JSON-based docx editing toolkit for Kiro CLI.

Extracts `.docx` body content into a flat JSON node map keyed by body index, LLM reads and writes change instructions, then patch applies changes by in-place modifying the original docx XML. Everything except the patched elements is preserved untouched.

## Scripts

| Script | Purpose |
|--------|---------|
| `extract.py` | docx → flat JSON (reading view + body-index locator) |
| `patch.py` | instructions → docx (in-place XML surgery, no rebuild) |

## Quick Start

```bash
# Extract docx → JSON
python3 scripts/extract.py input.docx -o doc.json

# Apply patch instructions
python3 scripts/patch.py input.docx instructions.json [-o output.docx]
```

Run `python3 <script> --help` for full usage.

## Patch Operations

| Op | What it does |
|----|-------------|
| `update_text` | Change text of one run by index |
| `update_runs` | Replace all runs in paragraph |
| `update_cell` | Change one table cell |
| `rename_heading` | Change heading text |
| `delete` | Remove body element |
| `add_after` | Insert paragraph after target |
| `add_table_after` | Insert table after target |
| `move` | Relocate element to after target |

## Key Gotchas

- Use `delete` (not `update_runs` with empty text) to remove template placeholders — empty runs leave blank lines
- `update_runs` strips rPr from original runs — include formatting in new runs or fix rPr after patching
- Multiple `add_after` on same idx → reverse order — use Python `addnext()` for bulk forward-order insertions
- `clone_style_from` does not set heading level — use direct Python insertion for new headings

## Requirements

- Python 3.6+
- python-docx
