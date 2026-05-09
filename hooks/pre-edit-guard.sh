#!/usr/bin/env bash
# 鞍 pre-edit guard: 编辑代码前检查 pm 规划状态
ARTIFACTS="$HOME/.claude/artifacts"
FILE="$2"

# 放行：鞍自身配置
case "$FILE" in
  *".claude/"*|*"/hooks/"*|*"/skills/"*|*"/agents/"*|*"/artifacts/"*|*"/鞍/"*|*"/saddle/"*)
    exit 0 ;;
esac

# 只拦截代码文件
case "$FILE" in
  *.py|*.js|*.ts|*.tsx|*.jsx|*.vue|*.go|*.rs|*.java|*.rb|*.sh|*.html|*.css|*.json|*.yaml|*.yml|*.md|*.txt) ;;
  *) exit 0 ;;
esac

# 无 iteration.json = 新环境，放行
if [ ! -f "$ARTIFACTS/iteration.json" ]; then
  exit 0
fi

# 有迭代文件则检查状态
STATUS=$(grep -o '"status":"[^"]*"' "$ARTIFACTS/iteration.json" | cut -d'"' -f4)
case "$STATUS" in
  idle|planned|checklist|implementing) exit 0 ;;
  interrupted)
    echo ""
    echo "  ⛔ 鞍: 上次会话中断，请先 /handoff 检查状态"
    echo ""
    exit 1 ;;
  *)
    echo ""
    echo "  ⛔ 鞍: 未检测到活跃计划 (status=$STATUS)"
    echo "  请先 /pm 规划，或说'跳过pm'"
    echo ""
    exit 1 ;;
esac
