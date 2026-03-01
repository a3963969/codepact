#!/bin/bash
# .claude/scripts/report.sh
# 用法：bash .claude/scripts/report.sh [天数]
# 示例：bash .claude/scripts/report.sh 30
#
# 数据来源：
#   - 本地模式：读取 .metrics/ci-log.jsonl（手动或脚本追加）
#   - CI 模式：先运行 download-metrics.sh 从 GitHub Artifacts 下载汇总

DAYS=${1:-30}
LOG_FILE=".metrics/ci-log.jsonl"

# 校验 DAYS 为纯数字，防止注入
if ! echo "$DAYS" | grep -qE '^[0-9]+$'; then
  echo "❌ 参数必须为数字，用法：bash .claude/scripts/report.sh [天数]"
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "❌ 指标文件不存在：$LOG_FILE"
  echo ""
  echo "数据来源说明："
  echo "  CI 指标以 GitHub Artifact 形式保存（ci-metrics-*），"
  echo "  请运行以下命令下载并汇总到本地："
  echo ""
  echo "    bash .claude/scripts/download-metrics.sh"
  echo ""
  echo "  或手动创建示例数据："
  echo "    mkdir -p .metrics"
  echo "    echo '{\"date\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"actor\":\"you\",\"branch\":\"main\",\"status\":\"success\",\"run_id\":\"1\"}' >> $LOG_FILE"
  exit 1
fi

python3 - <<EOF
import json
from datetime import datetime, timezone, timedelta

log_file = "$LOG_FILE"
days = int("$DAYS")

cutoff = datetime.now(timezone.utc) - timedelta(days=days)

logs = []
with open(log_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            entry_date = datetime.fromisoformat(entry['date'].replace('Z', '+00:00'))
            if entry_date >= cutoff:
                logs.append(entry)
        except:
            pass

if not logs:
    print(f"📊 最近 {days} 天无数据")
    exit()

# 按 commit SHA 去重：每个 commit 只取首次运行（最小 run_id）
from collections import defaultdict

commits = defaultdict(list)
for l in logs:
    commit = l.get('commit', l.get('run_id', ''))
    commits[commit].append(l)

first_runs = []
for commit, runs in commits.items():
    try:
        first = min(runs, key=lambda r: int(r.get('run_id', 0)))
    except (ValueError, TypeError):
        first = runs[0]
    first_runs.append(first)

total_runs = len(logs)
total_commits = len(first_runs)
passed = sum(1 for r in first_runs if r.get('status') == 'success')

print(f"===== Agent 绩效报告 =====")
print(f"统计周期：最近 {days} 天")
print(f"总 CI 运行次数：{total_runs}（去重后 {total_commits} 个独立提交）")
if total_commits > 0:
    print(f"首次通过率：{passed}/{total_commits} = {passed/total_commits*100:.1f}%")
else:
    print("首次通过率：无数据")

# 按操作人分组（使用去重后数据）
actors = {}
for r in first_runs:
    actor = r.get('actor', 'unknown')
    if actor not in actors:
        actors[actor] = {'total': 0, 'passed': 0}
    actors[actor]['total'] += 1
    if r.get('status') == 'success':
        actors[actor]['passed'] += 1

if len(actors) > 1:
    print("\n按操作人分组：")
    for actor, stats in sorted(actors.items()):
        rate = stats['passed'] / stats['total'] * 100
        print(f"  {actor}：通过 {stats['passed']}/{stats['total']} = {rate:.1f}%")

print("==========================")
EOF
