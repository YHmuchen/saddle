#!/usr/bin/env bash
#=============================================================================
# Saddle 元 Harness 脚手架生成器
#
# 用法:
#   ./scaffold.sh <harness-config.json> [output-dir]
#
# 说明:
#   读入 harness-config.json, 渲染模板, 生成完整项目特化 harness 目录
#
# 依赖: bash 4.0+ (MSYS2/Git Bash on Windows)
# 创建时间: 2026-05
#=============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "${CYAN}[STEP]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_TEMPLATES_DIR="$SCRIPT_DIR/templates/agents"

# ---- JSON 解析函数 ----

# 取字符串值: json_get "$JSON" "key"
json_get() {
  local json="$1" key="$2" result
  result=$(echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed "s/\"${key}\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//')
  if [ -z "$result" ]; then
    result=$(echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[^,}\r\n]*" | head -1 | sed "s/\"${key}\"[[:space:]]*:[[:space:]]*//" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  fi
  echo "$result"
}

# 取数组内容 (压成单行后提取)
json_get_array() {
  local json="$1" key="$2"
  local oneline
  oneline=$(echo "$json" | tr -d '\n\r' | tr -s ' ')
  echo "$oneline" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\[[^]]*\]" | head -1 | sed "s/\"${key}\"[[:space:]]*:[[:space:]]*\[//" | sed 's/\]$//'
}

# 从 JSON 对象列表中提取每个对象的字段 (grep 逐对象)
extract_obj_fields() {
  local array_json="$1"
  echo "$array_json" | grep -o '{[^}]*}'
}

# ---- 渲染模板 (用 Python 处理多行值和特殊字符) ----
render_template() {
  local template="$1" output="$2"
  shift 2
  cp "$template" "$output"
  python3 -c "
import sys
content = open(sys.argv[1], encoding='utf-8').read()
keys = sys.argv[2:]
for i in range(0, len(keys), 2):
    content = content.replace('\${' + keys[i] + '}', keys[i+1])
open(sys.argv[1], 'w', encoding='utf-8').write(content)
" "$output" "$@" 2>/dev/null || {
    # 若 Python 渲染失败，回退到简单 sed（仅处理单行值）
    warn "Python 渲染失败，回退到 sed"
    cp "$template" "$output"
    while [ $# -ge 2 ]; do
      local k="$1" v="$2"
      shift 2
      local e
      e=$(printf '%s\n' "$v" | sed 's/[\/&]/\\&/g')
      if [[ "$(uname -s)" == *"MSYS"* ]] || [[ "$(uname -s)" == *"MINGW"* ]]; then
        sed -i "s/\${${k}}/${e}/g" "$output"
      else
        sed -i.bak "s/\${${k}}/${e}/g" "$output" && rm -f "$output.bak"
      fi
    done
  }
}

