---
name: docx-toolkit
description: "JSON-based docx editing toolkit. Extracts docx structure into a flat node map (UUID-keyed sections with heading/content/children), LLM reads and edits via change instructions, then applies changes back to docx. Use when reading, editing, or creating .docx files. Trigger on mentions of '.docx', 'Word document', 'OA report', 'NDS', or any document editing task. Replaces direct XML manipulation."
---

# docx-toolkit

## Why

- **do**: LLM cannot efficiently operate on docx XML — it's too verbose and consumes context rapidly. A JSON intermediate layer provides a compact, structured representation that LLM can read and edit via change instructions.
- **don't**: Not for PDF, PPTX, XLSX, or Confluence pages.

## What

- **do**: Two scripts — `extract.py` (docx → JSON) and `apply.py` (JSON + change instructions → docx). JSON is the working copy (source of truth), persisted across sessions.
- **don't**: Does not render or preview documents. Does not handle track changes or comments (future).

## Who

- **do**: `extract.py` and `apply.py` are invoked by LLM via `python3.11`. LLM reads JSON, reasons about content, writes change instructions.
- **don't**: LLM never touches docx or XML directly.

## When

- **do**: Any task involving reading or editing .docx files.
- **don't**: Not for creating docx from scratch without a template (always start from existing docx).

## Where

| Path | Content |
|------|---------|
| `scripts/extract.py` | docx → JSON |
| `scripts/apply.py` | JSON + instructions → docx |
| `.docx-toolkit/<name>.json` | Persisted JSON working copy (next to source docx) |

## How

### Workflow

```
extract.py                    apply.py
docx ──────→ JSON ──LLM──→ instructions ──────→ docx
              ↑                                    │
              └──── persisted working copy ────────┘
```

1. **Extract**: `python3.11 extract.py input.docx -o output.json`
   - First run: generates JSON with UUIDs, saves as working copy
   - Re-extract: matches existing nodes by content, preserves UUIDs

2. **LLM reads JSON**, reasons about content, produces change instructions

3. **Apply**: `python3.11 apply.py input.docx instructions.json -o output.docx`
   - Or: `python3.11 apply.py input.docx -i '[ ... ]' -o output.docx`

### JSON Structure

```json
{
  "meta": {"source": "report.docx", "extracted": "2026-04-14T08:30:00"},
  "root": ["nd-a1b2c3d4", "nd-e5f6a7b8"],
  "nodes": {
    "nd-a1b2c3d4": {
      "type": "section",
      "heading": "Introduction",
      "level": 1,
      "children": ["nd-11223344"],
      "content": [
        {"type": "paragraph", "runs": [
          {"text": "This document presents the "},
          {"text": "OA study", "bold": true},
          {"text": " for 865-OA1. See "},
          {"text": "Confluence", "hyperlink": "https://..."},
          {"text": "."}
        ]},
        {"type": "table", "rows": [
          [{"runs": [{"text": "Rev", "bold": true}]}, {"runs": [{"text": "Date", "bold": true}]}],
          [{"runs": [{"text": "PA1"}]}, {"runs": [{"text": "260414"}]}]
        ]},
        {"type": "list", "style": "bullet", "items": [
          {"runs": [{"text": "Item one"}]},
          {"runs": [{"text": "Item two"}]}
        ]},
        {"type": "image", "filename": "image1.png", "alt": "Architecture diagram"}
      ]
    }
  }
}
```

#### Node ID

- Format: `nd-<8 hex chars>` (e.g., `nd-f7a1b2c3`)
- Generated on first extract, stable across re-extracts
- Bound to node lifecycle: created with node, unchanged on edit/move, deleted with node

#### Content Types

| Type | Fields |
|------|--------|
| `paragraph` | `runs[]` |
| `table` | `rows[][]` (each cell has `runs[]`) |
| `list` | `style` (bullet/number), `items[]` (each has `runs[]`) |
| `image` | `filename`, `alt` |

#### Run Format

| Field | Description |
|-------|-------------|
| `text` | Text content (required) |
| `bold` | Boolean |
| `italic` | Boolean |
| `hyperlink` | URL string |

### Change Instructions

Array of operations, applied in order:

```json
[
  {"op": "update", "id": "nd-a1b2c3d4", "content": [...]},
  {"op": "rename", "id": "nd-a1b2c3d4", "heading": "New Title"},
  {"op": "delete", "id": "nd-a1b2c3d4", "recursive": true},
  {"op": "add", "parent": "nd-a1b2c3d4", "after": "nd-11223344", "heading": "New Section", "level": 2, "content": [...]},
  {"op": "move", "id": "nd-a1b2c3d4", "parent": "nd-e5f6a7b8", "after": null}
]
```

| Op | Required | Optional | Description |
|----|----------|----------|-------------|
| `update` | `id`, `content` | | Replace section content |
| `rename` | `id`, `heading` | | Change heading text |
| `delete` | `id` | `recursive` (default: true) | Remove node. recursive=true: delete subtree. false: promote children |
| `add` | `parent`, `heading`, `level`, `content` | `after` (null = first child) | Insert new section |
| `move` | `id`, `parent` | `after` (null = first child) | Move node to new parent |

## How Much

- **do**: Extract handles H1-H4, paragraphs, tables, lists, images, hyperlinks, bold/italic. Apply supports all 5 operations.
- **don't**: No nested lists (flat only). No merged table cells (future). No headers/footers (future).
