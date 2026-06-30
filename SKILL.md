---
name: kol-content-review
description: Use when reviewing KOL or influencer deliverables against a brief, especially 小红书笔记审核, 达人稿件, 审稿, 短视频脚本审核, 广告稿件审核, or 稿件批注 for docx, xlsx, pdf, md, or txt drafts.
---

# KOL 稿件审核

## 概述

对照 brief 审核达人交付稿件，输出「批注版稿件 + 结构化审核报告」。

**核心理念**：分层弹性标准 —— 只对真正危险的内容一刀切（合规/事实），其余保留达人创作空间。

---

## 工作流

严格按以下四步执行：

### Step 1 · 收集输入

确认用户已提供：
1. **Brief**：文字描述 / markdown 文件 / 产品素材
2. **稿件**：docx / xlsx / pdf / md / txt 任一格式

若 brief 缺失，**必须先询问用户**，不得凭空审核。

### Step 2 · 解析稿件

按文件格式分派：

| 扩展名 | 处理方式 |
|---|---|
| `.docx` / `.xlsx` | 调用 `scripts/parse_draft.py <file>` 转 markdown |
| `.pdf` | **直接用 Read tool 原生读取**（Claude 原生支持 PDF） |
| `.md` / `.txt` | 用 Read tool 读取 |

解析脚本用法：
```bash
python3 scripts/parse_draft.py <稿件文件路径>
```

输出为 stdout 的 markdown。

### Step 3 · 识别内容类型 + 加载规则

识别维度：

1. **平台**（小红书 / 抖音 / 视频号 / B 站 / 快手）
   - 不明确时主动询问用户
   - 按平台加载 `references/platform-rules.md` 对应段落

2. **内容形式**（种草笔记 / 图文 / 短视频脚本 / 直播脚本）

3. **产品类目**（美妆 / 食品 / 母婴 / 医美 / 数码 / 教育等）
   - 影响 `references/compliance-words.md` 行业特殊禁忌段

### Step 4 · 三层标准审核 + 双输出

**必读参考**：

1. `references/review-standards.md` —— 三层弹性标准（Tier 1/2/3）+ 四条铁律
2. `references/compliance-words.md` —— 违禁词黑/灰/误区三级词库
3. `references/platform-rules.md` —— 对应平台段落（Step 3 已确定）
4. `references/annotation-guide.md` —— 批注格式 + 尊重达人人设边界

**输出 A：批注版稿件**

- 在原稿 markdown 基础上，**紧邻问题段落后方**插入批注块
- 使用 `[必改] / [建议] / [参考]` 三级标签（详见 annotation-guide）
- 单篇批注密度控制：Tier 1 ≤ 3 条，Tier 2 ≤ 5 条，Tier 3 ≤ 3 条
- 超过阈值应建议"打回重写"而非逐条批注

**输出 B：审核报告**

- 基于 `assets/review-report-template.md` 填充
- 必含章节：总评 / 红线 / 建议 / 参考 / Brief 覆盖度 / 平台合规 / 下一步
- "下一步动作"段落用**对达人的口语化沟通**，避免 checklist 式

---

## 三层标准速查

| Tier | 含义 | 措辞 | 弹性 |
|---|---|---|---|
| Tier 1 | 必改（合规/事实/brief 核心缺失） | "必须" | 零 |
| Tier 2 | 建议改（偏离 brief/影响转化） | "建议，因为…" | 中 |
| Tier 3 | 参考（文笔/标签/节奏优化） | "可参考" | 高 |

**四条铁律**（批注必须遵守）：

1. 每条必说 **why**（合规 / brief / 效果三选一）
2. 尊重达人标志性表达（冲突时降级 Tier 或不批）
3. 提供**替代选项** ≥ 2 个，拒绝命令式单一方案
4. 措辞分级（Tier 1 "必须" / Tier 2 "建议" / Tier 3 "可参考"）

详见 `references/review-standards.md`。

---

## 决策树：模糊场景

```
发现问题点
    │
    ├─ 触犯广告法/平台硬规则？─── 是 ──→ Tier 1（即使与人设冲突也必批）
    │
    ├─ 事实错误（产品/价格/成分）？── 是 ──→ Tier 1
    │
    ├─ Brief 必传卖点"完全没提"？── 是 ──→ Tier 1
    │   （注意：不是"表达不同"，是一个字没提）
    │
    ├─ 偏离 brief 意图但尚可理解？── 是 ──→ Tier 2
    │
    ├─ 影响转化（钩子/CTA/互动）？── 是 ──→ Tier 2
    │
    ├─ 纯文笔/节奏/标签优化？──── 是 ──→ Tier 3
    │
    └─ 是否破坏达人标志性表达？── 是 ──→ 降级 Tier 或不批注
```

---

## 关键原则

### 批注密度控制

批注太多会传递错误信号（不信任达人能力 / 达人摆烂）。每类 Tier 设置上限：

- Tier 1 超 3 条 → 建议打回重写
- 通过审核的稿件可以**零批注**，直接在报告写"内容符合要求"
- Tier 3 类似建议可以合并成一条（如多个标签建议并为一条）

### 尊重达人风格

以下不轻易修改：口头禅、开场习惯、用词偏好、叙事风格、情绪风格。遇冲突优先降级处理。

### Brief 缺失 ≠ 表达不同

- Brief 要求"突出神经酰胺"，稿件写"屏障修护因子" → **Tier 2**（谈同一件事但未命中关键词）
- Brief 要求"突出神经酰胺"，稿件完全不提成分 → **Tier 1**（必传信息缺失）

### 用户对话语气

完成审核后，主动询问用户是否需要：
- 调整批注严格度
- 针对特定段落深入分析
- 输出给达人的沟通话术（口语化版本）

---

## 资源地图

- `scripts/parse_draft.py` — docx/xlsx → markdown 统一解析器
- `references/review-standards.md` — 三层标准 + 四条铁律 + 边界场景
- `references/platform-rules.md` — 小红书/抖音/视频号/B 站/快手分段
- `references/compliance-words.md` — 违禁词黑/灰/误区三级词库
- `references/annotation-guide.md` — 批注格式 + 好坏对照 + 人设边界
- `assets/review-report-template.md` — 审核报告填充模板
