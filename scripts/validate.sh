#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 发布前验证：结构、frontmatter、解析器 smoke test
# ============================================================

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
python3 -m py_compile "$REPO_ROOT/scripts/parse_draft.py" >> "$LOG_FILE"

log "== 生成样例稿件 =="
python3 - "$TEMP_DIR" >> "$LOG_FILE" <<'PY'
from pathlib import Path
import zipfile
import sys

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
(root / "sample.md").write_text("# 标题\n\n小红书达人稿测试", encoding="utf-8")
(root / "sample.txt").write_text("纯文本达人稿测试", encoding="utf-8")

with zipfile.ZipFile(root / "sample.docx", "w") as z:
    z.writestr("[Content_Types].xml", "")
    z.writestr("word/document.xml", """<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>docx 达人稿测试</w:t></w:r></w:p>
  </w:body>
</w:document>""")

with zipfile.ZipFile(root / "sample.xlsx", "w") as z:
    z.writestr("xl/workbook.xml", """<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>""")
    z.writestr("xl/_rels/workbook.xml.rels", """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>""")
    z.writestr("xl/worksheets/sheet1.xml", """<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row><c t="inlineStr"><is><t>字段</t></is></c><c t="inlineStr"><is><t>内容</t></is></c></row>
    <row><c t="inlineStr"><is><t>平台</t></is></c><c t="inlineStr"><is><t>小红书</t></is></c></row>
  </sheetData>
</worksheet>""")

print("samples ok")
PY

log "== 运行解析器 smoke test =="
for sample in sample.md sample.txt sample.docx sample.xlsx; do
  output="$(python3 "$REPO_ROOT/scripts/parse_draft.py" "$TEMP_DIR/$sample")"
  if [[ -z "$output" ]]; then
    log "解析输出为空: $sample"
    exit 1
  fi
  log "解析通过: $sample"
done

log "验证通过。日志: $LOG_FILE"