# ---- 主逻辑 ----
main() {
  local CONFIG_FILE="${1:-}" OUTPUT_DIR="${2:-}"

  [ -z "$CONFIG_FILE" ] && { echo "用法: $0 <harness-config.json> [output-dir]"; exit 1; }
  [ -f "$CONFIG_FILE" ] || error "配置文件不存在: $CONFIG_FILE"

  local CONFIG; CONFIG=$(cat "$CONFIG_FILE")

  # ---- 解析顶层字段 ----
  local PROJECT_TYPE;       PROJECT_TYPE=$(json_get "$CONFIG" "project_type")
  local PROJECT_DESCRIPTION; PROJECT_DESCRIPTION=$(json_get "$CONFIG" "description")
  local OUTPUT_ARTIFACT;    OUTPUT_ARTIFACT=$(json_get "$CONFIG" "output_artifact")
  local UNIT_ID_FORMAT;     UNIT_ID_FORMAT=$(json_get "$CONFIG" "unit_id_format")
  [ -z "$UNIT_ID_FORMAT" ] && UNIT_ID_FORMAT="unit{NN}"

  local BATCH_SIZE; BATCH_SIZE=$(json_get "$CONFIG" "default_batch_size"); [ -z "$BATCH_SIZE" ] && BATCH_SIZE="1"
  local MAX_ROUNDS; MAX_ROUNDS=$(json_get "$CONFIG" "max_correction_rounds"); [ -z "$MAX_ROUNDS" ] && MAX_ROUNDS="3"
  local MAX_CONC;   MAX_CONC=$(json_get "$CONFIG" "max_concurrency"); [ -z "$MAX_CONC" ] && MAX_CONC="3"
  local TEMPLATE_SOURCE; TEMPLATE_SOURCE=$(json_get "$CONFIG" "template_source")

  # ---- 解析 agent_names 子对象 (压成单行后提取) ----
  local CONFIG_NL AN_RAW
  CONFIG_NL=$(echo "$CONFIG" | tr -d '\n\r')
  AN_RAW=$(echo "$CONFIG_NL" | grep -o '"agent_names"[[:space:]]*:[[:space:]]*{[^}]*}' | sed 's/"agent_names"[[:space:]]*:[[:space:]]*//')
  local AGENT_PLANNER; AGENT_PLANNER=$(json_get "$AN_RAW" "planner"); [ -z "$AGENT_PLANNER" ] && AGENT_PLANNER="dg-planner"
  local AGENT_DEV;     AGENT_DEV=$(json_get "$AN_RAW" "developer");   [ -z "$AGENT_DEV" ] && AGENT_DEV="dg-dev"

  # ---- 解析 artifact_patterns 子对象 (压成单行后提取) ----
  local AP_RAW
  AP_RAW=$(echo "$CONFIG_NL" | grep -o '"artifact_patterns"[[:space:]]*:[[:space:]]*{[^}]*}' | sed 's/"artifact_patterns"[[:space:]]*:[[:space:]]*//')
  local PLAN_FILE;           PLAN_FILE=$(json_get "$AP_RAW" "plan_file");             [ -z "$PLAN_FILE" ] && PLAN_FILE="dev-plan.md"
  local DESIGN_GUIDE;        DESIGN_GUIDE=$(json_get "$AP_RAW" "design_guide");       [ -z "$DESIGN_GUIDE" ] && DESIGN_GUIDE="page-design-guide.md"
  local LESSONS_LEARNED;     LESSONS_LEARNED=$(json_get "$AP_RAW" "lessons_learned"); [ -z "$LESSONS_LEARNED" ] && LESSONS_LEARNED="lessons-learned.md"
  local TEST_REPORT_DIR;     TEST_REPORT_DIR=$(json_get "$AP_RAW" "test_report_dir"); [ -z "$TEST_REPORT_DIR" ] && TEST_REPORT_DIR="test-reports"
  local TEST_REPORT_PATTERN; TEST_REPORT_PATTERN=$(json_get "$AP_RAW" "test_report_pattern"); [ -z "$TEST_REPORT_PATTERN" ] && TEST_REPORT_PATTERN="{unit_id}-{dimension}.md"
  local LOG_FILE;            LOG_FILE=$(json_get "$AP_RAW" "log_file");               [ -z "$LOG_FILE" ] && LOG_FILE="main-log.md"

  # ---- 解析 skills & test_dimensions ----
  local SKILLS_JSON;    SKILLS_JSON=$(json_get_array "$CONFIG" "skills")
  local TEST_DIMS_JSON; TEST_DIMS_JSON=$(json_get_array "$CONFIG" "test_dimensions")
  [ -z "$TEST_DIMS_JSON" ] && error "test_dimensions 不能为空"

  # ---- 定义换行符，用于构建多行 YAML 值 ----
  NL=$'\n'

  # ---- 确定输出目录 ----
  [ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="$SCRIPT_DIR/harnesses/$PROJECT_TYPE"

  if [ -d "$OUTPUT_DIR" ]; then
    warn "输出目录已存在: $OUTPUT_DIR"
    if [ -t 0 ]; then
      read -p "是否覆盖? (y/N) " CONFIRM
    else
      CONFIRM="n"
    fi
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { info "已取消"; exit 0; }
    rm -rf "$OUTPUT_DIR"
  fi

  step "创建 harness 目录: $OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR/agents" "$OUTPUT_DIR/templates" "$OUTPUT_DIR/skills" "$OUTPUT_DIR/hooks" "$OUTPUT_DIR/artifacts"
  cp "$CONFIG_FILE" "$OUTPUT_DIR/harness-config.json"

  # ---- 准备渲染变量 ----
  local UNIT_ID_EXAMPLE="${UNIT_ID_FORMAT//\{NN\}/01}"

  local SKILLS_YAML=""
  if [ -n "$SKILLS_JSON" ]; then
    SKILLS_YAML="  - $(echo "$SKILLS_JSON" | sed 's/,/\
  - /g')"
  fi

  local DIM_NAMES=""
  DIM_NAMES=$(echo "$TEST_DIMS_JSON" | sed 's/,/\n/g' | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"name"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

  local COMMON_VARS=()
  COMMON_VARS+=("PROJECT_TYPE" "$PROJECT_TYPE")
  COMMON_VARS+=("PROJECT_DESCRIPTION" "$PROJECT_DESCRIPTION")
  COMMON_VARS+=("OUTPUT_ARTIFACT" "$OUTPUT_ARTIFACT")
  COMMON_VARS+=("UNIT_ID_EXAMPLE" "$UNIT_ID_EXAMPLE")
  COMMON_VARS+=("UNIT_ID_FORMAT" "$UNIT_ID_FORMAT")
  COMMON_VARS+=("SKILLS_YAML" "$SKILLS_YAML")
  COMMON_VARS+=("AGENT_NAMES.planner" "$AGENT_PLANNER")
  COMMON_VARS+=("AGENT_NAMES.developer" "$AGENT_DEV")
  COMMON_VARS+=("ARTIFACT_PATTERNS.plan_file" "$PLAN_FILE")
  COMMON_VARS+=("ARTIFACT_PATTERNS.design_guide" "$DESIGN_GUIDE")
  COMMON_VARS+=("ARTIFACT_PATTERNS.lessons_learned" "$LESSONS_LEARNED")
  COMMON_VARS+=("ARTIFACT_PATTERNS.test_report_dir" "$TEST_REPORT_DIR")
  COMMON_VARS+=("ARTIFACT_PATTERNS.test_report_pattern" "$TEST_REPORT_PATTERN")
  COMMON_VARS+=("ARTIFACT_PATTERNS.log_file" "$LOG_FILE")
  COMMON_VARS+=("TEMPLATE_SOURCE" "$TEMPLATE_SOURCE")
  COMMON_VARS+=("BATCH_SIZE" "$BATCH_SIZE")
  COMMON_VARS+=("MAX_CORRECTION_ROUNDS" "$MAX_ROUNDS")
  COMMON_VARS+=("MAX_CONCURRENCY" "$MAX_CONC")
  COMMON_VARS+=("TEST_DIMENSIONS_LIST" "$DIM_NAMES")

  step "生成 Agent 定义文件..."

  # planner
  [ -f "$AGENT_TEMPLATES_DIR/planner.template.md" ] && {
    render_template "$AGENT_TEMPLATES_DIR/planner.template.md" "$OUTPUT_DIR/agents/$AGENT_PLANNER.md" "${COMMON_VARS[@]}"
    info "已生成: agents/$AGENT_PLANNER.md"
  } || warn "planner 模板不存在，跳过"

  # developer
  [ -f "$AGENT_TEMPLATES_DIR/dev.template.md" ] && {
    render_template "$AGENT_TEMPLATES_DIR/dev.template.md" "$OUTPUT_DIR/agents/$AGENT_DEV.md" "${COMMON_VARS[@]}"
    info "已生成: agents/$AGENT_DEV.md"
  } || warn "dev 模板不存在，跳过"

  # ---- 逐维度生成 tester ----
  local TESTER_AGENTS_YAML="" DIM_COUNT=0

  while IFS= read -r dim_entry; do
    [ -z "$dim_entry" ] && continue

    local dim_name dim_desc dim_agent dim_skill
    dim_name=$(json_get "$dim_entry" "name")
    dim_desc=$(json_get "$dim_entry" "description")
    dim_agent=$(json_get "$dim_entry" "agent_name")
    dim_skill=$(json_get "$dim_entry" "skill_ref")
    [ -z "$dim_name" ] && continue
    [ -z "$dim_agent" ] && dim_agent="tester-${dim_name}"

    local DIM_VARS=("${COMMON_VARS[@]}")
    DIM_VARS+=("TESTER_DIMENSION_NAME" "$dim_name")
    DIM_VARS+=("TESTER_DIMENSION_DESCRIPTION" "$dim_desc")
    DIM_VARS+=("TESTER_AGENT_NAME" "$dim_agent")
    DIM_VARS+=("TESTER_SKILLS_YAML" "[${dim_skill}]")
    DIM_VARS+=("UNIT_ID_ATTR" "${UNIT_ID_FORMAT//\{NN\}/01}")

    [ -f "$AGENT_TEMPLATES_DIR/tester.template.md" ] && {
      render_template "$AGENT_TEMPLATES_DIR/tester.template.md" "$OUTPUT_DIR/agents/$dim_agent.md" "${DIM_VARS[@]}"
      info "已生成: agents/$dim_agent.md ($dim_name)"
    }

    TESTER_AGENTS_YAML="${TESTER_AGENTS_YAML}  - dimension: ${dim_name}${NL}    agent: ${dim_agent}${NL}"
    DIM_COUNT=$((DIM_COUNT + 1))

  done < <(extract_obj_fields "$TEST_DIMS_JSON")

  [ "$DIM_COUNT" -eq 0 ] && error "未找到有效的测试维度定义"

  # ---- 生成 orchestrator 主智能体提示词 ----
  [ -f "$AGENT_TEMPLATES_DIR/orchestrator.template.md" ] && {
    local ORCH_VARS=("${COMMON_VARS[@]}")
    ORCH_VARS+=("TESTER_AGENTS_YAML" "$TESTER_AGENTS_YAML")
    local AP_YAML="  output_artifact: ${OUTPUT_ARTIFACT}${NL}  plan_file: ${PLAN_FILE}${NL}  design_guide: ${DESIGN_GUIDE}${NL}  lessons_learned: ${LESSONS_LEARNED}${NL}  test_report_dir: ${TEST_REPORT_DIR}${NL}  test_report_pattern: ${TEST_REPORT_PATTERN}${NL}  log_file: ${LOG_FILE}"
    ORCH_VARS+=("ARTIFACT_PATTERNS_YAML" "$AP_YAML")
    render_template "$AGENT_TEMPLATES_DIR/orchestrator.template.md" "$OUTPUT_DIR/主智能体提示词.md" "${ORCH_VARS[@]}"
    info "已生成: 主智能体提示词.md"
  }

  # ---- 收尾 ----
  touch "$OUTPUT_DIR/artifacts/.gitkeep"

  cat > "$OUTPUT_DIR/HARNESS.md" << HARNESS_EOF
# ${PROJECT_DESCRIPTION}
> 由 Saddle 元 Harness 于 $(date +%Y-%m-%d) 生成

## 配置
- 项目类型: \`${PROJECT_TYPE}\`
- 产出物: \`${OUTPUT_ARTIFACT}\`
- 单元格式: \`${UNIT_ID_FORMAT}\`
- 测试维度: ${DIM_NAMES}

## Agent
| 角色 | 文件 |
|------|------|
| 计划 | agents/${AGENT_PLANNER}.md |
| 开发 | agents/${AGENT_DEV}.md |
| 编排 | 主智能体提示词.md |
HARNESS_EOF

  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Harness 生成完成!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "输出目录: $OUTPUT_DIR"
  echo ""
  echo "目录结构:"
  find "$OUTPUT_DIR" -type f -not -path "*/artifacts/*" | sed "s|$OUTPUT_DIR/||" | sort | while IFS= read -r f; do echo "  - $f"; done
  echo ""
}

main "$@"
