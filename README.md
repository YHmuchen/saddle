# 鞍 (Saddle)

Claude Code 四层 Harness 工作流框架 — 上下文 · 工具 · 编排 · 恢复

## 架构

```
┌─ 第一层：上下文 ── CLAUDE.md ────────────────┐
│  角色定义 / 行为准则 / 禁止项 / 环境声明        │
├─ 第二层：工具 ─── MCP + Agent 能力 ───────────┤
│  搜索 / 浏览器验证 / reviewer 真实验证          │
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

## 安装

```bash
# 克隆本项目
git clone https://github.com/YOUR_USER/saddle.git
cd saddle

# 1. 编辑 CLAUDE.md — 填入你的环境信息
# 2. 配置 MCP — 编辑 templates/mcp.template.json 后合并到 ~/.mcp.json
# 3. 配置 settings — 参考 templates/settings.template.json
# 4. 部署
./install.sh
```

## 文件结构

```
鞍/
├── CLAUDE.md              # 全局上下文注入（模板，需自定义）
├── install.sh             # 一键部署到 ~/.claude/
├── .gitignore             # 排除密钥和运行时状态
├── agents/
│   ├── pm.md              # 项目经理 (模式A:规划 / 模式B:整理+回滚决策)
│   └── reviewer.md        # 审查员 (读代码 + 运行测试 + 浏览器验证)
├── skills/
│   ├── pm/SKILL.md          # /pm 入口
│   ├── reviewer/SKILL.md    # /reviewer 入口
│   ├── handoff/SKILL.md     # /handoff 流水线看板与交接
│   ├── recover/SKILL.md     # /recover 检查点与故障恢复
│   └── bili-summary/        # /bili-summary 视频下载+转写+总结
│       ├── SKILL.md
│       ├── summarize.sh
│       └── requirements.txt
├── hooks/
│   ├── session-start.sh   # 启动时显示流水线看板 + 中断检测
│   └── session-stop.sh    # 退出时保存状态
├── artifacts/             # 流水线状态文件（.gitignore 排除）
│   ├── iteration.json     #  { round, status, phase }
│   ├── plan.md            #  当前计划
│   ├── review-report.md   #  最近审查报告
│   └── modification-checklist.md
├── templates/             # 配置模板
└── README.md
```

## 四个组件

| 组件 | 调用 | 作用 |
|------|------|------|
| **pm** | `/pm` | 模式A: 需求→任务清单 / 模式B: 审查反馈→修改清单+回滚决策 |
| **reviewer** | `/reviewer` | 读代码 + 运行验证 + 浏览器测试 → 审查报告 |
| **handoff** | `/handoff` | 流水线看板、阶段转换、跨会话继续 |
| **recover** | `/recover` | 创建检查点、git 回滚、中断恢复 |
| **bili-summary** | `/bili-summary` | 下载音频 → Whisper 转写 → LLM 总结 |

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
- bash + git
- 可选: agent-browser (浏览器验证)
- 可选: SearXNG MCP (聚合搜索)
