# docx-toolkit

Two independent capabilities for `.docx` files:

1. **Scrape** — extract body content into flat JSON for reading, analysis, or comparison (includes images and comments)
2. **Modify** — use scraped indices to surgically patch the original docx XML in-place

Everything except the patched elements is preserved untouched.

## Scripts

| Script | Purpose |
|--------|---------|
| `scrape.py` | docx → flat JSON (body-index keyed node map) |
| `patch.py` | JSON instructions → docx (in-place XML surgery) |

## Quick Start

```bash
# Scrape only (read/analyze)
python3.12 scripts/scrape.py input.docx -o doc.json

# Modify (scrape → patch)
python3.12 scripts/scrape.py input.docx -o doc.json
python3.12 scripts/patch.py input.docx instructions.json [-o output.docx]
```

Run `python3.12 <script> --help` for full usage.

## Patch Operations

| Op | What it does |
|----|-------------|
| `update_text` | Change text of one run by index |
| `update_runs` | Replace all runs in paragraph |
| `update_cell` | Change one table cell |
| `rename_heading` | Change heading text |
| `add_row` | Add row to table after specified row |
| `delete_row` | Delete row from table |
| `delete` | Remove body element |
| `add_after` | Insert paragraph after target |
| `add_table_after` | Insert table after target |
| `insert_image` | Insert image in new paragraph after target |
| `move` | Relocate element to after target |
| `reply_comment` | Add reply to comments.xml |

## Requirements

- Python 3.12+
- python-docx
