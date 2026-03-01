#!/bin/bash
# .claude/scripts/download-metrics.sh
# 从 GitHub Artifacts 下载 CI 指标并汇总到 .metrics/ci-log.jsonl
# 依赖：gh CLI（已登录）
# 用法：bash .claude/scripts/download-metrics.sh

set -e

if ! command -v gh &> /dev/null; then
  echo "❌ 需要安装 gh CLI：https://cli.github.com/"
  exit 1
fi

mkdir -p .metrics

# 动态检测当前仓库
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
  echo "❌ 无法检测当前仓库，请确认："
  echo "  1. 在 git 仓库目录下运行"
  echo "  2. 已登录 gh CLI（gh auth login）"
  echo "  3. 仓库已关联 GitHub remote"
  exit 1
fi

echo "📥 正在从 ${REPO} 的 GitHub Artifacts 下载 CI 指标..."

# 列出所有 ci-metrics-* artifact 并逐个下载
ARTIFACTS=$(gh api "repos/${REPO}/actions/artifacts" --paginate -q '.artifacts[] | select(.name | startswith("ci-metrics-")) | .id')

if [ -z "$ARTIFACTS" ]; then
  echo "ℹ️ 未找到 CI 指标 artifact"
  exit 0
fi

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT
COUNT=0

for ARTIFACT_ID in $ARTIFACTS; do
  rm -rf "${_TMPDIR}/extracted"
  gh api "repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip" > "${_TMPDIR}/${ARTIFACT_ID}.zip" 2>/dev/null || { echo "  ⚠️ 下载 artifact ${ARTIFACT_ID} 失败，跳过"; continue; }
  unzip -qo "${_TMPDIR}/${ARTIFACT_ID}.zip" -d "${_TMPDIR}/extracted" 2>/dev/null || { echo "  ⚠️ 解压 artifact ${ARTIFACT_ID} 失败，跳过"; continue; }

  if [ -f "${_TMPDIR}/extracted/ci-result.json" ]; then
    cat "${_TMPDIR}/extracted/ci-result.json" >> .metrics/ci-log.jsonl
    COUNT=$((COUNT + 1))
  fi
done

# 去重（按 run_id）
if [ -f .metrics/ci-log.jsonl ]; then
  python3 -c "
import json
seen = set()
lines = []
with open('.metrics/ci-log.jsonl') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            d = json.loads(line)
            rid = d.get('run_id', line)
            if rid not in seen:
                seen.add(rid)
                lines.append(line)
        except: pass
with open('.metrics/ci-log.jsonl', 'w') as f:
    f.write('\n'.join(lines) + '\n')
print(f'✅ 已汇总 {len(lines)} 条指标记录（本次新增 $COUNT 条）')
"
fi
