# 鞍 (Saddle)

Claude Code 四层 Harness 工作流 — 上下文 · 工具 · 编排 · 恢复

## 架构

```
┌─ 第一层：上下文 ── CLAUDE.md ────────────────┐
│  角色定义 / 环境区分 / 禁止项 / 能力声明       │
├─ 第二层：工具 ─── MCP ────────────────────────┤
│  SearXNG 搜索 / Bilibili 字幕 / agent-browser  │
│  reviewer 真实验证（不只读代码）                │
├─ 第三层：编排 ─── context:fork + Hook ─────────┤
│  pm ⇄ reviewer 闭环 / handoff 交接 / 看板     │
├─ 第四层：恢复 ─── git + artifacts ────────────┤
│  检查点 / 回滚 / 崩溃检测 / 中断恢复           │
└─────────────────────────────────────────────────┘
```

## 流水线

```
需求 → /pm(规划) → 实现 → /reviewer(审查) → /pm(整理) → 循环
        ↑                ↑                    ↑
    context:fork     context:fork          回滚决策
        │                                    │
        └── /recover(检查点) ←────────────────┘
```

## 快速开始

```bash
# 1. 安装依赖
npm install -g agent-browser bilibili-mcp

# 2. 部署到 ~/.claude/
./install.sh

# 3. 配置 MCP (编辑 ~/.mcp.json)
# 参考 templates/mcp.template.json

# 4. 重启 Claude Code
claude
```

## 文件结构

```
鞍/
├── CLAUDE.md           # 全局上下文注入
├── agents/
│   ├── pm.md           # 项目经理 (模式A:规划 / 模式B:整理)
│   └── reviewer.md     # 审查员 (读代码 + 真实验证)
├── skills/
│   ├── pm/SKILL.md
│   ├── reviewer/SKILL.md
│   ├── handoff/SKILL.md # 流水线交接
│   └── recover/SKILL.md # 故障恢复
├── hooks/
│   ├── session-start.sh # 流水线看板 + 中断检测
│   └── session-stop.sh  # 退出状态保存
├── artifacts/           # 流水线状态文件
├── templates/           # 配置模板
├── install.sh           # 部署脚本
└── README.md
```

## 恢复策略

| 场景 | 怎么做 |
|------|--------|
| 实现跑偏 | `/recover` → 回滚 → 重做 |
| review < 3/10 | pm 建议回滚 |
| 同问题 2 轮未修 | 回滚重做 |
| 会话崩溃 | 重开 → 检测中断 → `/recover` |
| 轮次 ≥ 3 | pm 终止，人工裁定 |

## 依赖

- Claude Code v2.1+
- agent-browser (浏览器验证)
- bash + git (检查点/回滚)
- SearXNG MCP (搜索)
- Bilibili MCP (视频字幕)
