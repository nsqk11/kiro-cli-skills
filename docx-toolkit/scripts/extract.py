#!/usr/bin/env python3
"""Extract docx structure into JSON node map."""
import argparse
import json
import os
import uuid
import re
from docx import Document
from docx.oxml.ns import qn


def gen_id():
    return "nd-" + uuid.uuid4().hex[:8]


def _run_text(run_el):
    """Extract text from a w:r element, including br and tab."""
    parts = []
    for el in run_el:
        if el.tag == qn('w:t') and el.text:
            parts.append(el.text)
        elif el.tag == qn('w:br'):
            parts.append('\n')
        elif el.tag == qn('w:tab'):
            parts.append('\t')
    return ''.join(parts)


def extract_runs(paragraph):
    """Extract runs from a paragraph, preserving inline formatting and hyperlinks."""
    runs = []
    in_field_code = False
    for child in paragraph._element:
        if child.tag == qn('w:r'):
            # Track field: skip instruction (begin→separate), keep display (separate→end)
            for fc in child.findall(qn('w:fldChar')):
                ftype = fc.get(qn('w:fldCharType'))
                if ftype == 'begin':
                    in_field_code = True
                elif ftype == 'separate':
                    in_field_code = False
                elif ftype == 'end':
                    in_field_code = False
            if in_field_code:
                continue
            rpr = child.find(qn('w:rPr'))
            text = _run_text(child)
            if not text:
                continue
            run = {"text": text}
            if rpr is not None:
                if rpr.find(qn('w:b')) is not None:
                    run["bold"] = True
                if rpr.find(qn('w:i')) is not None:
                    run["italic"] = True
            runs.append(run)
        elif child.tag == qn('w:hyperlink'):
            if in_field_code:
                continue
            r_id = child.get(qn('r:id'))
            url = ""
            if r_id:
                rels = paragraph.part.rels
                if r_id in rels:
                    url = rels[r_id].target_ref
            texts = []
            for r in child.findall(qn('w:r')):
                t = r.find(qn('w:t'))
                if t is not None and t.text:
                    texts.append(t.text)
            if texts:
                run = {"text": "".join(texts)}
                if url:
                    run["hyperlink"] = url
                runs.append(run)
    return runs


def extract_table(table):
    """Extract table as rows of cells, each cell has runs."""
    rows = []
    for row in table.rows:
        cells = []
        for cell in row.cells:
            cell_runs = []
            for i, p in enumerate(cell.paragraphs):
                if i > 0 and cell_runs:
                    cell_runs.append({"text": "\n"})
                cell_runs.extend(extract_runs(p))
            cells.append({"runs": cell_runs})
        rows.append(cells)
    return {"type": "table", "rows": rows}


def extract_image(paragraph):
    """Check if paragraph contains an image, return image block or None."""
    for run in paragraph._element.findall(qn('w:r')):
        drawing = run.find(qn('w:drawing'))
        if drawing is None:
            continue
        blip = drawing.find('.//' + qn('a:blip'))
        if blip is None:
            continue
        r_id = blip.get(qn('r:embed'))
        if not r_id:
            continue
        rels = paragraph.part.rels
        if r_id in rels:
            filename = os.path.basename(rels[r_id].target_ref)
            return {"type": "image", "filename": filename, "alt": ""}
    return None


def is_list_paragraph(paragraph):
    ppr = paragraph._element.find(qn('w:pPr'))
    if ppr is None:
        return False
    return ppr.find(qn('w:numPr')) is not None


def get_heading_level(paragraph):
    """Return heading level (1-4) or 0 if not a heading."""
    style = paragraph.style
    if style and style.name and style.name.startswith('Heading'):
        try:
            return int(style.name.replace('Heading ', ''))
        except ValueError:
            pass
    return 0


def extract(docx_path):
    doc = Document(docx_path)
    nodes = {}
    root = []

    # Stack: [(node_id, level)] to track heading hierarchy
    stack = []
    current_id = None
    current_content = []
    pending_list_items = []
    pending_list_style = "bullet"

    def flush_list():
        nonlocal pending_list_items, pending_list_style
        if pending_list_items:
            current_content.append({
                "type": "list",
                "style": pending_list_style,
                "items": pending_list_items
            })
            pending_list_items = []

    def flush_section():
        nonlocal current_id, current_content
        flush_list()
        if current_id and current_content:
            nodes[current_id]["content"] = current_content
        current_content = []

    for element in doc.element.body:
        tag = element.tag
        if tag == qn('w:p'):
            from docx.text.paragraph import Paragraph
            para = Paragraph(element, doc)
            level = get_heading_level(para)

            # Skip TOC entries — they are auto-generated by Word
            if para.style and para.style.name and para.style.name.startswith('toc'):
                if current_id is None:
                    current_id = gen_id()
                    nodes[current_id] = {
                        "type": "section", "heading": "", "level": 0,
                        "children": [], "content": []
                    }
                    root.insert(0, current_id)
                flush_list()
                block = {"type": "paragraph", "runs": [], "style": para.style.name}
                current_content.append(block)
                continue

            if level > 0:
                flush_section()
                nid = gen_id()
                nodes[nid] = {
                    "type": "section",
                    "heading": para.text.strip(),
                    "level": level,
                    "children": [],
                    "content": []
                }
                while stack and stack[-1][1] >= level:
                    stack.pop()
                if stack:
                    parent_id = stack[-1][0]
                    nodes[parent_id]["children"].append(nid)
                else:
                    root.append(nid)
                stack.append((nid, level))
                current_id = nid
            else:
                if current_id is None:
                    # Content before first heading — create a virtual root section
                    current_id = gen_id()
                    nodes[current_id] = {
                        "type": "section",
                        "heading": "",
                        "level": 0,
                        "children": [],
                        "content": []
                    }
                    root.insert(0, current_id)

                # Check image
                img = extract_image(para)
                if img:
                    flush_list()
                    current_content.append(img)
                elif is_list_paragraph(para):
                    runs = extract_runs(para)
                    item = {"runs": runs}
                    if para.style and para.style.name:
                        item["style"] = para.style.name
                    pending_list_items.append(item)
                else:
                    flush_list()
                    runs = extract_runs(para)
                    block = {"type": "paragraph", "runs": runs}
                    if para.style and para.style.name and para.style.name != "Normal":
                        block["style"] = para.style.name
                    current_content.append(block)

        elif tag == qn('w:tbl'):
            from docx.table import Table
            flush_list()
            tbl = Table(element, doc)
            current_content.append(extract_table(tbl))

    flush_section()

    return {
        "meta": {"source": os.path.basename(docx_path)},
        "root": root,
        "nodes": nodes
    }


def main():
    parser = argparse.ArgumentParser(description="Extract docx to JSON")
    parser.add_argument("input", help="Input .docx file")
    parser.add_argument("-o", "--output", help="Output .json file (default: stdout)")
    args = parser.parse_args()

    result = extract(args.input)
    out = json.dumps(result, ensure_ascii=False, indent=2)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(out)
        print("Extracted {} nodes to {}".format(len(result["nodes"]), args.output))
    else:
        print(out)


if __name__ == "__main__":
    main()
