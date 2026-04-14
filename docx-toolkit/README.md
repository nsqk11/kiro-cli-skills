# docx-toolkit

JSON-based docx editing toolkit for Kiro CLI.

Extracts `.docx` structure into a flat JSON node map (UUID-keyed sections), lets LLM read and edit via change instructions, then applies changes back to docx.

## Usage

```bash
# Extract docx → JSON
python3 scripts/extract.py input.docx -o doc.json

# View tree structure
python3 scripts/tree.py show doc.json

# Apply change instructions
python3 scripts/tree.py apply doc.json instructions.json -o doc_modified.json

# Write back to docx
python3 scripts/apply.py input.docx doc_modified.json -o output.docx
```

## Requirements

- Python 3.6+
- python-docx
