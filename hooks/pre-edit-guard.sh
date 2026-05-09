#!/usr/bin/env bash
# 鞍 pre-edit guard: 代码写入前检查 pm 规划状态
# 从 stdin JSON 读取 file_path，兼容所有 PreToolUse matcher
set -euo pipefail
ARTIFACTS="$HOME/.claude/artifacts"

# 从 stdin 读取 tool input，提取 file_path
if [ -p /dev/stdin ] || [ ! -t 0 ]; then
  RAW=$(cat)
  FILE=$(echo "$RAW" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || echo "")
else
  FILE="$2"
fi

# 空路径 = 放行
[ -z "$FILE" ] && exit 0

# 放行：鞍自身配置（精确 HOME 路径）
case "$FILE" in
  "$HOME/.claude/"*|"$HOME/.claude.json"|"$HOME/.mcp.json")
    exit 0 ;;
esac

# 只拦截代码文件
case "$FILE" in
  *.py|*.js|*.ts|*.tsx|*.jsx|*.vue|*.go|*.rs|*.java|*.rb|*.sh|*.html|*.css|*.json|*.yaml|*.yml|*.md|*.txt|*.ipynb) ;;
  *) exit 0 ;;
esac

# 无 iteration.json = 新环境，放行
[ ! -f "$ARTIFACTS/iteration.json" ] && exit 0

# 解析状态（jq 优先，grep 兜底）
if command -v jq &>/dev/null; then
  STATUS=$(jq -r '.status // "unknown"' "$ARTIFACTS/iteration.json" 2>/dev/null || echo "unknown")
else
  STATUS=$(grep -o '"status":"[^"]*"' "$ARTIFACTS/iteration.json" 2>/dev/null | head -1 | cut -d'"' -f4)
fi

case "${STATUS:-unknown}" in
  idle|planned|checklist|implementing) exit 0 ;;
  interrupted)
    echo ""; echo "  ⛔ 鞍: 上次会话中断，请先 /handoff 检查状态"; echo ""; exit 1 ;;
  *)
    echo ""; echo "  ⛔ 鞍: 未检测到活跃计划 (status=$STATUS)"; echo "  请先 /pm 规划，或说'跳过pm'"; echo ""; exit 1 ;;
esac
