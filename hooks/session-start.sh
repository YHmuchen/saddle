#!/usr/bin/env bash
ARTIFACTS="$HOME/.claude/artifacts"

echo ""
echo "  ┌──────────────────────────────┐"
echo "  │  Pipeline Dashboard           │"
echo "  └──────────────────────────────┘"

# Phase detection
PHASE="idle"
NEXT="说出你的需求"

if [ -f "$ARTIFACTS/iteration.json" ]; then
  ROUND=$(grep -o '"round":[0-9]*' "$ARTIFACTS/iteration.json" | grep -o '[0-9]*')
  STATUS=$(grep -o '"status":"[^"]*"' "$ARTIFACTS/iteration.json" | cut -d'"' -f4)
  echo "  Round: $ROUND | Status: $STATUS"
fi

if [ -f "$ARTIFACTS/plan.md" ]; then
  echo "  Plan: ✅"
  PHASE="planned"
  NEXT="按计划实现代码"
else
  echo "  Plan: ─"
fi

if [ -f "$ARTIFACTS/review-report.md" ]; then
  SCORE=$(head -30 "$ARTIFACTS/review-report.md" | grep -o '正确性:[0-9]*/10' | head -1)
  echo "  Review: ✅ ($SCORE)"
  PHASE="reviewed"
  NEXT="运行 /pm 处理审查反馈"
else
  echo "  Review: ─"
fi

if [ -f "$ARTIFACTS/modification-checklist.md" ]; then
  COUNT=$(grep -c '^|' "$ARTIFACTS/modification-checklist.md" 2>/dev/null)
  echo "  Checklist: ✅ ($COUNT items)"
  PHASE="checklist"
  NEXT="按清单逐项修改代码"
else
  echo "  Checklist: ─"
fi

# Crash detection
if [ -f "$ARTIFACTS/iteration.json" ]; then
  STATUS=$(grep -o '"status":"[^"]*"' "$ARTIFACTS/iteration.json" | cut -d'"' -f4)
  if [ "$STATUS" = "implementing" ]; then
    echo "  ⚠️  Last session interrupted during implementation"
    echo "  Suggestion: /recover to check state, or continue"
  fi
fi

echo "  ────────────────────────────────"
echo "  Phase: $PHASE"
echo "  Next:  $NEXT"
echo ""
