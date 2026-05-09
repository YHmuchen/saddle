# 身份

[在此描述你的角色、工作环境、使用的模型]

## 鞍流水线规则（优先级最高）

用户消息含"鞍"开头时，**必须**走流水线：

```
鞍 → /handoff → pm(规划) → 实现 → reviewer(审查) → 修复 → 推送
```

- 编码/创建/修改任务必须走流水线
- 例外：纯问答不需要
- 跳过任何一步就是违规

# 行为准则

- 编码前先读项目结构，理解现有模式再动手
- 改动超 5 个文件或涉及架构变更时，先写计划
- 完成后必须验证（运行、检查输出、确认无错误）
- 不要创建 README/文档文件，除非明确要求
- 不泄露密钥/Token，配置文件中敏感信息用占位符

# 禁止项

- `git push --force` / `git push --no-verify` — 永远禁止
- `rm -rf /` 或 `rm -rf ~` — 永远禁止
- 在非项目目录外执行写操作 — 用 project-boundary 思维自检

# 环境

[在此描述：编程语言版本、包管理器、特殊工具路径]

# 可用能力

- Skills: [列出已安装的 Skills]
- MCP: [列出已配置的 MCP Servers]
- 其他: [tmux、Docker 等]

# 工具偏好

- 改文件优先用 Edit（精确替换），整文件重写时才用 Write
- 搜索代码用 Grep（ripgrep），搜文件用 Glob，避免 cat/find/sed/awk

# 协作流程

```
需求 → /pm(规划) → 实现 → /reviewer(审查) → /pm(整理) → 修改 → 循环
       ↑                ↑                    ↑
    context:fork    context:fork         mode B 反馈
```

- `/pm` — 需求澄清、任务拆分、进度跟踪
- `/reviewer` — 代码审查 + 运行时验证
- `/handoff` — 查看流水线状态、阶段转换、跨会话恢复
- `/recover` — 创建检查点、回滚到稳定状态、中断恢复

## 恢复策略

| 场景 | 怎么做 |
|------|--------|
| 实现跑偏 | `/recover` → 回滚到上一检查点 → 重新实现 |
| review 评分 < 3/10 | pm 会建议回滚（不是继续改） |
| 同一问题 2 轮未修复 | 回滚后重新实现，不走修补路径 |
| 会话崩溃 | 重开 → SessionStart 检测中断 → `/recover` 模式C 恢复 |
| 轮次 >= 3 | pm 自动终止，人工裁定 |
| 严重问题 >= 5 | pm 建议回滚或人工介入 |

## 文件清单

- 配置: `~/.claude/settings.json` + `settings.local.json`
- Agent: `~/.claude/agents/pm.md` + `reviewer.md`
- Skill: `~/.claude/skills/` (pm / reviewer / handoff / recover)
- Artifacts: `~/.claude/artifacts/`
- Hooks: `~/.claude/hooks/session-start.sh` + `session-stop.sh`
