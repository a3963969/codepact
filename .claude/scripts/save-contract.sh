#!/bin/bash
# .claude/scripts/save-contract.sh
# 用法：bash .claude/scripts/save-contract.sh <模块名> <功能名>
# 示例：bash .claude/scripts/save-contract.sh auth register-login
# 命名规范：模块名和功能名只允许字母、数字和连字符（a-z, 0-9, -）

set -e

MODULE=$1
FEATURE=$2

if [ -z "$MODULE" ] || [ -z "$FEATURE" ]; then
  echo "❌ 用法：bash .claude/scripts/save-contract.sh <模块名> <功能名>"
  exit 1
fi

# 校验参数：只允许字母、数字和连字符
if ! echo "$MODULE" | grep -qE '^[a-zA-Z0-9-]+$'; then
  echo "❌ 模块名只允许字母、数字和连字符，收到：$MODULE"
  exit 1
fi
if ! echo "$FEATURE" | grep -qE '^[a-zA-Z0-9-]+$'; then
  echo "❌ 功能名只允许字母、数字和连字符，收到：$FEATURE"
  exit 1
fi

DATE=$(date +%Y-%m-%d)
FILENAME="docs/contracts/${DATE}_${MODULE}_${FEATURE}.md"

if [ -f "$FILENAME" ]; then
  echo "⚠️  契约文件已存在：$FILENAME"
  echo ""
  echo "如果这是同一功能的更新版本，请直接编辑现有文件并更新「变更历史」表格。"
  echo "如果这是同一天的不同功能（同名），请为功能名添加后缀以区分，例如："
  echo "  bash .claude/scripts/save-contract.sh ${MODULE} ${FEATURE}-v2"
  echo ""
  echo "如果你确认需要重新创建（将清空现有内容），运行："
  echo "  rm \"$FILENAME\" && bash .claude/scripts/save-contract.sh ${MODULE} ${FEATURE}"
  exit 1
fi

mkdir -p docs/contracts

# 从模板复制
if [ -f "docs/contracts/_template.md" ]; then
  cp docs/contracts/_template.md "$FILENAME"
  # 使用 | 作为 sed 分隔符，避免特殊字符问题
  # 兼容 macOS 和 Linux 的 sed -i
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^module: \"\"|module: \"${MODULE}\"|" "$FILENAME"
    sed -i '' "s|^created: \"\"|created: \"${DATE}\"|" "$FILENAME"
    sed -i '' "s|# 行为契约：\[功能名称\]|# 行为契约：${FEATURE}|" "$FILENAME"
  else
    sed -i "s|^module: \"\"|module: \"${MODULE}\"|" "$FILENAME"
    sed -i "s|^created: \"\"|created: \"${DATE}\"|" "$FILENAME"
    sed -i "s|# 行为契约：\[功能名称\]|# 行为契约：${FEATURE}|" "$FILENAME"
  fi
else
  # Fallback: 无模板时直接生成 YAML front-matter 格式
  {
    echo "---"
    echo "module: \"${MODULE}\""
    echo "created: \"${DATE}\""
    echo "status: 草稿"
    echo "linked_pr: \"\""
    echo "---"
    echo ""
    echo "# 行为契约：${FEATURE}"
    echo ""
    echo "## 前置条件"
    echo ""
    echo "-"
    echo ""
    echo "## 后置条件"
    echo ""
    echo "-"
    echo ""
    echo "## 异常后置条件"
    echo ""
    echo "-"
    echo ""
    echo "## 不变式"
    echo ""
    echo "-"
    echo ""
    echo "## 边界目录"
    echo ""
    echo "| 场景 | 处理方式 | 状态 |"
    echo "|------|---------|------|"
    echo "|      |         | ✅ 已确认 / ⚠️ 待确认 |"
  } > "$FILENAME"
fi

echo "✅ 契约文件已创建：$FILENAME"
echo "📝 请填写契约内容，确认后状态改为「已确认」"
