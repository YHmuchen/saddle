#!/usr/bin/env bash
# 鞍 install — deploy to ~/.claude/

echo "鞍 (Saddle) - Claude Code Harness Setup"
echo ""

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude"

# 1. CLAUDE.md
cp "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"
echo "✅ CLAUDE.md"

# 2. Agents
mkdir -p "$DEST/agents"
cp "$SRC/agents/pm.md" "$DEST/agents/pm.md"
cp "$SRC/agents/reviewer.md" "$DEST/agents/reviewer.md"
echo "✅ agents (pm + reviewer)"

# 3. Skills
cp -r "$SRC/skills/pm" "$DEST/skills/"
cp -r "$SRC/skills/reviewer" "$DEST/skills/"
cp -r "$SRC/skills/handoff" "$DEST/skills/"
cp -r "$SRC/skills/recover" "$DEST/skills/"
echo "✅ skills (pm / reviewer / handoff / recover)"

# 4. Hooks
cp "$SRC/hooks/session-start.sh" "$DEST/hooks/session-start.sh"
cp "$SRC/hooks/session-stop.sh" "$DEST/hooks/session-stop.sh"
chmod +x "$DEST/hooks/session-start.sh"
chmod +x "$DEST/hooks/session-stop.sh"
echo "✅ hooks (session-start + session-stop)"

# 5. Artifacts
mkdir -p "$DEST/artifacts"
echo '{"round":0,"status":"idle","phase":"init"}' > "$DEST/artifacts/iteration.json"
echo "✅ artifacts"

echo ""
echo "Done. Restart Claude Code."
echo ""
echo "MCP 配置请手动添加到 ~/.mcp.json："
echo "  参考: $SRC/templates/mcp.template.json"
