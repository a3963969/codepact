#!/usr/bin/env bats
# tests/report.bats — 测试 .claude/scripts/report.sh

load helpers

setup() {
  setup_isolated_repo
}

teardown() {
  teardown_isolated_repo
}

# 辅助函数：生成 mock ci-log.jsonl 条目
write_log_entry() {
  local date="$1" actor="$2" status="$3" run_id="$4" commit="${5:-$run_id}"
  echo "{\"date\":\"${date}\",\"actor\":\"${actor}\",\"branch\":\"main\",\"commit\":\"${commit}\",\"status\":\"${status}\",\"run_id\":\"${run_id}\"}" >> .metrics/ci-log.jsonl
}

# ============================================================
# 参数校验
# ============================================================

@test "默认统计 30 天" {
  # 创建一条今天的数据
  write_log_entry "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "alice" "success" "1"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"最近 30 天"* ]]
}

@test "自定义天数参数生效" {
  write_log_entry "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "alice" "success" "1"

  run bash .claude/scripts/report.sh 7
  [ "$status" -eq 0 ]
  [[ "$output" == *"最近 7 天"* ]]
}

@test "非数字参数被拒绝" {
  run bash .claude/scripts/report.sh abc
  [ "$status" -eq 1 ]
  [[ "$output" == *"参数必须为数字"* ]]
}

@test "注入参数被拒绝" {
  run bash .claude/scripts/report.sh '10;rm -rf /'
  [ "$status" -eq 1 ]
  [[ "$output" == *"参数必须为数字"* ]]
}

# ============================================================
# 文件不存在
# ============================================================

@test "ci-log.jsonl 不存在时退出码为 1" {
  rm -f .metrics/ci-log.jsonl

  run bash .claude/scripts/report.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"指标文件不存在"* ]]
}

@test "ci-log.jsonl 不存在时输出 download-metrics.sh 提示" {
  rm -f .metrics/ci-log.jsonl

  run bash .claude/scripts/report.sh
  [[ "$output" == *"download-metrics.sh"* ]]
}

# ============================================================
# 统计逻辑
# ============================================================

@test "全部成功时首次通过率 100%" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "alice" "success" "1" "aaa"
  write_log_entry "$NOW" "bob" "success" "2" "bbb"
  write_log_entry "$NOW" "alice" "success" "3" "ccc"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"3/3 = 100.0%"* ]]
}

@test "部分失败时正确计算首次通过率" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "alice" "success" "1" "aaa"
  write_log_entry "$NOW" "bob" "failure" "2" "bbb"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"1/2 = 50.0%"* ]]
}

@test "全部失败时首次通过率 0%" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "alice" "failure" "1" "aaa"
  write_log_entry "$NOW" "bob" "failure" "2" "bbb"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"0/2 = 0.0%"* ]]
}

# ============================================================
# 按 commit 去重
# ============================================================

@test "同一 commit 多次运行只取首次（最小 run_id）" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # commit aaa 运行了两次: run_id=1 失败, run_id=3 成功
  write_log_entry "$NOW" "alice" "failure" "1" "aaa"
  write_log_entry "$NOW" "alice" "success" "3" "aaa"
  # commit bbb 成功
  write_log_entry "$NOW" "bob" "success" "2" "bbb"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  # 总运行 3 次，去重后 2 个独立提交
  [[ "$output" == *"总 CI 运行次数：3"* ]]
  [[ "$output" == *"2 个独立提交"* ]]
  # 首次通过率：commit aaa 首次(run_id=1) 失败，commit bbb 成功 → 1/2
  [[ "$output" == *"1/2 = 50.0%"* ]]
}

# ============================================================
# 时间过滤
# ============================================================

@test "超出时间窗口的数据被过滤" {
  # 100 天前的数据
  OLD_DATE="2020-01-01T00:00:00Z"
  write_log_entry "$OLD_DATE" "alice" "failure" "1" "old"

  # 今天的数据
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "bob" "success" "2" "new"

  run bash .claude/scripts/report.sh 7
  [ "$status" -eq 0 ]
  # 7 天内只有 bob 的 1 条
  [[ "$output" == *"1/1 = 100.0%"* ]]
}

@test "全部数据超出窗口时显示无数据" {
  OLD_DATE="2020-01-01T00:00:00Z"
  write_log_entry "$OLD_DATE" "alice" "success" "1" "old"

  run bash .claude/scripts/report.sh 7
  [ "$status" -eq 0 ]
  [[ "$output" == *"无数据"* ]]
}

# ============================================================
# 按操作人分组
# ============================================================

@test "多个操作人时按操作人分组显示" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "alice" "success" "1" "aaa"
  write_log_entry "$NOW" "alice" "success" "2" "bbb"
  write_log_entry "$NOW" "bob" "failure" "3" "ccc"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"按操作人分组"* ]]
  [[ "$output" == *"alice"* ]]
  [[ "$output" == *"bob"* ]]
}

@test "单一操作人时不显示分组" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "alice" "success" "1" "aaa"
  write_log_entry "$NOW" "alice" "success" "2" "bbb"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  # 只有一个操作人时不显示分组
  [[ "$output" != *"按操作人分组"* ]]
}

# ============================================================
# 报告格式
# ============================================================

@test "输出包含报告标题" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "alice" "success" "1"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Agent 绩效报告"* ]]
}

@test "输出包含分隔线" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_log_entry "$NOW" "alice" "success" "1"

  run bash .claude/scripts/report.sh
  [[ "$output" == *"=========================="* ]]
}

# ============================================================
# 异常数据容错
# ============================================================

@test "空行和无效 JSON 被跳过不报错" {
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  {
    echo ""
    echo "this is not json"
    echo "{invalid json too}"
  } > .metrics/ci-log.jsonl
  write_log_entry "$NOW" "alice" "success" "1"

  run bash .claude/scripts/report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"1/1 = 100.0%"* ]]
}
