#!/usr/bin/env python3
"""
稿件格式统一解析器

将达人交付的稿件（docx/xlsx/md/txt）统一转换为 markdown，
输出到 stdout，供 Claude 进行审稿处理。

PDF 文件请直接用 Claude Read tool 原生读取，本脚本不做 PDF 解析。

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
    """docx → markdown。标题样式映射为 #，其余为纯文本段落。"""
    with zipfile.ZipFile(path) as z:
        xml_data = z.read("word/document.xml")
    root = ET.fromstring(xml_data)
    body = root.find(f"{W}body")
    if body is None:
        return ""
    lines = [_render_paragraph(p) for p in body.findall(f"{W}p")]
    return "\n\n".join(line for line in lines if line)


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
    return [_cell_value(c, shared) for c in row.findall(f"{S}c")]


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
        f"（支持 .docx/.xlsx/.md/.txt；PDF 请用 Claude Read tool 原生读取）"
    )


def _pdf_hint(path: Path) -> str:
    """PDF 文件提示信息。"""
    return (
        f"# PDF 文件\n\n"
        f"本脚本不处理 PDF 解析。请调用 Claude Read tool 直接读取:\n"
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
