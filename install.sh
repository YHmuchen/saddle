#!/usr/bin/env bash
# 鞍 install — deploy to ~/.claude/

echo "鞍 (Saddle) 元 Harness — Claude Code Harness Setup"
echo ""

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude"

# 1. CLAUDE.md
cp "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"
echo "✅ CLAUDE.md"

# 2. Agents
mkdir -p "$DEST/agents"
cp "$SRC/agents/pm.md" "$DEST/agents/pm.md"
cp "$SRC/agents/inspector.md" "$DEST/agents/inspector.md"
cp "$SRC/agents/harness-generator.md" "$DEST/agents/harness-generator.md"
echo "✅ agents (pm + inspector + harness-generator)"

# 3. Skills
if [ -d "$SRC/skills/pm" ]; then cp -r "$SRC/skills/pm" "$DEST/skills/"; fi
if [ -d "$SRC/skills/handoff" ]; then cp -r "$SRC/skills/handoff" "$DEST/skills/"; fi
if [ -d "$SRC/skills/recover" ]; then cp -r "$SRC/skills/recover" "$DEST/skills/"; fi
if [ -d "$SRC/skills/鞍" ]; then cp -r "$SRC/skills/鞍" "$DEST/skills/"; fi
echo "✅ skills (pm / handoff / recover / 鞍)"

# 4. Hooks
mkdir -p "$DEST/hooks"
if [ -f "$SRC/hooks/session-start.sh" ]; then
  cp "$SRC/hooks/session-start.sh" "$DEST/hooks/session-start.sh"
  chmod +x "$DEST/hooks/session-start.sh"
fi
if [ -f "$SRC/hooks/session-stop.sh" ]; then
  cp "$SRC/hooks/session-stop.sh" "$DEST/hooks/session-stop.sh"
  chmod +x "$DEST/hooks/session-stop.sh"
fi
echo "✅ hooks (session-start + session-stop)"

# 5. Meta-Harness 工具
META_DIR="$DEST/meta-harness"
mkdir -p "$META_DIR/templates/agents"
mkdir -p "$META_DIR/examples"
mkdir -p "$META_DIR/harnesses"

cp "$SRC/scaffold.sh" "$META_DIR/scaffold.sh"
cp "$SRC/harness-manager.sh" "$META_DIR/harness-manager.sh"
chmod +x "$META_DIR/scaffold.sh"
chmod +x "$META_DIR/harness-manager.sh"

# 复制模板和示例
cp -r "$SRC/templates/agents/"*.template.md "$META_DIR/templates/agents/" 2>/dev/null || true
cp "$SRC/templates/harness-config.schema.json" "$META_DIR/templates/" 2>/dev/null || true
cp "$SRC/examples/"*.harness.json "$META_DIR/examples/" 2>/dev/null || true

# 复制 SADDLE 主智能体提示词作为参考
if [ -f "$SRC/SADDLE-主智能体提示词.md" ]; then
  cp "$SRC/SADDLE-主智能体提示词.md" "$META_DIR/SADDLE-主智能体提示词.md"
fi
echo "✅ meta-harness (scaffold.sh + harness-manager.sh + templates + examples)"

# 6. Artifacts
mkdir -p "$DEST/artifacts"
echo '{"round":0,"status":"idle","phase":"init"}' > "$DEST/artifacts/iteration.json"
echo "✅ artifacts"

echo ""
echo "============================================"
echo "  元 Harness 安装完成!"
echo "============================================"
echo ""
echo "已部署至: $DEST"
echo "  元 Harness 工具: $META_DIR"
echo ""
echo "快速上手:"
echo "  1. 生成 HTML 幻灯片 Harness:"
echo "     cd $META_DIR"
echo "     bash scaffold.sh examples/html-slide.harness.json"
echo "     bash harness-manager.sh list"
echo ""
echo "  2. 查看已生成的 Harness:"
echo "     bash $META_DIR/harness-manager.sh list"
echo ""
echo "  3. 启动 Harness 生成器 Agent:"
echo "     claude (然后说: 请 harness-generator 创建一个新的项目开发系统)"
echo ""
echo "MCP 配置请手动添加到 ~/.mcp.json："
echo "  参考: $SRC/templates/mcp.template.json"
