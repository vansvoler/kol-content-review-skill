# KOL Content Review Skill

KOL / 达人稿件审核与批注 skill，用于帮助品牌、内容和媒介团队对照 brief 审核达人交付稿，统一识别合规风险、卖点覆盖、平台规则和批注意见。

这个 skill 适合团队内部使用：让不同同事按同一套标准审稿，减少漏看、误判和输出格式不一致。

## 它能做什么

- **解析稿件**：支持 `.docx`、`.xlsx`、`.md`、`.txt`；PDF 由当前 agent 环境读取或先转成文本。
- **对照 brief 审核**：检查必传卖点、产品事实、价格/规格/成分、品牌口径是否一致。
- **识别合规风险**：按广告法、平台规则和行业敏感词判断红线问题。
- **分层输出意见**：用 `[必改] / [建议] / [参考]` 区分修改强度，避免把所有问题都写成强制修改。
- **保护达人风格**：对口头禅、人设表达、叙事方式保持克制，不把达人稿改成品牌通稿。
- **生成双输出**：产出「批注版稿件」和「结构化审核报告」。

## 适用场景

- 小红书图文笔记审稿
- 短视频脚本、分镜、口播审核
- 广告稿件合规检查
- 对照 brief 检查卖点覆盖
- 给达人整理修改意见
- 团队新人按统一标准完成初审

不适合的场景：

- 没有 brief 的自由创作评价
- 需要法律最终意见的高风险广告审查
- 需要自动发布、自动联系达人或自动修改原文件的工作流

## 让 agent 自动安装

把下面这段发给 Codex、Claude Code 或其他支持 skills 的 agent：

```text
请帮我安装这个 skill：
https://github.com/vansvoler/kol-content-review-skill

要求：
1. 先 clone 仓库，不要只复制单个 SKILL.md。
2. 运行 bash scripts/validate.sh，确认验证通过。
3. 如果我是 Codex，安装到 ~/.codex/skills；如果我是 Claude Code，安装到 ~/.claude/skills。
4. 安装后告诉我目标路径，并提醒我重启 agent 以加载新 skill。
```

如果 agent 已经知道当前环境，也可以用更短的说法：

```text
安装 vansvoler/kol-content-review-skill 这个 skill。请 clone 仓库，先验证，再用 scripts/install.sh 安装到当前 agent 的 skills 目录。
```

## 手动安装

```bash
git clone https://github.com/vansvoler/kol-content-review-skill.git
cd kol-content-review-skill
bash scripts/validate.sh
```

按环境选择安装目标：

```bash
# Codex
bash scripts/install.sh --target codex

# Claude Code
bash scripts/install.sh --target claude

# Agents 目录
bash scripts/install.sh --target agents

# 自定义 skills 根目录
bash scripts/install.sh --target-dir "$HOME/.codex/skills"
```

安装脚本会把 skill 安装到目标目录下的 `kol-content-review/`。如果目标目录已存在，会先备份为 `.backup-YYYYMMDDHHMMSS`。

安装完成后，重启 agent，让新 skill 生效。

## 使用方式

在 agent 中直接描述审稿任务，并同时提供 brief 和稿件路径：

```text
帮我审核这篇小红书达人稿。

Brief：
- 品牌：XX
- 产品：XX 精华
- 必传卖点：神经酰胺、屏障修护、敏感肌可用
- 禁忌：不要写治疗、消炎、立竿见影

稿件路径：
/path/to/draft.docx
```

也可以直接给文件：

```text
请对照 /path/to/brief.md 审核 /path/to/script.xlsx。
平台是抖音，内容形式是短视频脚本。
```

如果 brief 缺失，skill 会先要求补充 brief，不会凭空审核。

## 输出内容

### 1. 批注版稿件

在原稿 markdown 中紧邻问题段落插入批注：

```markdown
> [必改] 第 2 段「效果最佳」
  问题：极限词，存在平台限流和广告法风险
  原因：该表达形成绝对化宣传
  替代：「体验不错」/「口碑较好」
```

### 2. 审核报告

基于 `assets/review-report-template.md` 输出：

- 总评
- 红线问题
- 建议修改清单
- 参考优化
- Brief 卖点覆盖度
- 平台合规检查
- 给达人的沟通要点

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
- `.docx` 表格内容不会丢失
- `.xlsx` 空列不会导致表格错位

验证日志会写入 `logs/validate.log`。

## 运行要求

- macOS / Linux shell
- Python 3.9+
- 无额外 pip 依赖

PDF 稿件不通过 `scripts/parse_draft.py` 解析，应由当前 agent 环境直接读取，或先转成 markdown/text 后再审核。
