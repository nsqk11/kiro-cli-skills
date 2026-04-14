#!/usr/bin/env python3
"""Surgical patch: apply change instructions to docx by modifying XML in-place.

Usage:
  python3 patch.py input.docx instructions.json [-o output.docx]

If -o is omitted, input.docx is overwritten.

Instructions format (JSON array):
  [
    {"op": "update_text",    "idx": 4, "run": 0, "text": "New text"},
    {"op": "update_runs",    "idx": 4, "runs": [{"text": "Hello", "bold": true}]},
    {"op": "update_cell",    "idx": 5, "row": 0, "col": 1, "runs": [{"text": "Done"}]},
    {"op": "rename_heading", "idx": 3, "text": "New Heading"},
    {"op": "delete",         "idx": 7},
    {"op": "add_after",      "idx": 4, "runs": [{"text": "New para"}], "clone_style_from": 4},
    {"op": "add_table_after","idx": 4, "rows": [[{"runs":[{"text":"A"}]},{"runs":[{"text":"B"}]}]], "clone_style_from": 5},
    {"op": "move",           "idx": 10, "after": 4}
  ]
"""
import argparse
import json
import sys
from copy import deepcopy
from docx import Document
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


# --- helpers ---

def _clear_runs(p_el):
    """Remove all w:r and w:hyperlink children from a w:p, keeping w:pPr."""
    for child in list(p_el):
        if child.tag in (qn('w:r'), qn('w:hyperlink')):
            p_el.remove(child)


def _build_run_el(run_dict):
    """Build a w:r element from {"text": ..., "bold": ..., "italic": ..., "hyperlink": ...}."""
    r = OxmlElement('w:r')
    rpr = OxmlElement('w:rPr')
    has_props = False
    if run_dict.get('bold'):
        rpr.append(OxmlElement('w:b'))
        has_props = True
    if run_dict.get('italic'):
        rpr.append(OxmlElement('w:i'))
        has_props = True
    if run_dict.get('hidden'):
        rpr.append(OxmlElement('w:vanish'))
        has_props = True
    if has_props:
        r.append(rpr)
    # handle \n and \t in text
    text = run_dict.get('text', '')
    parts = []
    buf = []
    for ch in text:
        if ch == '\n':
            if buf:
                parts.append(('t', ''.join(buf)))
                buf = []
            parts.append(('br', None))
        elif ch == '\t':
            if buf:
                parts.append(('t', ''.join(buf)))
                buf = []
            parts.append(('tab', None))
        else:
            buf.append(ch)
    if buf:
        parts.append(('t', ''.join(buf)))
    for kind, val in parts:
        if kind == 't':
            t = OxmlElement('w:t')
            t.set(qn('xml:space'), 'preserve')
            t.text = val
            r.append(t)
        elif kind == 'br':
            r.append(OxmlElement('w:br'))
        elif kind == 'tab':
            r.append(OxmlElement('w:tab'))
    return r


def _build_hyperlink_el(part, run_dict):
    """Build a w:hyperlink element."""
    url = run_dict['hyperlink']
    r_id = part.relate_to(
        url,
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        is_external=True
    )
    hl = OxmlElement('w:hyperlink')
    hl.set(qn('r:id'), r_id)
    r = OxmlElement('w:r')
    rpr = OxmlElement('w:rPr')
    rs = OxmlElement('w:rStyle')
    rs.set(qn('w:val'), 'Hyperlink')
    rpr.append(rs)
    r.append(rpr)
    t = OxmlElement('w:t')
    t.set(qn('xml:space'), 'preserve')
    t.text = run_dict.get('text', '')
    r.append(t)
    hl.append(r)
    return hl


def _inject_runs(p_el, runs, part):
    """Append run elements to a w:p from a runs list."""
    for rd in runs:
        if rd.get('hyperlink'):
            p_el.append(_build_hyperlink_el(part, rd))
        else:
            p_el.append(_build_run_el(rd))


def _get_cell_el(tbl_el, row, col):
    """Get w:tc element at row, col."""
    trs = tbl_el.findall(qn('w:tr'))
    if row >= len(trs):
        raise ValueError(f"Row {row} out of range (table has {len(trs)} rows)")
    tcs = trs[row].findall(qn('w:tc'))
    if col >= len(tcs):
        raise ValueError(f"Col {col} out of range (row {row} has {len(tcs)} cols)")
    return tcs[col]


# --- ops ---

def op_update_text(body, idx, instr, part):
    """Change text of a specific run, preserving all formatting."""
    el = body[idx]
    run_idx = instr['run']
    new_text = instr['text']
    runs = el.findall(qn('w:r'))
    # also count hyperlink runs
    all_runs = []
    for child in el:
        if child.tag == qn('w:r'):
            all_runs.append(child)
        elif child.tag == qn('w:hyperlink'):
            for r in child.findall(qn('w:r')):
                all_runs.append(r)
    if run_idx >= len(all_runs):
        raise ValueError(f"Run index {run_idx} out of range (element has {len(all_runs)} runs)")
    target_run = all_runs[run_idx]
    # replace all w:t content
    for t in target_run.findall(qn('w:t')):
        target_run.remove(t)
    for br in target_run.findall(qn('w:br')):
        target_run.remove(br)
    for tab in target_run.findall(qn('w:tab')):
        target_run.remove(tab)
    t = OxmlElement('w:t')
    t.set(qn('xml:space'), 'preserve')
    t.text = new_text
    target_run.append(t)


