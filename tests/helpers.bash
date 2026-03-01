# tests/helpers.bash
# 共享的测试辅助函数

# 创建一个临时隔离 git 仓库，复制框架文件
setup_isolated_repo() {
  TEST_REPO="$(mktemp -d)"
  cd "$TEST_REPO"
  git init --initial-branch=main
  git config user.email "test@test.com"
  git config user.name "Test User"

  # 复制框架文件
  local SRC="${BATS_TEST_DIRNAME}/.."
  mkdir -p .claude/scripts hooks docs/contracts .metrics

  cp "$SRC/.claude/scripts/setup.sh" .claude/scripts/
  cp "$SRC/.claude/scripts/save-contract.sh" .claude/scripts/
  cp "$SRC/.claude/scripts/report.sh" .claude/scripts/
  cp "$SRC/hooks/pre-commit" hooks/
  cp "$SRC/docs/contracts/_template.md" docs/contracts/

  # 初始提交，让 git 状态干净
  git add -A
  git commit -m "init" --no-verify
}

# 清理临时仓库
teardown_isolated_repo() {
  if [ -n "$TEST_REPO" ] && [ -d "$TEST_REPO" ]; then
    rm -rf "$TEST_REPO"
  fi
}
