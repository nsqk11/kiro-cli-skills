---
name: docx-toolkit
description: "JSON-based docx editing toolkit. Extracts docx structure into a flat node map (UUID-keyed sections with heading/content/children), LLM reads and edits via change instructions, then applies changes back to docx. Use when reading, editing, or creating .docx files. Trigger on mentions of '.docx', 'Word document', 'report', 'specification', or any document editing task. Replaces direct XML manipulation."
---

# docx-toolkit

## Why

- **do**: LLM cannot efficiently operate on docx XML — it's too verbose and consumes context rapidly. A JSON intermediate layer provides a compact, structured representation that LLM can read and edit via change instructions. Roundtrip fidelity verified on real documents (82 nodes, 28 tables, 9 lists, 2 images, 86 hyperlinks — all preserved).
- **don't**: Not for PDF, PPTX, XLSX, or Confluence pages. Not for documents where XML fidelity matters more than content (e.g., complex form fields, tracked changes).

## What

- **do**: Three scripts forming a pipeline:
  - `extract.py` — docx → JSON (structure extraction with UUID-keyed nodes)
  - `tree.py` — JSON tree operations (show structure, get node, apply change instructions)
  - `apply.py` — JSON → docx (full rebuild using original docx as style template)
  - JSON is the working copy (source of truth), persisted across sessions.
- **don't**: Does not render or preview documents. Does not handle track changes, comments, headers/footers, or footnotes (future). Does not create docx from scratch — always starts from an existing docx as template.

## Who

- **do**: Scripts are invoked by LLM via `python3`. LLM reads JSON, reasons about content, writes change instructions. Scripts are in `$SKILL_DIR/scripts/`.
- **don't**: LLM never touches docx or XML directly. LLM never edits the JSON file by hand — always use `tree.py apply` with change instructions.

## When

- **do**: Any task involving reading or editing .docx files. Trigger on mentions of `.docx`, `Word document`, `report`, `specification`, or any document editing task.
- **don't**: Not when the task only needs text extraction without structure (use `python-docx` directly). Not when the primary deliverable is a non-docx format.

## Where

| Path | Content |
|------|---------|
| `$SKILL_DIR/scripts/extract.py` | docx → JSON extraction |
| `$SKILL_DIR/scripts/tree.py` | JSON tree operations (show, get, apply) |
| `$SKILL_DIR/scripts/apply.py` | JSON → docx rebuild using template |
| `.docx-toolkit/<name>.json` | Persisted JSON working copy (created next to source docx) |

Run `python3 <script> --help` for exact CLI usage. `tree.py` has subcommands: `python3 tree.py {show,get,apply} --help`.

## How

### Workflow

```
extract.py              tree.py apply           apply.py
docx ──────→ JSON ──LLM──→ instructions ──→ JSON' ──────→ docx
              ↑                                              │
              └────────── persisted working copy ────────────┘
```

1. Extract docx to JSON (first run generates UUIDs; re-extract preserves them)
2. LLM reads JSON via `tree.py show` (tree overview) and `tree.py get` (node detail)
3. LLM produces change instructions (see below)
4. Apply instructions to JSON via `tree.py apply`
5. Rebuild docx from JSON via `apply.py` (uses original docx as style template)

### JSON Structure

Top-level keys:

| Key | Type | Description |
|-----|------|-------------|
| `meta` | object | `source` (filename), `extracted` (timestamp) |
| `root` | string[] | Ordered list of top-level node IDs |
| `nodes` | object | Map of node ID → node object |

#### Node Object

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Always `"section"` |
| `heading` | string | Heading text (empty string for L0 preamble) |
| `level` | int | Heading level: 0 = preamble (content before first heading), 1-9 = Heading 1-9 |
| `children` | string[] | Ordered child node IDs |
| `content` | array | Content blocks (see below) |

#### Node ID

- Format: `nd-<8 hex chars>` (e.g., `nd-f7a1b2c3`)
- Generated on first extract, stable across re-extracts
- Lifecycle: created with node, unchanged on edit/move, deleted with node

#### Content Block Types

| Type | Fields | Notes |
|------|--------|-------|
| `paragraph` | `runs[]` | |
| `table` | `rows[][]` | Each cell is `{"runs": [...]}` |
| `list` | `style`, `items[]` | `style`: `"bullet"` or `"number"`. Each item is `{"runs": [...]}` |
| `image` | `filename`, `alt` | `filename` matches the image file inside docx media folder |

#### Run Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | yes | Text content |
| `bold` | boolean | no | Bold formatting |
| `italic` | boolean | no | Italic formatting |
| `hyperlink` | string | no | URL (makes the run a hyperlink) |

Example:

```json
{"type": "paragraph", "runs": [
  {"text": "See "},
  {"text": "Confluence", "hyperlink": "https://..."},
  {"text": " for details."}
]}
```

### Change Instructions

Array of operations, applied in order by `tree.py apply`:

| Op | Required Fields | Optional Fields | Description |
|----|----------------|-----------------|-------------|
| `update` | `id`, `content` | | Replace section content (array of content blocks) |
| `rename` | `id`, `heading` | | Change heading text |
| `delete` | `id` | `recursive` (default: `true`) | `true`: delete subtree. `false`: promote children to parent |
| `add` | `parent`, `heading`, `level`, `content` | `after` (`null` = first child, `"$end"` = last child, or node ID) | Insert new section |
| `move` | `id`, `parent` | `after` (`null` = first child, `"$end"` = last child, or node ID) | Move node to new parent |

Example:

```json
[
  {"op": "update", "id": "nd-a1b2c3d4", "content": [
    {"type": "paragraph", "runs": [{"text": "Updated content."}]}
  ]},
  {"op": "rename", "id": "nd-a1b2c3d4", "heading": "New Title"},
  {"op": "add", "parent": "nd-a1b2c3d4", "after": "$end", "heading": "New Sub-Section", "level": 3, "content": []},
  {"op": "delete", "id": "nd-e5f6a7b8"},
  {"op": "move", "id": "nd-11223344", "parent": "nd-a1b2c3d4", "after": null}
]
```

### Known Behaviors

- L0 preamble: content before the first heading (cover page, abstract, etc.) is collected into a virtual root node with `level: 0` and empty heading.
- Images: `extract.py` records filename only. `apply.py` copies image relationships from the template docx — no duplicate media files.
- Lists: `apply.py` injects `numPr` XML directly (not via style name) to ensure roundtrip fidelity.
- Hyperlinks: preserved in both extraction and rebuild, including in table cells.
- Font-specific formatting (e.g., Courier New for code variables): not captured in runs — only bold/italic/hyperlink are extracted.

## How Much

- **do**:
  - Extract: Heading 1-9, paragraphs, tables, bullet/number lists, images, hyperlinks, bold, italic.
  - Tree: all 5 change operations (update, rename, delete, add, move).
  - Apply: full document rebuild from JSON using template for styles/numbering/media.
  - Verified on real 160-page specification: 82 nodes, 302 paragraphs, 28 tables, 9 lists, 2 images — perfect roundtrip.
- **don't**:
  - No nested lists (flat only).
  - No merged table cells.
  - No headers/footers/footnotes.
  - No font name extraction (Courier New, etc.).
  - No track changes or comments.
