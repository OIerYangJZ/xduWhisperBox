#!/usr/bin/env bash
# scripts/health_check.sh
# 健康检查脚本：验证前端、后端和关键服务是否正常工作。
#
# 使用方式：
#   ./health_check.sh                    # 默认检查本机
#   ./health_check.sh --verbose          # 详细输出
#   API_BASE_URL=https://... ./health_check.sh  # 指定 API 地址
#   WEB_BASE_URL=https://... ./health_check.sh  # 指定前端地址
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认检查本机服务，可通过环境变量覆盖
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:8080/api}"
WEB_BASE_URL="${WEB_BASE_URL:-http://127.0.0.1:8080}"
TIMEOUT="${TIMEOUT:-5}"

# 详细模式
VERBOSE="${VERBOSE:-0}"
if [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "-v" ]; then
  VERBOSE=1
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

log_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_CHECKS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_info() {
    if [ "$VERBOSE" = "1" ]; then
        echo -e "      $1"
    fi
}

http_check() {
    local url="$1"
    local description="$2"
    local expected_codes="${3:-200}"
    local timeout="${4:-$TIMEOUT}"

    ((TOTAL_CHECKS++))
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if echo "$expected_codes" | grep -q "$http_code"; then
        log_pass "$description (HTTP $http_code)"
        return 0
    else
        log_fail "$description (HTTP $http_code, expected $expected_codes)"
        return 1
    fi
}

json_check() {
    local url="$1"
    local description="$2"
    local key="${3:-}"
    local expected_value="${4:-}"

    ((TOTAL_CHECKS++))
    local response
    response=$(curl -s --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "{}")

    if [ -z "$key" ]; then
        log_pass "$description - JSON 有效"
        return 0
    fi

    if echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$key',''))" 2>/dev/null | grep -q "$expected_value"; then
        log_pass "$description - $key=$expected_value"
        return 0
    else
        log_fail "$description - $key 未找到或值不匹配"
        return 1
    fi
}

echo "================================================"
echo "     西电树洞健康检查"
echo "================================================"
echo "检查时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "API 地址 : $API_BASE_URL"
echo "前端地址 : $WEB_BASE_URL"
echo ""

# ============================================================
# 1. 后端健康检查
# ============================================================
log_header "后端服务检查"

# 后端主端口连通性
((TOTAL_CHECKS++))
if curl -s --max-time 2 "http://127.0.0.1:8080" > /dev/null 2>&1 || curl -s --max-time 2 "$API_BASE_URL/health" > /dev/null 2>&1; then
    log_pass "后端端口 8080 可访问"
else
    log_fail "后端端口 8080 无法访问"
fi

# 后端健康接口
http_check "$API_BASE_URL/health" "后端健康检查接口"

# 后端版本接口
((TOTAL_CHECKS++))
VERSION_JSON=$(curl -s --max-time "$TIMEOUT" "$API_BASE_URL/version" 2>/dev/null || echo "{}")
if echo "$VERSION_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    log_pass "后端版本接口正常"
    if [ "$VERBOSE" = "1" ]; then
        echo "$VERSION_JSON" | python3 -m json.tool 2>/dev/null || echo "$VERSION_JSON"
    fi
else
    log_warn "后端版本接口不可用（可选）"
fi

# ============================================================
# 2. API 核心接口检查
# ============================================================
log_header "API 核心接口检查"

# 频道列表接口
http_check "$API_BASE_URL/channels" "获取频道列表"

# 帖子列表接口
http_check "$API_BASE_URL/posts" "获取帖子列表"

# ============================================================
# 3. 前端服务检查
# ============================================================
log_header "前端服务检查"

# 前端主页面
http_check "$WEB_BASE_URL/" "前端主页面"

# index.html 存在性
((TOTAL_CHECKS++))
if curl -s --max-time "$TIMEOUT" "$WEB_BASE_URL/index.html" > /dev/null 2>&1; then
    log_pass "index.html 可访问"
