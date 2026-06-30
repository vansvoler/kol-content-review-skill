#!/usr/bin/env python3
"""
稿件格式统一解析器

将达人交付的稿件（docx/xlsx/md/txt）统一转换为 markdown，
输出到 stdout，供 agent 进行审稿处理。

PDF 文件请使用当前 agent 环境可用的 PDF 读取能力，本脚本不做 PDF 解析。

用法:
    python3 parse_draft.py <文件路径>
"""

import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


# ═══════════════════════════════════════════════════════════
# XML 命名空间
# ═══════════════════════════════════════════════════════════
W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
S_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
W = f"{{{W_NS}}}"
S = f"{{{S_NS}}}"


# ═══════════════════════════════════════════════════════════
# docx 解析
# ═══════════════════════════════════════════════════════════
def parse_docx(path: Path) -> str:
    """docx → markdown。保留段落和表格在正文中的原始顺序。"""
    with zipfile.ZipFile(path) as z:
        xml_data = z.read("word/document.xml")
    root = ET.fromstring(xml_data)
    body = root.find(f"{W}body")
    if body is None:
        return ""
    blocks = [_render_docx_block(child) for child in body]
    return "\n\n".join(block for block in blocks if block)


def _render_docx_block(elem) -> str:
    """Word body 子节点 → markdown 块。"""
    if elem.tag == f"{W}p":
        return _render_paragraph(elem)
    if elem.tag == f"{W}tbl":
        return _render_docx_table(elem)
    return ""


def _render_paragraph(p) -> str:
    """单段落 → 文本（识别标题样式，渲染为 # 前缀）。"""
    text = "".join(t.text or "" for t in p.iter(f"{W}t"))
    if not text.strip():
        return ""
    style = _get_pstyle(p)
    if style and ("Heading" in style or "heading" in style):
        digits = "".join(c for c in style if c.isdigit())
        level = int(digits) if digits else 1
        return "#" * min(level, 6) + " " + text
    return text


def _get_pstyle(p) -> str:
    """读取段落样式名。"""
    p_pr = p.find(f"{W}pPr")
    if p_pr is None:
        return ""
    p_style = p_pr.find(f"{W}pStyle")
    return p_style.get(f"{W}val", "") if p_style is not None else ""


def _render_docx_table(tbl) -> str:
    """Word 表格 → markdown 表格。"""
    rows = [_render_docx_table_row(row) for row in tbl.findall(f"{W}tr")]
    rows = [row for row in rows if any(cell.strip() for cell in row)]
    return _rows_to_md_table(rows) if rows else ""


def _render_docx_table_row(row) -> list:
    """Word 表格行 → [单元格文本, ...]。"""
    return [_render_docx_table_cell(cell) for cell in row.findall(f"{W}tc")]


def _render_docx_table_cell(cell) -> str:
    """Word 表格单元格 → 文本，单元格内多段用换行连接。"""
    paragraphs = [_render_paragraph(p) for p in cell.findall(f"{W}p")]
    return "\n".join(p for p in paragraphs if p)


# ═══════════════════════════════════════════════════════════
# xlsx 解析
# ═══════════════════════════════════════════════════════════
def parse_xlsx(path: Path) -> str:
    """xlsx → markdown。每个 sheet 输出为独立的 markdown 表格。"""
    with zipfile.ZipFile(path) as z:
        shared = _load_shared_strings(z)
        sheets = _load_sheet_order(z)
        blocks = [_render_sheet(z, sheet_path, name, shared)
                  for name, sheet_path in sheets]
    return "\n\n".join(blocks)


def _load_shared_strings(z: zipfile.ZipFile) -> list:
    """读取 xl/sharedStrings.xml 共享字符串池。"""
    if "xl/sharedStrings.xml" not in z.namelist():
        return []
    root = ET.fromstring(z.read("xl/sharedStrings.xml"))
    return ["".join(t.text or "" for t in si.iter(f"{S}t"))
            for si in root.findall(f"{S}si")]


def _load_sheet_order(z: zipfile.ZipFile) -> list:
    """返回 [(sheet_name, sheet_xml_path), ...]，按 workbook 顺序。"""
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    rels = _load_rels(z, "xl/_rels/workbook.xml.rels")
    sheets_elem = wb.find(f"{S}sheets")
    out = []
    for s in sheets_elem.findall(f"{S}sheet"):
        rid = s.get(f"{{{R_NS}}}id")
        target = rels.get(rid, "")
        out.append((s.get("name"), "xl/" + target.lstrip("/")))
    return out


