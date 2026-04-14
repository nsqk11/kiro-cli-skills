# docx-toolkit

JSON-based docx editing toolkit for Kiro CLI.

Extracts `.docx` structure into a flat JSON node map (UUID-keyed sections with heading/content/children), lets LLM read and edit via change instructions, then applies changes back to docx. Roundtrip-verified on real NDS documents.

## Scripts

| Script | Purpose |
|--------|---------|
| `extract.py` | docx → JSON (structure extraction with stable UUIDs) |
| `tree.py` | JSON tree operations: `show`, `get`, `apply` change instructions |
| `apply.py` | JSON → docx (full rebuild using original docx as style template) |

## Quick Start

```bash
# Extract docx → JSON
python3 scripts/extract.py input.docx -o doc.json

# View tree structure
python3 scripts/tree.py show doc.json

# Get a specific node
python3 scripts/tree.py get doc.json nd-a1b2c3d4

# Apply change instructions
python3 scripts/tree.py apply doc.json '[{"op":"rename","id":"nd-a1b2c3d4","heading":"New Title"}]'

# Rebuild docx from JSON
python3 scripts/apply.py input.docx doc.json -o output.docx
```

Run `python3 <script> --help` for full usage.

## Supported Content

- Headings (any level), paragraphs, tables, bullet/number lists, images
- Inline formatting: bold, italic, hyperlinks
- 5 change operations: `update`, `rename`, `delete`, `add`, `move`

## Requirements

- Python 3.6+
- python-docx
