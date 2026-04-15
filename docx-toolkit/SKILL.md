---
name: docx-toolkit
description: "Two independent capabilities for .docx files: (1) Scrape — extract body content into flat JSON for reading/analysis; (2) Modify — use scraped indices to surgically patch the original docx XML in-place. Use when reading or editing .docx files."
---

# docx-toolkit

## Why

- **do**: LLM cannot operate on docx XML directly. This toolkit provides two independent capabilities: scraping docx content into JSON for reading, and using the scraped data to make precise modifications.
- **don't**: Not for PDF, PPTX, XLSX, or Confluence pages.

## What

- **do**: Two independent capabilities, each backed by a script:
  1. **Scrape** (`scrape.py`) — docx → flat JSON. Use standalone for reading, analysis, comparison, or as input for modification.
  2. **Modify** (`patch.py`) — JSON instructions → docx. Uses body indices from scraping to surgically modify the original XML in-place. Everything not targeted is preserved bit-for-bit.
- **don't**: Does not rebuild the document. Does not touch anything not explicitly targeted by instructions.

## Who

- **do**: Scripts invoked by LLM via `python3`. LLM reads JSON, writes change instructions. Scripts are in `$SKILL_DIR/scripts/`.
- **don't**: LLM never edits XML directly — always use patch.py with instructions.

## Where

| Path | Content |
|------|---------|
| `$SKILL_DIR/scripts/scrape.py` | docx → JSON |
| `$SKILL_DIR/scripts/patch.py` | instructions → docx (in-place) |

Run `python3 <script> --help` for CLI usage.

## How

### Scrape (read-only)

```
python3 scrape.py input.docx -o output.json
```

Use the JSON for reading, analysis, comparison — no modification needed.

### Modify (scrape → patch)

```
python3 scrape.py input.docx -o doc.json     # 1. scrape for indices
# LLM reads JSON, writes change instructions  # 2. plan changes
python3 patch.py input.docx instructions.json  # 3. apply in-place
```

Re-extract after patch if further edits needed.

### JSON Structure

```json
{
  "meta": {"source": "report.docx", "body_count": 142},
  "nodes": {
    "0":  {"tag": "p", "style": "Title", "text": "Report Title", "runs": [...]},
    "34": {"tag": "p", "style": "Heading1", "text": "Introduction", "section": "Introduction", "level": 1},
    "35": {"tag": "tbl", "style": "TableGrid", "cells": [
      {"row": 0, "col": 0, "text": "Header", "runs": [...]}
    ]},
    "37": {"tag": "p", "text": "Body text here", "runs": [...]}
  },
  "sections": {
    "Introduction": {"idx": 34, "level": 1, "children": ["Introduction > Background"]}
  }
}
```

Key: node keys are body element indices (strings). Use these indices in patch instructions.

| Field | Description |
|-------|-------------|
| `tag` | `p` (paragraph), `tbl` (table), `sdt` (structured doc tag) |
| `text` | Plain text summary (runs concatenated) |
| `runs` | Array of `{"text", "bold?", "italic?", "hidden?", "hyperlink?"}` — images appear as `{"image": true, "rId", "target", "alt?", "width_emu?", "height_emu?"}` |
| `style` | Paragraph/table style name |
| `level` | Heading level (1-9), only on headings |
| `section` | Full section path, only on headings |
| `cells` | Table cells with `row`, `col`, `text`, `runs`, `shading?` |
| `list` | `true` if list paragraph |
| `comments` | Array of `{"id", "author", "date", "text"}` — inline comments attached to this node |

### Patch Instructions

