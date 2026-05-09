# 身份

全栈开发助手。环境：Windows 11 + MSYS2 (MINGW64) + DeepSeek v4-pro (cc-switch 管理)。

## 鞍触发规则（优先级最高）

用户消息含"鞍"开头或"鞍，"时，**必须**走流水线，不得跳过：

```
鞍 → /handoff 检查状态 → pm(规划) → 实现 → reviewer(审查) → 修复 → 推送
```

- 任何编码/创建/修改任务，只要用户说了"鞍"，第一步永远是派 pm，第二步才是动手
- 如果我在没派 pm 的情况下直接写了代码，那就是违规
- 例外：纯问答（"鞍，xxx是什么"）不需要走流水线

## cc-switch
- 当前模型：DeepSeek v4-pro[1m]，三档合一（Haiku/Sonnet/Opus 都指向同一模型）
- 切换配置用 cc-switch GUI，不要手动改 settings.json 的 env 字段
- 翻译/编码可能需要不同配置档，切换前确认目标工作类型

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

# Python 环境

- Python 3.12：`E:\manga-translator-ui\Miniconda3\python.exe`（翻译/ML 项目用）
- Python 3.14：`python3` / `python3.14`（日常脚本用）
- pip 对应：Miniconda 的 pip 给 3.12，用户目录的 pip 给 3.14
- 装包时明确目标环境，避免装错 Python 版本

# 可用能力

- Skills（9个）：web-design-engineer / guizang-ppt-skill / kb-retriever / pm / reviewer / handoff / gpt-image-2 / web-video-presentation / Superpowers 14项
- MCP（4个）：SearXNG 聚合搜索 / Bilibili 字幕提取 / Danbooru 图库 / agent-browser 浏览器自动化
- tmux：teammateMode 已启用，Agent Teams 已配置 (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- 启动方式：`claude --permission-mode bypassPermissions`（teammateMode 会自动激活）
- Agent Teams 用于需要成员间双向通信的任务（审查→反馈→修改→再审查），替代当前手动 pm→reviewer→pm 接力
- "鞍"触发时：优先使用 TeamCreate 创建 Team + spawn 队友，而非 Agent 子代理
- 团队成员用 SendMessage 直接通信，不再由主会话转发
- nah：已卸载，暂无替代 guard，操作前注意路径边界

# 工具偏好

- 改文件优先用 Edit（精确替换），整文件重写时才用 Write
- 搜索代码用 Grep（ripgrep），搜文件用 Glob，避免 cat/find/sed/awk
- GitHub 下载走 `gh-proxy.com` 代理（`https://gh-proxy.com/https://github.com/...`）

# 协作流程

```
需求 → /pm(规划) → 实现 → /reviewer(审查) → /pm(整理) → 修改 → 循环
       ↑                ↑                    ↑
    context:fork    context:fork         mode B 反馈
```

- `/handoff` — 查看流水线状态、阶段转换、跨会话恢复
- `/recover` — 创建检查点、回滚到稳定状态、中断恢复
- pm / reviewer 已启用 `context: fork`，独立上下文不污染主会话
- SessionStart Hook 自动显示流水线看板，检测中断状态
- SessionStop Hook 保存退出状态（正常/中断）
- 多 Agent 并行用 Superpowers dispatching-parallel-agents
- Artifacts 目录: `.claude/artifacts/`（plan.md / review-report.md / modification-checklist.md / iteration.json）

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
- Skill: `~/.claude/skills/` (10个)
- MCP: `~/.mcp.json` (4个)
- Artifacts: `~/.claude/artifacts/`
- Hooks: `~/.claude/hooks/session-start.sh` + `session-stop.sh`
