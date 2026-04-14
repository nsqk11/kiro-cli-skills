---
name: docx-toolkit
description: "JSON-based docx editing toolkit. Extracts docx body content into a flat node map keyed by body index, LLM reads and writes change instructions, then patch applies changes by in-place modifying the original docx XML. Everything except the patched elements is preserved untouched. Use when reading, editing, or creating .docx files."
---

# docx-toolkit

## Why

- **do**: LLM cannot operate on docx XML directly. JSON provides a compact reading view. Patch writes changes back by surgically modifying the original XML — everything not explicitly changed is preserved bit-for-bit.
- **don't**: Not for PDF, PPTX, XLSX, or Confluence pages.

## What

- **do**: Two scripts:
  - `extract.py` — docx → flat JSON (reading view + body-index locator)
  - `patch.py` — instructions → docx (in-place XML surgery, no rebuild)
- **don't**: Does not rebuild the document. Does not touch anything not explicitly targeted by instructions.

## Who

- **do**: Scripts invoked by LLM via `python3`. LLM reads JSON, writes change instructions. Scripts are in `$SKILL_DIR/scripts/`.
- **don't**: LLM never edits XML directly — always use patch.py with instructions.

## Where

| Path | Content |
|------|---------|
| `$SKILL_DIR/scripts/extract.py` | docx → JSON |
| `$SKILL_DIR/scripts/patch.py` | instructions → docx (in-place) |

Run `python3 <script> --help` for CLI usage.

## How

### Workflow

```
extract.py              LLM                    patch.py
docx ──→ JSON(read-only) ──→ change instructions ──→ docx(in-place modify)
```

1. Extract: `python3 extract.py input.docx -o output.json`
2. Read: LLM reads JSON — flat map keyed by body index, sections index for navigation
3. Write instructions: LLM produces JSON array of ops
4. Patch: `python3 patch.py input.docx instructions.json [-o output.docx]`
5. Re-extract after patch if further edits needed

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
| `runs` | Array of `{"text", "bold?", "italic?", "hidden?", "hyperlink?"}` |
| `style` | Paragraph/table style name |
| `level` | Heading level (1-9), only on headings |
| `section` | Full section path, only on headings |
| `cells` | Table cells with `row`, `col`, `text`, `runs`, `shading?` |
| `list` | `true` if list paragraph |

### Patch Instructions

```json
[
  {"op": "update_text",     "idx": 37, "run": 0, "text": "New text"},
  {"op": "update_runs",     "idx": 37, "runs": [{"text": "New", "bold": true}]},
  {"op": "update_cell",     "idx": 35, "row": 0, "col": 1, "runs": [{"text": "Done"}]},
  {"op": "rename_heading",  "idx": 34, "text": "New Heading"},
  {"op": "delete",          "idx": 50},
  {"op": "add_after",       "idx": 37, "runs": [{"text": "Inserted"}], "clone_style_from": 37},
  {"op": "add_table_after", "idx": 37, "rows": [[{"runs": [{"text": "A"}]}]], "clone_style_from": 35},
  {"op": "move",            "idx": 50, "after": 37}
]
```

| Op | What it does | Lossless? |
|----|-------------|-----------|
| `update_text` | Change text of one run by index | 100% — all formatting preserved |
| `update_runs` | Replace all runs in paragraph | pPr preserved, run formatting rewritten |
| `update_cell` | Change one table cell | Table structure + other cells untouched |
| `rename_heading` | Change heading text | 100% — formatting preserved |
| `delete` | Remove body element | 100% |
| `add_after` | Insert paragraph after target | Style cloned from `clone_style_from` |
| `add_table_after` | Insert table after target | tblPr/grid cloned from source |
| `move` | Relocate element to after target | 100% |

### Execution Order

patch.py handles idx stability automatically:
1. Modifications first (update_text, update_runs, update_cell, rename_heading) — body length unchanged
2. Structural changes (delete, add, move) — sorted by idx descending to prevent drift

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

- **do**: 8 ops covering text edit, run replacement, cell edit, heading rename, delete, add paragraph, add table, move. Flat JSON with body-index keys, cell-level row/col coordinates, text summaries, section navigation index.
- **don't**: No merged cell editing. No nested list manipulation. No cross-file changes (headers/footers/styles). No automatic re-extract after patch.
