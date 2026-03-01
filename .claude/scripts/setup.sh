#!/bin/bash
# .claude/scripts/setup.sh
# 项目初始化脚本：安装 git hooks、创建必要目录
# 用法：bash .claude/scripts/setup.sh

set -e

echo "🔧 项目初始化..."

# 1. 安装 pre-commit hook
if git rev-parse --git-dir &>/dev/null; then
  GIT_HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
  if [ -f "hooks/pre-commit" ]; then
    mkdir -p "$GIT_HOOKS_DIR"
    cp hooks/pre-commit "$GIT_HOOKS_DIR/pre-commit"
    chmod +x "$GIT_HOOKS_DIR/pre-commit"
    echo "✅ pre-commit hook 已安装"
  else
    echo "❌ hooks/pre-commit 文件不存在，请检查仓库完整性"
    exit 1
  fi
else
  echo "⚠️  不在 git 仓库中，跳过 hook 安装"
fi

# 2. 创建必要目录
mkdir -p docs/contracts
mkdir -p .metrics
echo "✅ 目录结构已创建"

# 3. 检查依赖
echo ""
echo "📋 环境检查："

if command -v node &> /dev/null; then
  echo "  ✅ Node.js $(node -v)"
else
  echo "  ⚠️  未检测到 Node.js"
fi

if command -v python3 &> /dev/null; then
  echo "  ✅ Python $(python3 --version 2>&1 | cut -d' ' -f2)"
else
  echo "  ⚠️  未检测到 Python3（report.sh 需要）"
fi

if command -v gh &> /dev/null; then
  echo "  ✅ GitHub CLI $(gh --version 2>&1 | head -1 | cut -d' ' -f3)"
else
  echo "  ⚠️  未检测到 gh CLI（download-metrics.sh 需要）"
fi

# 4. 检测项目语言并输出配置指引
echo ""
echo "🔍 项目语言检测："

HAS_NODE=false
HAS_PYTHON=false
[ -f "package.json" ] && HAS_NODE=true
[ -f "requirements.txt" ] || [ -f "pyproject.toml" ] && HAS_PYTHON=true

if $HAS_NODE && $HAS_PYTHON; then
  echo "  ⚠️  同时检测到 package.json 和 requirements.txt/pyproject.toml"
  echo "  请手动确认项目主语言，并相应编辑 test.yml 和 hooks/pre-commit"
elif $HAS_NODE; then
  echo "  检测到 Node.js 项目（package.json 存在）"
  echo "  ✅ test.yml 和 hooks/pre-commit 默认为 Node.js 配置"
  echo "  📝 确认 hooks/pre-commit 使用 'npm test -- --run'（而非 pytest）"
elif $HAS_PYTHON; then
  echo "  检测到 Python 项目（requirements.txt / pyproject.toml 存在）"
  echo "  ⚙️  请在 .github/workflows/test.yml 中："
  echo "     - 注释掉 Node.js 段（setup-node + npm ci + npm run lint/test/build）"
  echo "     - 取消注释 Python 段（setup-python + pip install + ruff + pytest）"
  echo "  ⚙️  请在 hooks/pre-commit 中："
  echo "     - 注释掉 'npm test -- --run' 行"
  echo "     - 取消注释 'pytest -q' 行"
else
  echo "  ⚠️  未检测到 package.json 或 requirements.txt/pyproject.toml"
  echo "  这是新项目？请先创建项目配置文件，再运行此脚本"
  echo "  ⚙️  无论如何，记得手动编辑 test.yml 和 hooks/pre-commit 中的 ⚙️ 标记项"
fi

echo ""
echo "🎉 初始化完成！"
echo ""
echo "🔑 在 GitHub Repo Settings → Secrets and Variables 中配置："
echo ""
echo "  Secrets（加密存储，Actions 中通过 secrets.XXX 访问）："
echo "  - ANTHROPIC_API_KEY  Anthropic API Key（qa-review.yml 自动 QA 审查用）"
echo "  - DINGTALK_WEBHOOK   钉钉机器人 Webhook URL（可选，CI 失败通知用）"
echo ""
echo "  Variables（明文存储，Actions 中通过 vars.XXX 访问）："
echo "  - QA_MODEL           QA 审查模型 ID（可选，默认 claude-sonnet-4-5-20250514）"
echo ""
echo "  注：GITHUB_TOKEN 由 GitHub 自动提供，无需手动配置"
