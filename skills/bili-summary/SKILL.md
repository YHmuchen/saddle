---
name: bili-summary
description: 总结 Bilibili/Youtube 视频内容。自动下载音频 → 本地 Whisper 转写 → LLM 总结。用于无字幕视频的深度总结。触发词：总结视频、bili、summary、视频讲了什么、帮我看看这个视频。
---

# 视频总结 Skill

## 适用场景

视频**有字幕**时直接用 Bilibili MCP 提取，**无字幕**时用本 Skill 做本地转写+总结。

## 工作流

```
视频链接 → yt-dlp 下载音频 → faster-whisper 转写 → LLM 总结
```

## 使用方式

```
/bili-summary https://www.bilibili.com/video/BVxxxx
/bili-summary https://www.youtube.com/watch?v=xxxx
```

## 参数

| 参数 | 说明 | 默认 |
|------|------|------|
| `--model` | Whisper 模型 | tiny |
| `--language` | 视频语言 | zh |
| `--no-summary` | 只转写不总结 | false |

## 依赖

```bash
pip install yt-dlp faster-whisper
```
