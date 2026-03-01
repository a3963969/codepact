#!/usr/bin/env bats
# tests/setup.bats — 测试 .claude/scripts/setup.sh

load helpers

setup() {
  setup_isolated_repo
}

teardown() {
  teardown_isolated_repo
}

# ============================================================
# Hook 安装
# ============================================================

@test "setup.sh 安装 pre-commit hook 到 .git/hooks/" {
  # 确保 hook 尚未安装
  rm -f .git/hooks/pre-commit

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [ -f ".git/hooks/pre-commit" ]
}

@test "安装的 hook 具有可执行权限" {
  rm -f .git/hooks/pre-commit

  bash .claude/scripts/setup.sh
  [ -x ".git/hooks/pre-commit" ]
}

@test "hook 内容与 hooks/pre-commit 一致" {
  rm -f .git/hooks/pre-commit

  bash .claude/scripts/setup.sh
  diff hooks/pre-commit .git/hooks/pre-commit
}

@test "hooks/pre-commit 不存在时 setup.sh 退出码为 1" {
  rm hooks/pre-commit

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"hooks/pre-commit 文件不存在"* ]]
}

@test "重复运行 setup.sh 幂等成功" {
  bash .claude/scripts/setup.sh
  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [ -f ".git/hooks/pre-commit" ]
}

# ============================================================
# 目录创建
# ============================================================

@test "setup.sh 创建 docs/contracts 目录" {
  rm -rf docs/contracts

  bash .claude/scripts/setup.sh
  [ -d "docs/contracts" ]
}

@test "setup.sh 创建 .metrics 目录" {
  rm -rf .metrics

  bash .claude/scripts/setup.sh
  [ -d ".metrics" ]
}

@test "目录已存在时不报错" {
  mkdir -p docs/contracts .metrics

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
}

# ============================================================
# 语言检测
# ============================================================

@test "检测 Node.js 项目 (package.json)" {
  echo '{}' > package.json

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Node.js 项目"* ]]
}

@test "检测 Python 项目 (requirements.txt)" {
  rm -f package.json
  echo "flask" > requirements.txt

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Python 项目"* ]]
}

@test "检测 Python 项目 (pyproject.toml)" {
  rm -f package.json
  echo "[project]" > pyproject.toml

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Python 项目"* ]]
}

@test "同时存在 package.json 和 requirements.txt 时警告" {
  echo '{}' > package.json
  echo "flask" > requirements.txt

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"同时检测到"* ]]
}

@test "无项目配置文件时提示新项目" {
  rm -f package.json requirements.txt pyproject.toml

  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"未检测到"* ]]
}

# ============================================================
# 非 git 仓库场景
# ============================================================

@test "非 git 仓库中跳过 hook 安装但不失败" {
  NON_GIT="$(mktemp -d)"
  mkdir -p "$NON_GIT/.claude/scripts" "$NON_GIT/hooks" "$NON_GIT/docs/contracts"
  cp .claude/scripts/setup.sh "$NON_GIT/.claude/scripts/"
  cp hooks/pre-commit "$NON_GIT/hooks/"
  cp docs/contracts/_template.md "$NON_GIT/docs/contracts/"

  cd "$NON_GIT"
  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"不在 git 仓库中"* ]]

  rm -rf "$NON_GIT"
}

# ============================================================
# 输出格式
# ============================================================

@test "输出包含初始化完成信息" {
  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"初始化完成"* ]]
}

@test "输出包含 GitHub 配置指引" {
  run bash .claude/scripts/setup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"ANTHROPIC_API_KEY"* ]]
  [[ "$output" == *"DINGTALK_WEBHOOK"* ]]
}
