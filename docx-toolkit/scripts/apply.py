#!/usr/bin/env python3
"""Apply JSON tree back to docx. Reads original docx as template for styles,
then rebuilds document body from JSON."""
import argparse
import json
import os
import sys
from docx import Document
from docx.shared import Pt
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


def make_hyperlink(paragraph, text, url):
    """Add a hyperlink run to a paragraph."""
    part = paragraph.part
    r_id = part.relate_to(url, "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink", is_external=True)
    hyperlink = OxmlElement('w:hyperlink')
    hyperlink.set(qn('r:id'), r_id)
    run_el = OxmlElement('w:r')
    rpr = OxmlElement('w:rPr')
    rstyle = OxmlElement('w:rStyle')
    rstyle.set(qn('w:val'), 'Hyperlink')
    rpr.append(rstyle)
    run_el.append(rpr)
    t = OxmlElement('w:t')
    t.set(qn('xml:space'), 'preserve')
    t.text = text
    run_el.append(t)
    hyperlink.append(run_el)
    paragraph._element.append(hyperlink)


def add_runs(paragraph, runs):
    """Add runs to a paragraph with formatting."""
    for r in runs:
        text = r.get("text", "")
        if "hyperlink" in r:
            make_hyperlink(paragraph, text, r["hyperlink"])
        else:
            run = paragraph.add_run(text)
            if r.get("bold"):
                run.bold = True
            if r.get("italic"):
                run.italic = True


def add_content_blocks(doc, content):
    """Add content blocks (paragraphs, tables, lists, images) to document."""
    for block in content:
        btype = block.get("type")
        if btype == "paragraph":
            p = doc.add_paragraph()
            add_runs(p, block.get("runs", []))
        elif btype == "table":
            rows = block.get("rows", [])
            if not rows:
                continue
            ncols = max(len(row) for row in rows)
            tbl = doc.add_table(rows=0, cols=ncols)
            for row_data in rows:
                row = tbl.add_row()
                for i, cell_data in enumerate(row_data):
                    if i < ncols:
                        cell = row.cells[i]
                        # Clear default paragraph
                        cell.paragraphs[0].clear()
                        add_runs(cell.paragraphs[0], cell_data.get("runs", []))
        elif btype == "list":
            style_name = "List Bullet" if block.get("style") == "bullet" else "List Number"
            for item in block.get("items", []):
                p = doc.add_paragraph(style=style_name)
                add_runs(p, item.get("runs", []))
        elif btype == "image":
            filename = block.get("filename", "")
            # Try to find image in same directory as source docx
            p = doc.add_paragraph()
            p.add_run("[Image: {}]".format(filename))


def build_doc(data, template_path):
    """Build a new docx from JSON tree using template for styles."""
    doc = Document(template_path)

    # Clear existing body content
    body = doc.element.body
    for child in list(body):
        tag = child.tag
        if tag in (qn('w:p'), qn('w:tbl')):
            body.remove(child)

    nodes = data["nodes"]

    def render_node(nid):
        node = nodes[nid]
        heading = node.get("heading", "")
        level = node.get("level", 0)
        content = node.get("content", [])
        children = node.get("children", [])

        # Add heading (skip level 0 preamble heading)
        if level > 0 and heading:
            doc.add_heading(heading, level=level)

        # Add content blocks
        add_content_blocks(doc, content)

        # Recurse into children
        for cid in children:
            render_node(cid)

    for rid in data["root"]:
        render_node(rid)

    return doc


def main():
    parser = argparse.ArgumentParser(description="Apply JSON tree to docx")
    parser.add_argument("template", help="Template/original .docx file (used for styles)")
    parser.add_argument("json_file", help="JSON tree file")
    parser.add_argument("-o", "--output", required=True, help="Output .docx file")
    args = parser.parse_args()

    data = load_json(args.json_file)
    doc = build_doc(data, args.template)
    doc.save(args.output)
    print("Saved to {}".format(args.output))


def load_json(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


if __name__ == "__main__":
    main()