def op_update_runs(body, idx, instr, part):
    """Replace all runs in a paragraph, preserving pPr."""
    el = body[idx]
    _clear_runs(el)
    _inject_runs(el, instr['runs'], part)


def op_update_cell(body, idx, instr, part):
    """Update a specific table cell's content."""
    tbl_el = body[idx]
    tc = _get_cell_el(tbl_el, instr['row'], instr['col'])
    # clear all paragraphs in cell, keep first one for runs
    paras = tc.findall(qn('w:p'))
    for p in paras[1:]:
        tc.remove(p)
    if paras:
        _clear_runs(paras[0])
        _inject_runs(paras[0], instr['runs'], part)
    else:
        p = OxmlElement('w:p')
        _inject_runs(p, instr['runs'], part)
        tc.append(p)


def op_rename_heading(body, idx, instr, part):
    """Change heading text only, preserving all formatting."""
    el = body[idx]
    # find first w:r with w:t
    for r in el.findall(qn('w:r')):
        t = r.find(qn('w:t'))
        if t is not None:
            t.text = instr['text']
            # remove subsequent runs (heading usually has one run)
            break
    # if multi-run heading, clear extra runs and put all text in first
    runs = el.findall(qn('w:r'))
    if len(runs) > 1:
        first_t = runs[0].find(qn('w:t'))
        if first_t is not None:
            first_t.text = instr['text']
        for r in runs[1:]:
            el.remove(r)


def op_delete(body, idx, instr, part):
    """Remove element from body."""
    el = body[idx]
    body.remove(el)


def op_add_after(body, idx, instr, part):
    """Insert a new paragraph after body[idx], optionally cloning style."""
    ref = body[idx]
    clone_from = instr.get('clone_style_from')
    if clone_from is not None:
        source = body[clone_from]
        new_p = deepcopy(source)
        _clear_runs(new_p)
    else:
        new_p = OxmlElement('w:p')
    _inject_runs(new_p, instr['runs'], part)
    ref.addnext(new_p)


def op_add_table_after(body, idx, instr, part):
    """Insert a new table after body[idx], optionally cloning style from existing table."""
    ref = body[idx]
    clone_from = instr.get('clone_style_from')
    if clone_from is not None:
        source = body[clone_from]
        # clone tblPr only
        new_tbl = OxmlElement('w:tbl')
        src_tpr = source.find(qn('w:tblPr'))
        if src_tpr is not None:
            new_tbl.append(deepcopy(src_tpr))
        src_grid = source.find(qn('w:tblGrid'))
        if src_grid is not None:
            new_tbl.append(deepcopy(src_grid))
    else:
        new_tbl = OxmlElement('w:tbl')
    for row_data in instr['rows']:
        tr = OxmlElement('w:tr')
        for cell_data in row_data:
            tc = OxmlElement('w:tc')
            p = OxmlElement('w:p')
            _inject_runs(p, cell_data.get('runs', []), part)
            tc.append(p)
            tr.append(tc)
        new_tbl.append(tr)
    ref.addnext(new_tbl)


def op_move(body, idx, instr, part):
    """Move element to after another element."""
    el = body[idx]
    body.remove(el)
    after_idx = instr['after']
    # after removal, indices shift — find target by scanning
    target = body[after_idx] if after_idx < len(body) else None
    if target is not None:
        target.addnext(el)
    else:
        body.append(el)


# --- execution engine ---

OPS_MODIFY = {
    'update_text': op_update_text,
    'update_runs': op_update_runs,
    'update_cell': op_update_cell,
    'rename_heading': op_rename_heading,
}

OPS_STRUCTURAL = {
    'delete': op_delete,
    'add_after': op_add_after,
    'add_table_after': op_add_table_after,
    'move': op_move,
}

ALL_OPS = {**OPS_MODIFY, **OPS_STRUCTURAL}


def apply_instructions(doc, instructions):
    """Apply instructions to doc in safe order."""
    body = doc.element.body
    part = doc.part

    # Phase 1: modifications (don't change body length, safe in any order)
    mods = [i for i in instructions if i['op'] in OPS_MODIFY]
    for instr in mods:
        OPS_MODIFY[instr['op']](body, instr['idx'], instr, part)

    # Phase 2: structural changes — sort by idx descending to avoid drift
    structs = [i for i in instructions if i['op'] in OPS_STRUCTURAL]
    structs.sort(key=lambda i: i['idx'], reverse=True)
    for instr in structs:
        OPS_STRUCTURAL[instr['op']](body, instr['idx'], instr, part)

    return len(mods) + len(structs)


def main():
    parser = argparse.ArgumentParser(
        description="Surgical patch: apply change instructions to docx in-place",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("docx", help="Input .docx file")
    parser.add_argument("instructions", help="Instructions JSON file")
    parser.add_argument("-o", "--output", help="Output .docx (default: overwrite input)")
    args = parser.parse_args()

    with open(args.instructions, 'r', encoding='utf-8') as f:
        instructions = json.load(f)

    doc = Document(args.docx)
    count = apply_instructions(doc, instructions)
    out_path = args.output or args.docx
    doc.save(out_path)
    print(f"Applied {count} instructions, saved to {out_path}")
    print("Re-extract recommended: python3 extract.py", out_path)


if __name__ == "__main__":
    main()
