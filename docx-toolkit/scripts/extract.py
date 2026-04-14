#!/usr/bin/env python3
"""Extract docx body into flat JSON node map keyed by body index."""
import argparse
import json
import os
from docx import Document
from docx.oxml.ns import qn


MC_NS = 'http://schemas.openxmlformats.org/markup-compatibility/2006'


def _run_text(run_el):
    parts = []
    for el in run_el:
        if el.tag == qn('w:t') and el.text:
            parts.append(el.text)
        elif el.tag == qn('w:br'):
            parts.append('\n')
        elif el.tag == qn('w:tab'):
            parts.append('\t')
    return ''.join(parts)


def _extract_run(run_el):
    text = _run_text(run_el)
    if not text:
        return None
    run = {"text": text}
    rpr = run_el.find(qn('w:rPr'))
    if rpr is not None:
        if rpr.find(qn('w:b')) is not None:
            run["bold"] = True
        if rpr.find(qn('w:i')) is not None:
            run["italic"] = True
        if rpr.find(qn('w:vanish')) is not None:
            run["hidden"] = True
    return run


def extract_runs(para_el, part):
    """Extract runs from a w:p element, preserving hyperlinks and field display text."""
    runs = []
    in_field_code = False
    for child in para_el:
        if child.tag == qn('w:r'):
            for fc in child.findall(qn('w:fldChar')):
                ft = fc.get(qn('w:fldCharType'))
                if ft == 'begin':
                    in_field_code = True
                elif ft in ('separate', 'end'):
                    in_field_code = False
            if in_field_code:
                continue
            r = _extract_run(child)
            if r:
                runs.append(r)
        elif child.tag == qn('w:hyperlink'):
            if in_field_code:
                continue
            r_id = child.get(qn('r:id'))
            url = ""
            if r_id and r_id in part.rels:
                url = part.rels[r_id].target_ref
            texts = []
            for r in child.findall(qn('w:r')):
                t = _run_text(r)
                if t:
                    texts.append(t)
            if texts:
                run = {"text": "".join(texts)}
                if url:
                    run["hyperlink"] = url
                runs.append(run)
        elif child.tag == qn('w:sdt'):
            sdt_content = child.find(qn('w:sdtContent'))
            if sdt_content is not None:
                for r in sdt_content.findall(qn('w:r')):
                    run = _extract_run(r)
                    if run:
                        runs.append(run)
    return runs


def runs_to_text(runs):
    return "".join(r.get("text", "") for r in runs)


def extract_table(tbl_el, part):
    rows = []
    for ri, tr in enumerate(tbl_el.findall(qn('w:tr'))):
        for ci, tc in enumerate(tr.findall(qn('w:tc'))):
            cell_runs = []
            for pi, p in enumerate(tc.findall(qn('w:p'))):
                if pi > 0 and cell_runs:
                    cell_runs.append({"text": "\n"})
                cell_runs.extend(extract_runs(p, part))
            cell = {"row": ri, "col": ci, "text": runs_to_text(cell_runs), "runs": cell_runs}
            # shading
            shd = tc.find(f'.//{qn("w:shd")}')
            if shd is not None:
                fill = shd.get(qn('w:fill'))
                if fill and fill.upper() not in ('AUTO', 'FFFFFF'):
                    cell["shading"] = fill
            rows.append(cell)
    return rows


def get_heading_level(para_el):
    ppr = para_el.find(qn('w:pPr'))
    if ppr is None:
        return 0
    pstyle = ppr.find(qn('w:pStyle'))
    if pstyle is None:
        return 0
    val = pstyle.get(qn('w:val'), '')
    if val.startswith('Heading'):
        try:
            return int(val.replace('Heading', ''))
        except ValueError:
            pass
    return 0


def get_style_name(para_el):
    ppr = para_el.find(qn('w:pPr'))
    if ppr is None:
        return None
    pstyle = ppr.find(qn('w:pStyle'))
    if pstyle is None:
        return None
    return pstyle.get(qn('w:val'), None)


def is_list_para(para_el):
    ppr = para_el.find(qn('w:pPr'))
    if ppr is None:
        return False
    return ppr.find(qn('w:numPr')) is not None


def get_table_style(tbl_el):
    tpr = tbl_el.find(qn('w:tblPr'))
    if tpr is not None:
        ts = tpr.find(qn('w:tblStyle'))
        if ts is not None:
            return ts.get(qn('w:val'))
    return None


def extract(docx_path):
    doc = Document(docx_path)
    part = doc.part
    body = doc.element.body
    children = list(body)

    nodes = {}
    sections = {}
    # heading stack: [(section_path, level)]
    heading_stack = []

    for i, el in enumerate(children):
        tag = el.tag
        if tag == qn('w:p'):
            level = get_heading_level(el)
            style = get_style_name(el)
            has_ac = el.find(f'.//{{{MC_NS}}}AlternateContent') is not None
            runs = extract_runs(el, part)
            text = runs_to_text(runs)

            if has_ac:
                from lxml import etree
                nodes[str(i)] = {
                    "tag": "p", "style": style, "text": "[AlternateContent]",
                    "raw_xml": etree.tostring(el, encoding='unicode')
                }
                continue

            if level > 0:
                # update heading stack
                while heading_stack and heading_stack[-1][1] >= level:
                    heading_stack.pop()
                if heading_stack:
                    section_path = heading_stack[-1][0] + " > " + text.strip()
                else:
                    section_path = text.strip()
                heading_stack.append((section_path, level))

                nodes[str(i)] = {
                    "tag": "p", "style": style or f"Heading{level}",
                    "text": text.strip(), "section": section_path, "level": level
                }
                sections[section_path] = {"idx": i, "level": level, "children": []}
                # register as child of parent section
                if len(heading_stack) >= 2:
                    parent_path = heading_stack[-2][0]
                    if parent_path in sections:
                        sections[parent_path]["children"].append(section_path)
            elif is_list_para(el):
                node = {"tag": "p", "style": style, "text": text, "runs": runs, "list": True}
                nodes[str(i)] = node
            else:
                node = {"tag": "p", "text": text, "runs": runs}
                if style and style != "Normal":
                    node["style"] = style
                nodes[str(i)] = node

        elif tag == qn('w:tbl'):
            tbl_style = get_table_style(el)
            cells = extract_table(el, part)
            node = {"tag": "tbl", "cells": cells}
            if tbl_style:
                node["style"] = tbl_style
            nodes[str(i)] = node

        elif tag == qn('w:sdt'):
            # structured document tag at body level — record as opaque
            nodes[str(i)] = {"tag": "sdt", "text": "[StructuredDocumentTag]"}

        # skip w:sectPr and other non-content elements

    return {
        "meta": {"source": os.path.basename(docx_path), "body_count": len(children)},
        "nodes": nodes,
        "sections": sections
    }


def main():
    parser = argparse.ArgumentParser(description="Extract docx to flat JSON (body-index keyed)")
    parser.add_argument("input", help="Input .docx file")
    parser.add_argument("-o", "--output", help="Output .json file (default: stdout)")
    args = parser.parse_args()

    result = extract(args.input)
    out = json.dumps(result, ensure_ascii=False, indent=2)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(out)
        print(f"Extracted {len(result['nodes'])} nodes, {len(result['sections'])} sections to {args.output}")
    else:
        print(out)


if __name__ == "__main__":
    main()