def _load_rels(z: zipfile.ZipFile, rels_path: str) -> dict:
    """读取 relationships 文件 → {rId: Target}。"""
    rel_tag = f"{{{PKG_NS}}}Relationship"
    root = ET.fromstring(z.read(rels_path))
    return {r.get("Id"): r.get("Target") for r in root.findall(rel_tag)}


def _render_sheet(z, sheet_path: str, name: str, shared: list) -> str:
    """单个 sheet → markdown 表格。"""
    root = ET.fromstring(z.read(sheet_path))
    sheet_data = root.find(f"{S}sheetData")
    if sheet_data is None:
        return f"## {name}\n\n（空表）"
    rows = [_render_row(r, shared) for r in sheet_data.findall(f"{S}row")]
    rows = [r for r in rows if any(cell.strip() for cell in r)]
    if not rows:
        return f"## {name}\n\n（空表）"
    return f"## {name}\n\n{_rows_to_md_table(rows)}"


def _render_row(row, shared: list) -> list:
    """单行 → [单元格文本, ...]"""
    values = []
    for cell in row.findall(f"{S}c"):
        index = _cell_column_index(cell)
        if index is None:
            values.append(_cell_value(cell, shared))
            continue
        while len(values) < index:
            values.append("")
        values[index - 1] = _cell_value(cell, shared)
    return values


def _cell_column_index(cell) -> int | None:
    """从 A1/C12 这类单元格地址提取 1-based 列号。"""
    ref = cell.get("r", "")
    letters = "".join(ch for ch in ref if ch.isalpha())
    if not letters:
        return None
    index = 0
    for letter in letters.upper():
        index = index * 26 + ord(letter) - ord("A") + 1
    return index


def _cell_value(c, shared: list) -> str:
    """读取单元格值：共享字符串池引用 or 内联值。"""
    t_attr = c.get("t", "")
    v = c.find(f"{S}v")
    if v is None:
        inline = c.find(f"{S}is")
        if inline is not None:
            return "".join(n.text or "" for n in inline.iter(f"{S}t"))
        return ""
    if t_attr == "s":
        idx = int(v.text)
        return shared[idx] if 0 <= idx < len(shared) else ""
    return v.text or ""


def _rows_to_md_table(rows: list) -> str:
    """行列表 → markdown 表格（首行为表头）。"""
    width = max(len(r) for r in rows)
    padded = [r + [""] * (width - len(r)) for r in rows]
    header = "| " + " | ".join(_escape(c) for c in padded[0]) + " |"
    sep = "| " + " | ".join(["---"] * width) + " |"
    body_rows = ["| " + " | ".join(_escape(c) for c in r) + " |"
                 for r in padded[1:]]
    return "\n".join([header, sep] + body_rows) if body_rows else f"{header}\n{sep}"


def _escape(cell: str) -> str:
    """表格单元格转义：| 和换行会破坏表格结构。"""
    return cell.replace("|", "\\|").replace("\n", "<br>")


# ═══════════════════════════════════════════════════════════
# 入口调度
# ═══════════════════════════════════════════════════════════
def parse(path: Path) -> str:
    """按扩展名分派解析器。"""
    ext = path.suffix.lower()
    if ext == ".docx":
        return parse_docx(path)
    if ext == ".xlsx":
        return parse_xlsx(path)
    if ext in {".md", ".txt"}:
        return path.read_text(encoding="utf-8")
    if ext == ".pdf":
        return _pdf_hint(path)
    raise ValueError(
        f"不支持的格式: {ext}"
        f"（支持 .docx/.xlsx/.md/.txt；PDF 请用当前环境的 PDF 读取能力处理）"
    )


def _pdf_hint(path: Path) -> str:
    """PDF 文件提示信息。"""
    return (
        f"# PDF 文件\n\n"
        f"本脚本不处理 PDF 解析。请使用当前 agent 环境的 PDF 读取能力处理:\n"
        f"  {path.resolve()}\n"
    )


def main():
    if len(sys.argv) != 2:
        print("用法: python3 parse_draft.py <文件路径>", file=sys.stderr)
        sys.exit(1)
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"文件不存在: {path}", file=sys.stderr)
        sys.exit(2)
    try:
        print(parse(path))
    except Exception as e:
        print(f"解析失败: {e}", file=sys.stderr)
        sys.exit(3)


if __name__ == "__main__":
    main()
