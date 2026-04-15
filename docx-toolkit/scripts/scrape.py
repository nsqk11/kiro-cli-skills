#!/usr/bin/env python3
"""Scrape docx body into flat JSON node map keyed by body index."""

import argparse
import json
import os
from typing import Any, Dict, List, Optional, Tuple

from lxml import etree
from docx import Document
from docx.oxml.ns import qn

# XML namespace constants.
_MC_NS = 'http://schemas.openxmlformats.org/markup-compatibility/2006'
_WP_NS = ('http://schemas.openxmlformats.org/drawingml/2006/'
           'wordprocessingDrawing')
_A_NS = 'http://schemas.openxmlformats.org/drawingml/2006/main'

# Type aliases.
RunDict = Dict[str, Any]
NodeDict = Dict[str, Any]


def _run_text(run_el: etree._Element) -> str:
    """Extract plain text from a ``w:r`` element."""
    parts: List[str] = []
    for child in run_el:
        if child.tag == qn('w:t') and child.text:
            parts.append(child.text)
        elif child.tag == qn('w:br'):
            parts.append('\n')
        elif child.tag == qn('w:tab'):
            parts.append('\t')
    return ''.join(parts)


def _extract_image(
    run_el: etree._Element,
    part: Any,
) -> Optional[RunDict]:
    """Return image info dict if *run_el* contains ``w:drawing``/``w:pict``."""
    drawing = run_el.find(qn('w:drawing'))
    if drawing is not None:
        img: RunDict = {}
        inline = (drawing.find(f'{{{_WP_NS}}}inline')
                  or drawing.find(f'{{{_WP_NS}}}anchor'))
        if inline is not None:
            cx = inline.get('cx')
            cy = inline.get('cy')
            if cx:
                img['width_emu'] = int(cx)
            if cy:
                img['height_emu'] = int(cy)
            doc_pr = inline.find(f'{{{_WP_NS}}}docPr')
            if doc_pr is not None:
                alt = doc_pr.get('descr')
                if alt:
                    img['alt'] = alt
            blip = inline.find(f'.//{{{_A_NS}}}blip')
            if blip is not None:
                r_embed = blip.get(qn('r:embed'))
                if r_embed and r_embed in part.rels:
                    img['rId'] = r_embed
                    img['target'] = part.rels[r_embed].target_ref
        img['image'] = True
        return img
    if run_el.find(qn('w:pict')) is not None:
        return {'image': True}
    return None


def _extract_run(run_el: etree._Element) -> Optional[RunDict]:
    """Extract text and formatting from a single ``w:r`` element."""
    text = _run_text(run_el)
    if not text:
        return None
    run: RunDict = {'text': text}
    rpr = run_el.find(qn('w:rPr'))
    if rpr is not None:
        if rpr.find(qn('w:b')) is not None:
            run['bold'] = True
        if rpr.find(qn('w:i')) is not None:
            run['italic'] = True
        if rpr.find(qn('w:vanish')) is not None:
            run['hidden'] = True
    return run


def _extract_runs(
    para_el: etree._Element,
    part: Any,
) -> List[RunDict]:
    """Extract runs from a ``w:p``, preserving hyperlinks and field text."""
    runs: List[RunDict] = []
    in_field = False
    for child in para_el:
        if child.tag == qn('w:r'):
            for fc in child.findall(qn('w:fldChar')):
                ftype = fc.get(qn('w:fldCharType'))
                if ftype == 'begin':
                    in_field = True
                elif ftype in ('separate', 'end'):
                    in_field = False
            if in_field:
                continue
            img = _extract_image(child, part)
            if img:
                runs.append(img)
                continue
            run = _extract_run(child)
            if run:
                runs.append(run)
        elif child.tag == qn('w:hyperlink'):
            if in_field:
                continue
            r_id = child.get(qn('r:id'))
            url = ''
            if r_id and r_id in part.rels:
                url = part.rels[r_id].target_ref
            texts = [_run_text(r) for r in child.findall(qn('w:r'))]
            joined = ''.join(t for t in texts if t)
            if joined:
                entry: RunDict = {'text': joined}
                if url:
                    entry['hyperlink'] = url
                runs.append(entry)
        elif child.tag == qn('w:sdt'):
            sdt_content = child.find(qn('w:sdtContent'))
            if sdt_content is not None:
                for r in sdt_content.findall(qn('w:r')):
                    run = _extract_run(r)
                    if run:
                        runs.append(run)
    return runs


