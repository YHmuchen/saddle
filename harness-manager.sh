#!/usr/bin/env bash
#=============================================================================
# Saddle 元 Harness 管理器
#
# 用法:
#   ./harness-manager.sh list          — 列出所有已生成的 harness
#   ./harness-manager.sh inspect <id>  — 查看指定 harness 的配置
#   ./harness-manager.sh destroy <id>  — 删除指定 harness
#   ./harness-manager.sh path  <id>    — 显示指定 harness 的路径
#   ./harness-manager.sh help          — 显示帮助
#
# 说明:
#   管理由 scaffold.sh 生成的"harnesses/"目录下的所有项目特化 harness。
#   Harness 可通过 "id"（目录名）或数字索引引用。
#
# 创建时间: 2026-05
#=============================================================================

set -euo pipefail

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESSES_DIR="$SCRIPT_DIR/harnesses"

# ---- 确保 harnesses 目录存在 ----
ensure_dir() {
  mkdir -p "$HARNESSES_DIR"
}

# ---- 列出所有 harness ----
cmd_list() {
  ensure_dir

  # 检查 harnesses 目录是否为空
  if [ -z "$(ls -A "$HARNESSES_DIR" 2>/dev/null)" ]; then
    info "暂无已生成的 harness。"
    echo ""
    echo "使用 ./scaffold.sh 创建第一个 harness:"
    echo "  ./scaffold.sh examples/html-slide.harness.json"
    exit 0
  fi

  echo -e "${BOLD}已生成的 Harness 列表:${NC}"
  echo ""

  local index=0
  for dir in "$HARNESSES_DIR"/*/; do
    if [ -d "$dir" ]; then
      local id=$(basename "$dir")
      local config="$dir/harness-config.json"
      local desc=""

      if [ -f "$config" ]; then
        # 读取描述（使用简易 JSON 解析）
        desc=$(grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' "$config" 2>/dev/null | head -1 | sed 's/"description"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
        local project_type=$(grep -o '"project_type"[[:space:]]*:[[:space:]]*"[^"]*"' "$config" 2>/dev/null | head -1 | sed 's/"project_type"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
        echo -e "  ${CYAN}[$index]${NC} ${BOLD}$id${NC} — $desc"
        echo -e "       类型: $project_type  |  配置: $config"

        # 统计文件数
        local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo -e "       文件数: $file_count"
      else
        echo -e "  ${CYAN}[$index]${NC} ${BOLD}$id${NC} (配置缺失)"
      fi
      echo ""
      index=$((index + 1))
    fi
  done

  if [ "$index" -eq 0 ]; then
    warn "未找到有效的 harness 目录。"
  fi

  echo -e "使用: ${BOLD}$0 inspect <id|index>${NC} 查看详情"
  echo -e "使用: ${BOLD}$0 destroy <id|index>${NC} 删除"
}

# ---- 通过 ID 或索引查找 harness 目录 ----
resolve_harness_dir() {
  local target="$1"

  # 先尝试直接作为目录名
  if [ -d "$HARNESSES_DIR/$target" ]; then
    echo "$HARNESSES_DIR/$target"
    return 0
  fi

  # 尝试作为数字索引
  if [[ "$target" =~ ^[0-9]+$ ]]; then
    local index=0
    for dir in "$HARNESSES_DIR"/*/; do
      if [ -d "$dir" ]; then
        if [ "$index" -eq "$target" ]; then
          echo "$dir"
          return 0
        fi
        index=$((index + 1))
      fi
    done
  fi

  return 1
}

# ---- 查看 harness 详情 ----
cmd_inspect() {
  local target="${1:-}"
  [ -z "$target" ] && error "请指定 harness ID 或索引。使用 list 查看可用列表。"

  local dir
  dir=$(resolve_harness_dir "$target") || error "未找到 harness: $target"

  local id=$(basename "$dir")
  echo -e "${BOLD}Harness: $id${NC}"
  echo ""

  if [ -f "$dir/harness-config.json" ]; then
    echo -e "${CYAN}--- 配置 ---${NC}"
    cat "$dir/harness-config.json"
    echo ""
  else
    warn "配置文件不存在。"
  fi

  echo -e "${CYAN}--- 文件结构 ---${NC}"
  find "$dir" -type f -not -path "*/artifacts/*" | sort | while IFS= read -r f; do
    echo "  ${f#$dir/}"
  done
  echo ""

  # 检测是否有主智能体提示词
  if [ -f "$dir/主智能体提示词.md" ]; then
    local lines=$(wc -l < "$dir/主智能体提示词.md")
    echo -e "主智能体提示词: ${lines} 行"
  fi

  # 检测 agent 文件
  local agent_count=$(find "$dir/agents" -name "*.md" 2>/dev/null | wc -l)
  echo -e "Agent 文件: ${agent_count} 个"
}

# ---- 删除 harness ----
cmd_destroy() {
  local target="${1:-}"
  [ -z "$target" ] && error "请指定 harness ID 或索引。"

  local dir
  dir=$(resolve_harness_dir "$target") || error "未找到 harness: $target"

  local id=$(basename "$dir")

  echo -e "${YELLOW}警告: 即将删除 harness '${id}'${NC}"
  echo "  路径: $dir"

  # 检查文件数
  local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
  echo "  影响文件: ${file_count} 个"

  read -p "确认删除？(y/N) " CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    info "已取消。"
    exit 0
  fi

  rm -rf "$dir"
  info "已删除: $id"
}

# ---- 显示路径 ----
cmd_path() {
  local target="${1:-}"
  [ -z "$target" ] && error "请指定 harness ID 或索引。"

  local dir
  dir=$(resolve_harness_dir "$target") || error "未找到 harness: $target"
  echo "$dir"
}

# ---- 帮助 ----
cmd_help() {
  echo "Saddle 元 Harness 管理器"
  echo ""
  echo "用法:"
  echo "  $0 list                   列出所有 harness"
  echo "  $0 inspect <id|index>     查看 harness 配置详情"
  echo "  $0 destroy <id|index>     删除 harness"
  echo "  $0 path <id|index>        显示 harness 路径"
  echo "  $0 help                   显示此帮助"
  echo ""
  echo "参数:"
  echo "  id        harness 目录名（如 html-slide）"
  echo "  index     harness 数字索引（可用 list 查看）"
  echo ""
  echo "示例:"
  echo "  $0 list"
  echo "  $0 inspect html-slide"
  echo "  $0 inspect 0"
  echo "  $0 destroy html-slide"
}

# ---- 入口 ----
main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true

  case "$cmd" in
    list)
      cmd_list
      ;;
    inspect)
      cmd_inspect "${1:-}"
      ;;
    destroy)
      cmd_destroy "${1:-}"
      ;;
    path)
      cmd_path "${1:-}"
      ;;
    help|--help|-h)
      cmd_help
      ;;
    *)
      error "未知命令: $cmd。使用 $0 help 查看帮助。"
      ;;
  esac
}

main "$@"
