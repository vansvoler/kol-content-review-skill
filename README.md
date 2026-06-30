# KOL Content Review Skill

用于 KOL / 达人稿件审核与批注的 Claude Code / Codex-compatible skill。适合对照 brief 审核小红书笔记、短视频脚本、图文稿件和广告稿件，输出「批注版稿件 + 结构化审核报告」。

## 适用场景

- 小红书笔记审核
- KOL / 达人交付稿审稿
- 短视频脚本合规与转化检查
- 广告稿件批注
- 对照 brief 检查卖点覆盖、平台合规、违禁词风险

## 安装

推荐先验证，再安装：

```bash
git clone https://github.com/vansvoler/kol-content-review-skill.git
cd kol-content-review-skill
bash scripts/validate.sh
bash scripts/install.sh --target claude
```

可选安装目标：

```bash
# Claude Code
bash scripts/install.sh --target claude

# Codex / Agents skill 目录
bash scripts/install.sh --target agents

# 自定义目录
bash scripts/install.sh --target-dir "$HOME/.claude/skills"
```

安装脚本会把当前仓库复制到目标目录下的 `kol-content-review/`。如果目标目录已存在，会先重命名为带时间戳的 `.backup-*` 目录。

## 使用方式

在 Claude Code 或支持 skills 的 agent 中直接描述任务：

```text
帮我审核这篇小红书达人稿。Brief 是：...
稿件在：/path/to/draft.docx
```

必须同时提供：

- Brief：文字描述、markdown 文件或产品素材说明
- 稿件：`.docx` / `.xlsx` / `.pdf` / `.md` / `.txt`

Brief 缺失时，skill 会先要求补充 brief，不会凭空审核。

## 输出

skill 会产出两类结果：

- 批注版稿件：在原稿 markdown 中紧邻问题段落插入 `[必改] / [建议] / [参考]` 批注
- 审核报告：基于 `assets/review-report-template.md` 输出总评、红线、建议、Brief 覆盖度、平台合规和给达人的沟通要点

## 文件结构

```text
.
├── SKILL.md
├── assets/
│   └── review-report-template.md
├── references/
│   ├── annotation-guide.md
│   ├── compliance-words.md
│   ├── platform-rules.md
│   └── review-standards.md
└── scripts/
    ├── install.sh
    ├── parse_draft.py
    └── validate.sh
```

## 验证

```bash
bash scripts/validate.sh
```

验证内容：

- 必需文件存在
- `SKILL.md` frontmatter 可解析
- Python 解析脚本可编译
- `.md` / `.txt` / `.docx` / `.xlsx` 样例稿件可转换为 markdown

验证日志会写入 `logs/validate.log`。

## 运行要求

- macOS / Linux shell
- Python 3.9+
- 无额外 pip 依赖

PDF 稿件不通过 `scripts/parse_draft.py` 解析，应由 Claude Code / agent 原生读取 PDF。

