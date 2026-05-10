# 鞍 (Saddle)

**Claude Code 多智能体 Harness 工作流**

鞍是一个基于 Claude Code Agent Teams 的多智能体协作框架。核心理念是**主智能体只调度不干活**——通过 orchestrator 统一编排，将需求分析、代码实现、多维度审查分离到不同角色，实现软件开发的流水线自动化。

---

## 核心理念

```
主 Agent (你) → orchestrator → dev + N×tester → 轮次仲裁 → 完成
```

传统的 AI 编码方式是单 Agent 包揽一切：理解需求、写代码、检查、修改都在同一上下文中完成。这会导致上下文膨胀、角色混淆、质量不稳定。

鞍的做法是**分工**：

- **orchestrator** — 只调度，不干活。负责任务分发、Agent 管理、PASS/FAIL 仲裁、Agent ID 恢复与复用。
- **dev** — 只写代码。根据需求和计划实现功能，根据测试报告修正问题。
- **tester** — 只审查。按维度（correctness、safety、quality 等）检查代码质量，输出 PASS/FAIL。

---

## 架构

```
                        ┌──────────────────┐
                        │   orchestrator    │
                        │  (只调度不干活)    │
                        └────────┬─────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
       ┌──────▼──────┐  ┌───────▼────────┐  ┌──────▼─────────┐
       │    dev       │  │ tester-正确性   │  │ tester-安全性   │
       │  (写代码)     │  │ (审查功能)      │  │ (审查安全)      │
       └──────┬───────┘  └───────┬────────┘  └──────┬─────────┘
              │                  │                   │
              └──────────────────┼───────────────────┘
                                 │
                        ┌────────▼────────┐
                        │   PASS/FAIL     │
                        │   仲裁(3轮上限)  │
                        └─────────────────┘
```

### 测试维度动态定义

测试维度不从代码中固定，而由 `project-config.json` 的 `tester_dimensions` 字段定义。每个维度对应一个独立的 tester Agent：

```json
{
  "tester_dimensions": [
    { "name": "correctness", "description": "功能正确性审查" },
    { "name": "safety",      "description": "安全性审查" },
    { "name": "performance", "description": "性能审查" }
  ]
}
```

这意味着你可以**为每个项目定制审查维度**，比如给前端项目加 `accessibility` 维度，给 API 项目加 `rate-limit` 维度。

---

## 工作流

```
需求 → pm(规划) → orchestrator(调度) → dev(实现) → testers(审查) → 修正循环 → 完成
```

### 完整流程

1. **pm 规划** — 项目经理将需求拆分为可执行的任务列表，写入 `plan.md`
2. **orchestrator 调度** — 读取 plan.md，按 batch_size 分组，逐一调度
3. **批量开发** — 启动 dev Agent，一个会话中连续开发本批所有任务
4. **批量测试** — 为每个维度启动 tester Agent，并行审查本批任务
5. **修正循环（最多 3 轮）** —
   - 有 FAIL 则 resume 同一个 dev Agent 修正
   - 修正后 resume 对应的 tester Agent 重测
   - 全 PASS 或 3 轮满则进入下一批
6. **收尾** — 统计迭代情况，写入最终日志

### 修正循环细节

```
Round 0: dev 实现 → 各维度 tester 测试
         ↓ 有 FAIL
Round 1: resume dev 修正 → resume FAIL 维度 tester 重测
         ↓ 还有 FAIL
Round 2: resume dev 修正 → resume FAIL 维度 tester 重测
         ↓ 仍有 FAIL（第 3 轮上限）
         标记为 ⚠️ 低质量通过
```

核心机制：
- **Agent ID 恢复** — 修正循环必须 resume 同一个 Agent，而不是新建。orchestrator 通过文件系统探测 Agent ID 并缓存到日志中。
- **PASS/FAIL 仲裁** — tester 输出以 `VERDICT: PASS` 或 `VERDICT: FAIL` 结尾，orchestrator 用 Grep 提取判定，不读完整报告以节省上下文。
- **上下文预算** — orchestrator 不读需求文件、不读审查报告、不读代码文件，只传递路径和判定结果，保持自身上下文长期稳定。
- **经验沉淀** — dev Agent 在修正后将通用性经验写入 `lessons-learned.md`，后续任务自动读取避免重复踩坑。