```json
[
  {"op": "update_text",     "idx": 37, "run": 0, "text": "New text"},
  {"op": "update_runs",     "idx": 37, "runs": [{"text": "New", "bold": true}]},
  {"op": "update_cell",     "idx": 35, "row": 0, "col": 1, "runs": [{"text": "Done"}]},
  {"op": "rename_heading",  "idx": 34, "text": "New Heading"},
  {"op": "add_row",         "idx": 35, "after_row": 2, "cells": [{"runs": [{"text": "A"}]}]},
  {"op": "delete_row",      "idx": 35, "row": 3},
  {"op": "delete",          "idx": 50},
  {"op": "add_after",       "idx": 37, "runs": [{"text": "Inserted"}], "clone_style_from": 37},
  {"op": "add_table_after", "idx": 37, "rows": [[{"runs": [{"text": "A"}]}]], "clone_style_from": 35},
  {"op": "insert_image",    "idx": 37, "image_path": "fig.png", "width_cm": 15},
  {"op": "move",            "idx": 50, "after": 37},
  {"op": "reply_comment",   "comment_id": 1, "text": "Done.", "author": "AI"}
]
```

| Op | What it does | Lossless? |
|----|-------------|-----------|
| `update_text` | Change text of one run by index | 100% — all formatting preserved |
| `update_runs` | Replace all runs in paragraph | pPr preserved, run formatting rewritten |
| `update_cell` | Change one table cell | Table structure + other cells untouched |
| `rename_heading` | Change heading text | 100% — formatting preserved |
| `add_row` | Add row to table after specified row | Clones trPr + tcPr from reference row |
| `delete_row` | Delete row from table | 100% |
| `delete` | Remove body element | 100% |
| `add_after` | Insert paragraph after target | Style cloned from `clone_style_from` |
| `add_table_after` | Insert table after target | tblPr cloned, grid auto-generated |
| `insert_image` | Insert image in new paragraph after target | New w:drawing element |
| `move` | Relocate element to after target | 100% |
| `reply_comment` | Add reply to comments.xml | New w:comment element |

### Execution Order

patch.py handles idx stability automatically:
1. Modifications first (update_text, update_runs, update_cell, rename_heading, add_row, delete_row) — body length unchanged
2. Structural changes (delete, add_after, add_table_after, insert_image, move) — sorted by idx descending to prevent drift
3. Comment replies — applied to comments.xml after body ops

### What Is Preserved

- Preamble (cover page, TOC) — never touched
- Headers, footers, styles, numbering, theme — in separate XML files, never touched
- Unmodified paragraphs/tables — bit-for-bit identical
- Paragraph formatting (pPr) on modified paragraphs — preserved by update_text and rename_heading
- Images, bookmarks, comments, track changes on unmodified elements — preserved

### Gotchas

| Pitfall | Correct Approach |
|---------|-----------------|
| `update_runs` with `{"text":""}` to clear template placeholder text → leaves empty paragraph (visible blank line) | Use `delete` to remove unwanted placeholder paragraphs entirely |
| `update_runs` replaces all runs → new runs have no rPr → font/size reverts to style default, causing inconsistent formatting | Include formatting in runs: `{"text":"...", "bold": true}`, or copy rPr from template's original runs after patching |
| Multiple `add_after` ops targeting the same `idx` → structural ops sorted by idx descending → insertions appear in reverse order | Use different target indices, or use Python `addnext()` in forward order for bulk insertions |
| `clone_style_from` on `add_after` clones pPr from source paragraph → does NOT set heading level if source is body text | For adding headings, use Python direct insertion with explicit `pStyle` set to `Heading2`/`Heading3`/etc. |
| Template file copied with read-only permissions → `patch.py` save fails with PermissionError | `os.chmod()` the file before patching, or use `shutil.copy2` + explicit permission fix |

## How Much

- **do**: 12 ops covering text edit, run replacement, cell edit, heading rename, table row add/delete, delete, add paragraph, add table, insert image, move, reply comment. Scrape outputs flat JSON with body-index keys, inline images, inline comments, section navigation index.
- **don't**: No merged cell editing. No nested list manipulation. No headers/footers/styles editing. No automatic re-extract after patch.
