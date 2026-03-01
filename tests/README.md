# 框架测试

## 第一层：本地脚本测试（bats）

使用 [bats-core](https://github.com/bats-core/bats-core) 测试所有 shell 脚本。每个测试用例在独立临时 git 仓库中运行，互不干扰。

### 安装

```bash
brew install bats-core   # macOS
```

### 运行

```bash
# 全部运行（67 个用例）
bats tests/

# 单文件运行
bats tests/setup.bats
bats tests/save-contract.bats
bats tests/report.bats
bats tests/pre-commit.bats
```

### 测试清单

| 文件 | 用例数 | 被测脚本 | 覆盖范围 |
|------|-------|---------|---------|
| `setup.bats` | 16 | `.claude/scripts/setup.sh` | hook 安装/权限/幂等、目录创建、语言检测（Node/Python/双语/无配置）、非 git 仓库、输出格式 |
| `save-contract.bats` | 25 | `.claude/scripts/save-contract.sh` | 参数缺失/中文/空格/注入/斜杠/下划线/合法值、文件生成（命名/字段/标题）、模板复制 vs fallback、重复文件处理、目录自动创建 |
| `report.bats` | 17 | `.claude/scripts/report.sh` | 默认/自定义天数、注入防护、文件缺失、统计逻辑（全通过/部分/全失败）、commit 去重、时间过滤、操作人分组、报告格式、异常数据容错 |
| `pre-commit.bats` | 9 | `hooks/pre-commit` | hook 安装识别、测试通过放行、测试失败阻断、失败后数据不丢失、npm 缺失阻断、输出消息、连续提交修复 |

### 隔离机制

`helpers.bash` 提供共享辅助函数：

- `setup_isolated_repo` — 创建临时目录、`git init`、复制框架文件、初始提交
- `teardown_isolated_repo` — 清理临时目录

每个 `@test` 通过 bats 的 `setup/teardown` 钩子自动调用。

---

## 第二层：端到端验证（独立 GitHub 仓库）

仓库：[codepact-sandbox](https://github.com/a3963969/codepact-sandbox)

```
git@github.com:a3963969/codepact-sandbox.git
```

一个最小 Python 项目（pytest + ruff + mypy），验证完整闭环：

### 已验证的流程

| 步骤 | 验证项 | 结果 |
|------|-------|------|
| 1 | `setup.sh` 检测 Python 项目 + 安装 hook | ✅ |
| 2 | `save-contract.sh` 创建契约文件 | ✅ |
| 3 | pre-commit hook 运行 pytest 阻断/放行 | ✅ |
| 4 | CI `test.yml` (ruff + mypy + pytest + coverage ≥ 80%) | ✅ |
| 5 | `link-contract.yml` 自动评论契约链接 | ✅ |
| 6 | PAL consensus 本地共识审查（codex + gemini-pro） | ✅ |
| 7 | `qa-review.yml` 检测共识标记跳过 CI 回退 | ✅ |
| 8 | PR 合并 → `update-contract-status.yml` 更新契约状态 | ✅ |

### 复现 E2E 测试

```bash
# 1. 克隆 sandbox
git clone git@github.com:a3963969/codepact-sandbox.git
cd codepact-sandbox

# 2. 初始化
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
bash .claude/scripts/setup.sh

# 3. 创建契约
bash .claude/scripts/save-contract.sh <模块名> <功能名>

# 4. TDD：写测试（红）→ 写实现（绿）
pytest -q  # 先红后绿

# 5. 提交（hook 自动跑 pytest）
git checkout -b feature/<功能名>
git add -A && git commit -m "feat: ..."

# 6. 推送 + 创建 PR
git push -u origin feature/<功能名>
gh pr create --title "..." --body "## 关联契约\n- 契约文件：\`docs/contracts/...\`"

# 7. 观察 CI + QA 审查 + 契约关联
gh run list
gh api repos/<owner>/<repo>/issues/<pr>/comments --jq '.[].body'
```
