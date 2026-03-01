#!/usr/bin/env bats
# tests/pre-commit.bats — 测试 hooks/pre-commit 在实际 git commit 中的阻断行为

load helpers

setup() {
  setup_isolated_repo

  # 创建一个最小 Node.js 项目来测试 pre-commit hook
  cat > package.json <<'PKGJSON'
{
  "name": "test-project",
  "scripts": {
    "test": "node test.js"
  }
}
PKGJSON

  # 安装 pre-commit hook
  bash .claude/scripts/setup.sh >/dev/null 2>&1
}

teardown() {
  teardown_isolated_repo
}

# ============================================================
# Hook 安装验证
# ============================================================

@test "setup.sh 安装的 hook 可被 git 识别" {
  [ -f ".git/hooks/pre-commit" ]
  [ -x ".git/hooks/pre-commit" ]
}

# ============================================================
# 测试通过时允许提交
# ============================================================

@test "测试通过时 commit 成功" {
  # 创建一个总是成功的测试脚本
  echo 'process.exit(0)' > test.js
  git add -A
  git commit -m "should succeed" --no-gpg-sign
  # 如果 commit 成功，最新 commit 消息应该是 "should succeed"
  run git log -1 --format=%s
  [ "$output" = "should succeed" ]
}

# ============================================================
# 测试失败时阻断提交
# ============================================================

@test "测试失败时 commit 被阻断" {
  # 创建一个总是失败的测试脚本
  echo 'process.exit(1)' > test.js
  git add -A

  run git commit -m "should fail" --no-gpg-sign
  [ "$status" -ne 0 ]
}

@test "测试失败时输出阻断消息" {
  echo 'process.exit(1)' > test.js
  git add -A

  run git commit -m "should fail" --no-gpg-sign
  [[ "$output" == *"Tests failed"* ]] || [[ "$output" == *"Commit aborted"* ]]
}

@test "测试失败后工作区变更仍保留（不丢失数据）" {
  echo 'process.exit(1)' > test.js
  echo "important change" > important.txt
  git add -A

  run git commit -m "should fail" --no-gpg-sign
  [ "$status" -ne 0 ]

  # 文件应该仍然存在且在暂存区
  [ -f "important.txt" ]
  run git diff --cached --name-only
  [[ "$output" == *"important.txt"* ]]
}

# ============================================================
# 边界情况
# ============================================================

@test "npm test 不存在时 hook 阻断提交" {
  # 删除 package.json 让 npm test 失败
  rm package.json
  echo "some file" > dummy.txt
  git add -A

  run git commit -m "no npm" --no-gpg-sign
  [ "$status" -ne 0 ]
}

@test "hook 输出包含 Running pre-commit tests 提示" {
  echo 'process.exit(0)' > test.js
  git add -A

  # 捕获 hook 输出（git commit 会转发 hook 的 stdout/stderr）
  run git commit -m "check output" --no-gpg-sign
  [[ "$output" == *"Running pre-commit tests"* ]]
}

@test "测试通过时 hook 输出 All tests passed" {
  echo 'process.exit(0)' > test.js
  git add -A

  run git commit -m "check passed output" --no-gpg-sign
  [[ "$output" == *"All tests passed"* ]]
}

# ============================================================
# 连续提交场景
# ============================================================

@test "修复测试后可以成功提交" {
  # 第一次：失败
  echo 'process.exit(1)' > test.js
  git add -A
  run git commit -m "fail first" --no-gpg-sign
  [ "$status" -ne 0 ]

  # 第二次：修复后成功
  echo 'process.exit(0)' > test.js
  git add -A
  run git commit -m "fixed and pass" --no-gpg-sign
  [ "$status" -eq 0 ]

  run git log -1 --format=%s
  [ "$output" = "fixed and pass" ]
}
