#!/bin/bash
# .claude/scripts/setup.sh
# 项目初始化脚本：安装 git hooks、创建必要目录
# 用法：bash .claude/scripts/setup.sh

set -e

echo "🔧 项目初始化..."

# 1. 安装 pre-commit hook
if [ -d ".git" ]; then
  if [ -f "hooks/pre-commit" ]; then
    cp hooks/pre-commit .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
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

echo ""
echo "🎉 初始化完成！"
echo ""
echo "⚙️ 接下来请根据项目类型修改以下文件中的 ⚙️ 标记项："
echo "  - .github/workflows/test.yml（选择 Node.js 或 Python 配置）"
echo "  - hooks/pre-commit（选择测试命令）"
echo ""
echo "🔑 在 GitHub Repo Settings → Secrets 中配置："
echo "  - DINGTALK_WEBHOOK（钉钉机器人 Webhook URL）"
