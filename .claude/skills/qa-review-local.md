# 本地 QA 共识审查（PAL Consensus）

## 何时使用

在创建 PR **之前**或 PR 创建**之后、合并之前**，运行本地 QA 共识审查。

这是 QA 审查的**首选方式**，优先于 CI 中的 Anthropic API 单模型审查。

## 流程

### 1. 准备审查材料

```bash
# 获取 diff（相对于 main）
git diff main...HEAD

# 确认契约文件路径
ls docs/contracts/
```

### 2. 调用 PAL consensus

使用 `mcp__pal__consensus` 工具，配置：

- **模型**: `openai/gpt-5.1-codex`（neutral）+ `google/gemini-2.5-pro`（neutral）
- **relevant_files**: 变更的源码文件 + 契约文件
- **step**: 审查 prompt（见下方模板）

#### 审查 Prompt 模板

```
审查以下 PR 的代码变更，对照行为契约检查合规性。

行为契约（{契约文件路径}）：
{契约核心内容：前置/后置/异常后置/不变式/边界}

代码变更摘要：
{变更说明或关键 diff}

请按以下格式输出审查结果：
**逻辑 / 契约符合度** · （列出问题，无问题则写"无"）
**安全 / 边界** · （列出问题，无问题则写"无"）
**其他建议** · （列出建议，无建议则写"无"）
severity: 高 / 中 / 低
建议：合并 ✅ / 修复后合并 ⚠️ / 必须修复 ❌
```

### 3. 发布到 PR 评论

使用 `gh api` 将综合结果发布到 PR：

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  -X POST -f body="<!-- qa-review-consensus -->
## 🔍 QA 共识审查（PAL Consensus: codex + gemini-2.5-pro）

### openai/gpt-5.1-codex
{codex 的审查结果}

---

### google/gemini-2.5-pro
{gemini 的审查结果}

---

### 综合结论
{综合 severity 和建议}

---
*由 PAL MCP consensus 本地触发（codex + gemini-2.5-pro）*"
```

**关键**：评论必须包含 `<!-- qa-review-consensus -->` 标记，CI 中的 qa-review.yml 会检测此标记，检测到则跳过 CI 回退审查。

### 4. 人类决策

| QA 指出的问题类型 | 动作 |
|---|---|
| 真实缺陷（漏处理边界、潜在崩溃） | 打回重改 |
| 值得改但不紧急 | 创建 Issue，当前 PR 可过 |
| 过度挑剔 / 不适用 | 忽略，直接合并 |

## 与 CI 审查的关系

| 场景 | 行为 |
|---|---|
| 本地已发布共识审查 | CI qa-review.yml 检测到标记，跳过 |
| 本地未审查 + ANTHROPIC_API_KEY 已配置 | CI 自动用 Anthropic API 单模型审查（回退） |
| 本地未审查 + API key 未配置 | CI 发布提示评论，建议使用本地共识审查 |