else
    log_fail "index.html 不可访问"
fi

# 版本 meta 标签检查
((TOTAL_CHECKS++))
VERSION_META=$(curl -s --max-time "$TIMEOUT" "$WEB_BASE_URL/index.html" 2>/dev/null | grep -o 'app-version.*content="[^"]*"' || echo "")
if [ -n "$VERSION_META" ]; then
    log_pass "前端版本标识: $VERSION_META"
else
    log_warn "前端版本标识未找到（可能未注入版本信息）"
fi

# ============================================================
# 4. 静态资源缓存策略检查
# ============================================================
log_header "静态资源缓存策略检查"

# JS 文件缓存检查
((TOTAL_CHECKS++))
CACHE_HEADER=$(curl -s -I --max-time "$TIMEOUT" "$WEB_BASE_URL/main.dart.js" 2>/dev/null | grep -i "Cache-Control" | tr -d '\r' || echo "")
if echo "$CACHE_HEADER" | grep -qi "max-age=31536000\|public"; then
    log_pass "JS 文件配置了长期缓存"
else
    log_warn "JS 文件未配置长期缓存"
fi

# HTML 文件不缓存检查
((TOTAL_CHECKS++))
HTML_CACHE=$(curl -s -I --max-time "$TIMEOUT" "$WEB_BASE_URL/index.html" 2>/dev/null | grep -i "Cache-Control" | tr -d '\r' || echo "")
if echo "$HTML_CACHE" | grep -qi "no-cache\|no-store"; then
    log_pass "HTML 文件配置了不缓存"
else
    log_warn "HTML 文件可能配置了缓存（建议 no-cache）"
fi

# ============================================================
# 5. Nginx 反向代理检查
# ============================================================
log_header "Nginx 反向代理检查"

# API 代理到后端
((TOTAL_CHECKS++))
if curl -s --max-time "$TIMEOUT" -H "Host: localhost" "$WEB_BASE_URL/api/health" > /dev/null 2>&1; then
    log_pass "Nginx API 代理正常"
else
    log_warn "Nginx API 代理可能未配置"
fi

# ============================================================
# 6. 系统资源检查（仅 verbose 模式）
# ============================================================
if [ "$VERBOSE" = "1" ]; then
    log_header "系统资源（详细模式）"

    # 磁盘空间
    ((TOTAL_CHECKS++))
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")
    if [ "$DISK_USAGE" -lt 80 ]; then
        log_pass "磁盘空间充足 (使用 ${DISK_USAGE}%)"
    else
        log_warn "磁盘空间使用率较高 (${DISK_USAGE}%)"
    fi

    # 内存使用
    ((TOTAL_CHECKS++))
    if command -v free > /dev/null 2>&1; then
        MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}' || echo "0")
        MEM_USED=$(free -m | awk '/^Mem:/{print $3}' || echo "0")
        if [ "$MEM_TOTAL" -gt 0 ]; then
            MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
            if [ "$MEM_PCT" -lt 80 ]; then
                log_pass "内存使用正常 (${MEM_PCT}%)"
            else
                log_warn "内存使用率较高 (${MEM_PCT}%)"
            fi
        fi
    fi

    # 后端进程
    ((TOTAL_CHECKS++))
    if pgrep -f "server.py" > /dev/null 2>&1; then
        log_pass "后端进程运行中"
    else
        log_warn "后端进程未运行"
    fi
fi

# ============================================================
# 检查总结
# ============================================================
echo ""
echo "================================================"
echo "     检查总结"
echo "================================================"
echo "总计检查项: $TOTAL_CHECKS"
echo -e "通过: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "失败: ${RED}$FAILED_CHECKS${NC}"

if [ "$FAILED_CHECKS" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}所有检查通过！服务运行正常。${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}部分检查失败，请调查。${NC}"
    exit 1
fi