def _runs_to_text(runs: List[RunDict]) -> str:
    """Concatenate plain text from a runs list."""
    return ''.join(r.get('text', '') for r in runs)


def _extract_table(
    tbl_el: etree._Element,
    part: Any,
) -> List[Dict[str, Any]]:
    """Extract all cells from a ``w:tbl`` element."""
    cells: List[Dict[str, Any]] = []
    for row_idx, tr in enumerate(tbl_el.findall(qn('w:tr'))):
        for col_idx, tc in enumerate(tr.findall(qn('w:tc'))):
            cell_runs: List[RunDict] = []
            for para_idx, para in enumerate(tc.findall(qn('w:p'))):
                if para_idx > 0 and cell_runs:
                    cell_runs.append({'text': '\n'})
                cell_runs.extend(_extract_runs(para, part))
            cell: Dict[str, Any] = {
                'row': row_idx,
                'col': col_idx,
                'text': _runs_to_text(cell_runs),
                'runs': cell_runs,
            }
            shd = tc.find(f'.//{qn("w:shd")}')
            if shd is not None:
                fill = shd.get(qn('w:fill'))
                if fill and fill.upper() not in ('AUTO', 'FFFFFF'):
                    cell['shading'] = fill
            cells.append(cell)
    return cells


def _get_heading_level(para_el: etree._Element) -> int:
    """Return heading level (1-9) or 0 if not a heading."""
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


def _get_style_name(para_el: etree._Element) -> Optional[str]:
    """Return paragraph style name or ``None``."""
    ppr = para_el.find(qn('w:pPr'))
    if ppr is None:
        return None
    pstyle = ppr.find(qn('w:pStyle'))
    if pstyle is None:
        return None
    return pstyle.get(qn('w:val'))


def _is_list_para(para_el: etree._Element) -> bool:
    """Return ``True`` if the paragraph has numbering properties."""
    ppr = para_el.find(qn('w:pPr'))
    if ppr is None:
        return False
    return ppr.find(qn('w:numPr')) is not None


def _get_table_style(tbl_el: etree._Element) -> Optional[str]:
    """Return table style name or ``None``."""
    tpr = tbl_el.find(qn('w:tblPr'))
    if tpr is not None:
        ts = tpr.find(qn('w:tblStyle'))
        if ts is not None:
            return ts.get(qn('w:val'))
    return None


# --- comments ---


def _parse_comments(doc: Document) -> Dict[str, Dict[str, str]]:
    """Parse ``comments.xml`` and return ``{id: {author, date, text}}``."""
    comments: Dict[str, Dict[str, str]] = {}
    for rel in doc.part.rels.values():
        if 'comments' not in rel.reltype:
            continue
        try:
            cxml = rel.target_part.element
        except AttributeError:
            cxml = etree.fromstring(rel.target_part.blob)
        for comment in cxml.findall(qn('w:comment')):
            cid = comment.get(qn('w:id'))
            if cid is None:
                continue
            author = comment.get(qn('w:author'), '')
            date = comment.get(qn('w:date'), '')
            texts: List[str] = []
            for para in comment.findall(qn('w:p')):
                for run in para.findall(qn('w:r')):
                    for t_el in run.findall(qn('w:t')):
                        if t_el.text:
                            texts.append(t_el.text)
            comments[cid] = {
                'author': author,
                'date': date,
                'text': ''.join(texts),
            }
        break
    return comments


def _map_comments_to_body(
    children: List[etree._Element],
) -> Dict[str, int]:
    """Map comment IDs to body element indices via ``w:commentRangeStart``."""
    mapping: Dict[str, int] = {}
    for idx, el in enumerate(children):
        for crs in el.iter(qn('w:commentRangeStart')):
            cid = crs.get(qn('w:id'))
            if cid is not None:
                mapping[cid] = idx
    return mapping