---

## 关键特性

| 特性 | 说明 |
|------|------|
| **Agent ID 恢复** | 修正循环 resume 同一个子 Agent，不创建新实例 |
| **3 轮修正上限** | 同一任务最多修正 3 轮，第 3 轮仍 FAIL 则标记低质量通过 |
| **PASS/FAIL 仲裁** | Tester 输出标准判定，orchestrator 只取判定不读全文 |
| **上下文预算** | 各 Agent 各司其职，orchestrator 保持上下文长期清洁 |
| **经验沉淀** | lessons-learned.md 积累跨项目可迁移经验 |
| **并发上限 3** | 测试阶段同时运行不超过 3 个 Agent |
| **批量控制** | 通过 batch_size 控制并行粒度，默认单任务 |
| **会话恢复** | SessionStart/SessionStop Hook 自动检测中断状态 |

---

## 快速开始

### 前置条件

- Claude Code（Agent Teams 模式）
- bash（Windows 推荐 MSYS2 / Git Bash）
- 一个可用的 LLM API（DeepSeek / Anthropic 等）

### 安装

```bash
git clone <your-repo-url>
cd 鞍
./install.sh
```

`install.sh` 会将以下内容部署到 `~/.claude/`：

- `CLAUDE.md` — 项目全局指令
- `agents/pm.md` — 项目经理 Agent 定义
- `agents/inspector.md` — 验收员 Agent 定义
- `skills/pm` / `skills/handoff` / `skills/recover` / `skills/鞍` — 配套技能
- `hooks/session-start.sh` + `hooks/session-stop.sh` — 会话 Hook
- `artifacts/iteration.json` — 流水线状态文件

### 自定义配置

参考 `templates/settings.template.json` 配置环境变量和 Hook：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "YOUR_BASE_URL",
    "ANTHROPIC_AUTH_TOKEN": "YOUR_AUTH_TOKEN",
    "ANTHROPIC_MODEL": "YOUR_MODEL"
  },
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "bash \"${HOME}/.claude/hooks/session-start.sh\"", "timeout": 5 }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "bash \"${HOME}/.claude/hooks/session-stop.sh\"", "timeout": 5 }] }]
  }
}
```

MCP 配置参考 `templates/mcp.template.json`。

### 启动

```bash
claude --permission-mode bypassPermissions
```

SessionStart Hook 会自动显示流水线看板，检测中断状态。

---

## 项目结构

```
鞍/
├── CLAUDE.md              # 项目全局指令
├── install.sh             # 部署脚本
├── agents/
│   ├── orchestrator.md       # 编排 Agent
│   ├── dev.md                # 通用开发 Agent
│   ├── tester.md             # 通用测试 Agent
│   ├── pm.md                 # 项目经理 Agent
│   ├── inspector.md          # 验收 Agent
│   ├── harness-generator.md  # Harness 生成器
│   ├── dg-planner.md         # 领域专用计划 Agent
│   ├── dg-dev.md             # 领域专用开发 Agent
│   └── dg-tester.md          # 领域专用测试 Agent
├── skills/
│   ├── pm/                # 规划技能
│   ├── handoff/           # 交接技能
│   ├── recover/           # 恢复技能
│   ├── 鞍/                # 调度入口
│   └── bili-summary/      # B站总结技能
├── hooks/
│   ├── session-start.sh   # 启动 Hook（看板显示）
│   └── session-stop.sh    # 停止 Hook（中断标记）
├── templates/
│   ├── agents/            # Agent 渲染模板
│   ├── settings.template.json  # 配置模板
│   └── mcp.template.json       # MCP 模板
├── examples/              # 示例 harness 配置
├── harnesses/             # 生成的 harness 输出
├── artifacts/             # 运行时工作成果
└── .gitignore
```

---

## 恢复策略

| 场景 | 处理方式 |
|------|----------|
| 实现跑偏 | `/recover` 回滚到上一检查点 |
| review 评分 < 3/10 | pm 建议回滚，不继续修补 |
| 同一问题 2 轮未修复 | 回滚后重新实现 |
| 会话崩溃 | SessionStart 检测中断 → `/recover` 恢复 |
| 轮次 >= 3 | pm 自动终止，人工裁定 |
| 严重问题 >= 5 | pm 建议回滚或人工介入 |

---

## 工作原理：为什么叫"鞍"？

"鞍"是马鞍的鞍——它连接骑手（你）和马力（AI Agent），让你稳稳地坐在上面，控制方向而不必亲自奔跑。

在传统 AI 编码中，你是马：亲自处理每一个上下文切换、每一次代码修改。在鞍的框架下，你是骑手：定方向、看结果，中间的所有奔跑都交给 Agent 去完成。

---

## 元 Harness 使用指南

Saddle 不仅是一个通用编排框架，还是一个**元 Harness**（harness for writing different project harnesses）。你可以为任意项目类型生成一套特化的多智能体开发系统。

### 概念

```
元 Harness (Saddle本身)
    │
    ├── scaffold.sh             ← 脚手架生成器
    ├── harness-manager.sh      ← Harness 管理器
    └── templates/agents/       ← Agent 模板
          │
          ▼ 读入 harness-config.json
          │
    项目特化 Harness (生成物)
          │
          ├── 主智能体提示词.md
          ├── agents/planner.md
          ├── agents/dev.md
          ├── agents/tester-*.md
          └── harness-config.json
