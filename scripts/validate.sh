#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
TEMP_DIR="$REPO_ROOT/temp/validate"
LOG_FILE="$LOG_DIR/validate.log"

mkdir -p "$LOG_DIR" "$TEMP_DIR"
: > "$LOG_FILE"

log() {
  echo "$*" | tee -a "$LOG_FILE"
}

require_file() {
  if [[ ! -f "$REPO_ROOT/$1" ]]; then
    log "缺少文件: $1"
    exit 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    log "断言失败: ${label} 缺少「${needle}」"
    exit 1
  fi
}

log "== 检查必需文件 =="
require_file "SKILL.md"
require_file "assets/review-report-template.md"
require_file "references/annotation-guide.md"
require_file "references/compliance-words.md"
require_file "references/platform-rules.md"
require_file "references/review-standards.md"
require_file "scripts/parse_draft.py"

log "== 检查 SKILL.md frontmatter =="
python3 - "$REPO_ROOT/SKILL.md" >> "$LOG_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if not text.startswith("---\n"):
    raise SystemExit("SKILL.md 缺少 YAML frontmatter")
end = text.find("\n---\n", 4)
if end == -1:
    raise SystemExit("SKILL.md frontmatter 未闭合")
frontmatter = text[4:end]
for key in ("name:", "description:"):
    if key not in frontmatter:
        raise SystemExit(f"frontmatter 缺少 {key}")
print("frontmatter ok")
PY

log "== 检查 Python 语法 =="
python3 - "$REPO_ROOT/scripts/parse_draft.py" "$TEMP_DIR/parse_draft.pyc" >> "$LOG_FILE" <<'PY'
import py_compile
import sys

py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)
print("syntax ok")
PY

log "== 生成样例稿件 =="
python3 - "$TEMP_DIR" >> "$LOG_FILE" <<'PY'
from pathlib import Path
import sys
import zipfile

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
(root / "sample.md").write_text("# 标题\n\n小红书达人稿测试", encoding="utf-8")
(root / "sample.txt").write_text("纯文本达人稿测试", encoding="utf-8")

with zipfile.ZipFile(root / "sample.docx", "w") as z:
    z.writestr("word/document.xml", """<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>正文段落测试</w:t></w:r></w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>镜头</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>口播</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>第一神器必须推</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>""")

with zipfile.ZipFile(root / "sample.xlsx", "w") as z:
    z.writestr("xl/workbook.xml", """<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="脚本" sheetId="1" r:id="rId1"/></sheets>
</workbook>""")
    z.writestr("xl/_rels/workbook.xml.rels", """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>""")
    z.writestr("xl/worksheets/sheet1.xml", """<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row><c r="A1" t="inlineStr"><is><t>镜头</t></is></c><c r="C1" t="inlineStr"><is><t>口播</t></is></c></row>
    <row><c r="A2" t="inlineStr"><is><t>1</t></is></c><c r="C2" t="inlineStr"><is><t>第一神器必须推</t></is></c></row>
  </sheetData>
</worksheet>""")

print("samples ok")
PY

log "== 运行解析器断言测试 =="
md_output="$(python3 "$REPO_ROOT/scripts/parse_draft.py" "$TEMP_DIR/sample.md")"
assert_contains "$md_output" "小红书达人稿测试" "md 解析"

txt_output="$(python3 "$REPO_ROOT/scripts/parse_draft.py" "$TEMP_DIR/sample.txt")"
assert_contains "$txt_output" "纯文本达人稿测试" "txt 解析"

docx_output="$(python3 "$REPO_ROOT/scripts/parse_draft.py" "$TEMP_DIR/sample.docx")"
assert_contains "$docx_output" "正文段落测试" "docx 段落解析"
assert_contains "$docx_output" "第一神器必须推" "docx 表格解析"

xlsx_output="$(python3 "$REPO_ROOT/scripts/parse_draft.py" "$TEMP_DIR/sample.xlsx")"
assert_contains "$xlsx_output" "第一神器必须推" "xlsx 解析"
assert_contains "$xlsx_output" "| 镜头 |  | 口播 |" "xlsx 空列保留"

log "验证通过。日志: $LOG_FILE"
