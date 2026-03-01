#!/usr/bin/env bats
# tests/save-contract.bats — 测试 .claude/scripts/save-contract.sh

load helpers

setup() {
  setup_isolated_repo
}

teardown() {
  teardown_isolated_repo
}

# ============================================================
# 参数校验
# ============================================================

@test "缺少全部参数时退出码为 1" {
  run bash .claude/scripts/save-contract.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"用法"* ]]
}

@test "缺少功能名参数时退出码为 1" {
  run bash .claude/scripts/save-contract.sh auth
  [ "$status" -eq 1 ]
  [[ "$output" == *"用法"* ]]
}

@test "模块名含中文时拒绝" {
  run bash .claude/scripts/save-contract.sh 认证 login
  [ "$status" -eq 1 ]
  [[ "$output" == *"只允许字母、数字和连字符"* ]]
}

@test "功能名含中文时拒绝" {
  run bash .claude/scripts/save-contract.sh auth 登录
  [ "$status" -eq 1 ]
  [[ "$output" == *"只允许字母、数字和连字符"* ]]
}

@test "模块名含空格时拒绝" {
  run bash .claude/scripts/save-contract.sh "my module" feature
  [ "$status" -eq 1 ]
  [[ "$output" == *"只允许字母、数字和连字符"* ]]
}

@test "模块名含特殊字符时拒绝（防注入）" {
  run bash .claude/scripts/save-contract.sh 'auth;rm -rf' login
  [ "$status" -eq 1 ]
  [[ "$output" == *"只允许字母、数字和连字符"* ]]
}

@test "功能名含斜杠时拒绝" {
  run bash .claude/scripts/save-contract.sh auth "../../etc/passwd"
  [ "$status" -eq 1 ]
  [[ "$output" == *"只允许字母、数字和连字符"* ]]
}

@test "模块名含下划线时拒绝" {
  run bash .claude/scripts/save-contract.sh auth_module login
  [ "$status" -eq 1 ]
  [[ "$output" == *"只允许字母、数字和连字符"* ]]
}

@test "合法参数（字母+数字+连字符）通过校验" {
  run bash .claude/scripts/save-contract.sh auth register-login
  [ "$status" -eq 0 ]
}

@test "纯数字参数通过校验" {
  run bash .claude/scripts/save-contract.sh m1 f2
  [ "$status" -eq 0 ]
}

@test "大写字母通过校验" {
  run bash .claude/scripts/save-contract.sh Auth Register-Login
  [ "$status" -eq 0 ]
}

# ============================================================
# 文件生成
# ============================================================

@test "生成的文件名格式为 YYYY-MM-DD_模块_功能.md" {
  bash .claude/scripts/save-contract.sh auth login
  TODAY=$(date +%Y-%m-%d)
  [ -f "docs/contracts/${TODAY}_auth_login.md" ]
}

@test "生成的文件包含 module 字段" {
  bash .claude/scripts/save-contract.sh auth login
  TODAY=$(date +%Y-%m-%d)
  grep -q 'module: "auth"' "docs/contracts/${TODAY}_auth_login.md"
}

@test "生成的文件包含 created 日期" {
  bash .claude/scripts/save-contract.sh auth login
  TODAY=$(date +%Y-%m-%d)
  grep -q "created: \"${TODAY}\"" "docs/contracts/${TODAY}_auth_login.md"
}

@test "生成的文件包含 status 草稿" {
  bash .claude/scripts/save-contract.sh auth login
  TODAY=$(date +%Y-%m-%d)
  grep -q "status: 草稿" "docs/contracts/${TODAY}_auth_login.md"
}

@test "生成的文件标题包含功能名" {
  bash .claude/scripts/save-contract.sh auth register-login
  TODAY=$(date +%Y-%m-%d)
  grep -q "行为契约：register-login" "docs/contracts/${TODAY}_auth_register-login.md"
}

@test "输出成功提示消息" {
  run bash .claude/scripts/save-contract.sh auth login
  [ "$status" -eq 0 ]
  [[ "$output" == *"契约文件已创建"* ]]
  [[ "$output" == *"请填写契约内容"* ]]
}

# ============================================================
# 模板复制
# ============================================================

@test "有模板时从模板复制并填充" {
  bash .claude/scripts/save-contract.sh content feed
  TODAY=$(date +%Y-%m-%d)
  FILE="docs/contracts/${TODAY}_content_feed.md"

  # 验证五要素结构来自模板
  grep -q "## 前置条件" "$FILE"
  grep -q "## 后置条件" "$FILE"
  grep -q "## 异常后置条件" "$FILE"
  grep -q "## 不变式" "$FILE"
  grep -q "## 边界目录" "$FILE"
  # 模板独有的确认记录和变更历史
  grep -q "## 确认记录" "$FILE"
  grep -q "## 变更历史" "$FILE"
}

@test "无模板时 fallback 生成包含五要素" {
  rm docs/contracts/_template.md

  bash .claude/scripts/save-contract.sh content feed
  TODAY=$(date +%Y-%m-%d)
  FILE="docs/contracts/${TODAY}_content_feed.md"

  grep -q "## 前置条件" "$FILE"
  grep -q "## 后置条件" "$FILE"
  grep -q "## 异常后置条件" "$FILE"
  grep -q "## 不变式" "$FILE"
  grep -q "## 边界目录" "$FILE"
  # front-matter 字段也应存在
  grep -q 'module: "content"' "$FILE"
  grep -q "status: 草稿" "$FILE"
}

@test "无模板时 fallback 生成包含边界表格" {
  rm docs/contracts/_template.md

  bash .claude/scripts/save-contract.sh content feed
  TODAY=$(date +%Y-%m-%d)
  FILE="docs/contracts/${TODAY}_content_feed.md"

  grep -q "| 场景 | 处理方式 | 状态 |" "$FILE"
}

# ============================================================
# 重复文件处理
# ============================================================

@test "文件已存在时退出码为 1" {
  bash .claude/scripts/save-contract.sh auth login
  run bash .claude/scripts/save-contract.sh auth login
  [ "$status" -eq 1 ]
  [[ "$output" == *"契约文件已存在"* ]]
}

@test "文件已存在时提示 v2 后缀方案" {
  bash .claude/scripts/save-contract.sh auth login
  run bash .claude/scripts/save-contract.sh auth login
  [[ "$output" == *"-v2"* ]]
}

@test "文件已存在时提示 rm 重新创建方案" {
  bash .claude/scripts/save-contract.sh auth login
  run bash .claude/scripts/save-contract.sh auth login
  [[ "$output" == *"rm"* ]]
}

@test "不同功能名可以共存" {
  bash .claude/scripts/save-contract.sh auth login
  run bash .claude/scripts/save-contract.sh auth register
  [ "$status" -eq 0 ]
  TODAY=$(date +%Y-%m-%d)
  [ -f "docs/contracts/${TODAY}_auth_login.md" ]
  [ -f "docs/contracts/${TODAY}_auth_register.md" ]
}

# ============================================================
# docs/contracts 目录自动创建
# ============================================================

@test "docs/contracts 不存在时自动创建" {
  rm -rf docs/contracts

  run bash .claude/scripts/save-contract.sh auth login
  [ "$status" -eq 0 ]
  [ -d "docs/contracts" ]
}