# --- main extraction ---


def _process_paragraph(
    idx: int,
    el: etree._Element,
    part: Any,
    heading_stack: List[Tuple[str, int]],
    sections: Dict[str, Dict[str, Any]],
) -> Optional[NodeDict]:
    """Process a single ``w:p`` element and return its node dict."""
    level = _get_heading_level(el)
    style = _get_style_name(el)
    has_ac = (
        el.find(f'.//{{{_MC_NS}}}AlternateContent') is not None
    )
    runs = _extract_runs(el, part)
    text = _runs_to_text(runs)

    if has_ac:
        return {
            'tag': 'p',
            'style': style,
            'text': '[AlternateContent]',
            'raw_xml': etree.tostring(el, encoding='unicode'),
        }

    if level > 0:
        while heading_stack and heading_stack[-1][1] >= level:
            heading_stack.pop()
        if heading_stack:
            section_path = (
                heading_stack[-1][0] + ' > ' + text.strip()
            )
        else:
            section_path = text.strip()
        heading_stack.append((section_path, level))
        sections[section_path] = {
            'idx': idx, 'level': level, 'children': [],
        }
        if len(heading_stack) >= 2:
            parent = heading_stack[-2][0]
            if parent in sections:
                sections[parent]['children'].append(section_path)
        return {
            'tag': 'p',
            'style': style or f'Heading{level}',
            'text': text.strip(),
            'runs': runs,
            'section': section_path,
            'level': level,
        }

    if _is_list_para(el):
        return {
            'tag': 'p',
            'style': style,
            'text': text,
            'runs': runs,
            'list': True,
        }

    node: NodeDict = {'tag': 'p', 'text': text, 'runs': runs}
    if style and style != 'Normal':
        node['style'] = style
    return node


def extract(docx_path: str) -> Dict[str, Any]:
    """Extract docx body into a flat JSON-serialisable dict.

    Args:
        docx_path: Path to the ``.docx`` file.

    Returns:
        Dict with ``meta``, ``nodes``, and ``sections`` keys.
    """
    doc = Document(docx_path)
    part = doc.part
    children = list(doc.element.body)

    nodes: Dict[str, NodeDict] = {}
    sections: Dict[str, Dict[str, Any]] = {}
    heading_stack: List[Tuple[str, int]] = []

    for idx, el in enumerate(children):
        tag = el.tag
        if tag == qn('w:p'):
            node = _process_paragraph(
                idx, el, part, heading_stack, sections,
            )
            if node is not None:
                nodes[str(idx)] = node
        elif tag == qn('w:tbl'):
            tbl_style = _get_table_style(el)
            cells = _extract_table(el, part)
            node = {'tag': 'tbl', 'cells': cells}
            if tbl_style:
                node['style'] = tbl_style
            nodes[str(idx)] = node
        elif tag == qn('w:sdt'):
            nodes[str(idx)] = {
                'tag': 'sdt',
                'text': '[StructuredDocumentTag]',
            }

    # Attach comments inline.
    comments_data = _parse_comments(doc)
    if comments_data:
        comment_map = _map_comments_to_body(children)
        for cid, body_idx in comment_map.items():
            if cid in comments_data and str(body_idx) in nodes:
                target = nodes[str(body_idx)]
                if 'comments' not in target:
                    target['comments'] = []
                entry = {'id': int(cid)}
                entry.update(comments_data[cid])
                target['comments'].append(entry)

    return {
        'meta': {
            'source': os.path.basename(docx_path),
            'body_count': len(children),
        },
        'nodes': nodes,
        'sections': sections,
    }


def main() -> None:
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Scrape docx to flat JSON (body-index keyed)',
    )
    parser.add_argument('input', help='Input .docx file')
    parser.add_argument(
        '-o', '--output', help='Output .json file (default: stdout)',
    )
    args = parser.parse_args()

    result = extract(args.input)
    out = json.dumps(result, ensure_ascii=False, indent=2)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(out)
        print(
            f"Extracted {len(result['nodes'])} nodes, "
            f"{len(result['sections'])} sections to {args.output}"
        )
    else:
        print(out)


if __name__ == '__main__':
    main()