```

### 第一步：创建项目配置

在 `examples/` 目录下创建 `<your-project>.harness.json`，参考现有示例：

```json
{
  "project_type": "my-type",
  "description": "我的项目多智能体开发系统",
  "output_artifact": "output.py",
  "unit_id_format": "unit{NN}",
  "test_dimensions": [
    {"name": "correctness", "description": "功能正确性审查", "agent_name": "my-tester-correctness"}
  ],
  "agent_names": {
    "planner": "my-planner",
    "developer": "my-dev"
  },
  "artifact_patterns": {
    "plan_file": "dev-plan.md",
    "design_guide": "design-guide.md",
    "lessons_learned": "lessons-learned.md",
    "test_report_dir": "test-reports",
    "test_report_pattern": "{unit_id}-{dimension}.md",
    "log_file": "main-log.md"
  },
  "default_batch_size": 1,
  "max_correction_rounds": 3,
  "max_concurrency": 3
}
```

### 第二步：生成 Harness

```bash
./scaffold.sh examples/my-type.harness.json
```

输出到 `harnesses/my-type/`，包含完整的项目特化多智能体开发系统。

### 第三步：管理 Harness

```bash
./harness-manager.sh list               # 列出所有 harness
./harness-manager.sh inspect my-type    # 查看详情
./harness-manager.sh destroy my-type    # 删除
```

### 使用 Harness 生成器 Agent

也可以使用 `harness-generator` Agent 交互式创建：

```
你: "请创建一个 Python CLI 工具的多智能体开发系统"
→ harness-generator 会引导你配置各参数并自动运行 scaffold.sh
```

### 模板引擎说明

`templates/agents/` 目录包含 4 个渲染模板：

| 模板 | 生成目标 | 占位符来源 |
|------|----------|-----------|
| `planner.template.md` | `agents/<planner>.md` | AGENT_NAMES.planner, ARTIFACT_PATTERNS, SKILLS |
| `dev.template.md` | `agents/<developer>.md` | AGENT_NAMES.developer, ARTIFACT_PATTERNS, SKILLS |
| `tester.template.md` | `agents/<tester-N>.md` | TEST_DIMENSIONS[N].*, ARTIFACT_PATTERNS |
| `orchestrator.template.md` | `主智能体提示词.md` | 全部配置 |

渲染时，`scaffold.sh` 使用 shell sed 将 `${PLACEHOLDER}` 替换为配置值。

---

## License

MIT
