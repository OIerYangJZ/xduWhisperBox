#!/usr/bin/env bash
# scripts/rollback.sh
# 回滚脚本：将 current 软链接指向上一个稳定版本目录。
# 支持参数：
#   ./rollback.sh              # 回滚到上一个版本
#   ./rollback.sh --list       # 仅列出可用版本
#   ./rollback.sh <版本名>     # 回滚到指定版本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/xdu-whisperbox}"
SERVICE_NAME="${SERVICE_NAME:-xdu-whisperbox}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[rollback]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[rollback]${NC} $1"
}

log_error() {
    echo -e "${RED}[rollback]${NC} $1"
}

echo "[rollback] === 西电树洞回滚脚本 ==="
echo "[rollback] DEPLOY_DIR: $DEPLOY_DIR"
echo "[rollback] SERVICE  : $SERVICE_NAME"

if [ ! -d "$DEPLOY_DIR" ]; then
  log_error "Error: deploy directory not found: $DEPLOY_DIR"
  echo "提示：设置 DEPLOY_DIR 环境变量指定部署目录"
  exit 1
fi

cd "$DEPLOY_DIR"

# 检查 releases 目录
if [ ! -d "$DEPLOY_DIR/releases" ]; then
  log_error "No releases directory found: $DEPLOY_DIR/releases"
  exit 1
fi

# 列出所有版本
list_releases() {
  echo ""
  echo "=== 可用版本 ==="

  if [ -L "$DEPLOY_DIR/current" ]; then
    CURRENT_TARGET=$(readlink -f "$DEPLOY_DIR/current" 2>/dev/null || echo "")
    CURRENT_NAME=$(basename "$CURRENT_TARGET" 2>/dev/null || echo "unknown")
    echo ""
    echo "当前版本: $CURRENT_NAME (软链接指向 $(basename "$CURRENT_TARGET"))"
    echo ""
  fi

  echo "版本列表（按时间倒序）："
  echo "---------------------------------------------------"
  ls -ltd releases/*/ 2>/dev/null | awk '{print $6, $7, $8, $9}' | while read date time path; do
    if [ -n "$path" ]; then
      name=$(basename "$path" 2>/dev/null || echo "")
      if [ -n "$name" ]; then
        if [ -L "$DEPLOY_DIR/current" ] && [ "$(readlink -f "$DEPLOY_DIR/current" 2>/dev/null)" = "$path" ]; then
          echo "  > $name (当前)"
        else
          echo "    $name"
        fi
      fi
    fi
  done
  echo "---------------------------------------------------"
}

# --list 参数：仅列出版本
if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
  list_releases
  exit 0
fi

# 解析参数
TARGET_VERSION=""
if [ $# -gt 0 ]; then
  TARGET_VERSION="$1"
fi

# 获取当前版本
CURRENT_LINK=""
if [ -L "$DEPLOY_DIR/current" ]; then
  CURRENT_LINK="$(readlink -f "$DEPLOY_DIR/current")"
  CURRENT_NAME=$(basename "$CURRENT_LINK" 2>/dev/null || echo "unknown")
  log_info "当前版本: $CURRENT_NAME"
fi

# 确定要回滚到的版本
if [ -n "$TARGET_VERSION" ]; then
  # 指定了版本
  TARGET_DIR="$DEPLOY_DIR/releases/$TARGET_VERSION"
  if [ ! -d "$TARGET_DIR" ]; then
    log_error "版本不存在: $TARGET_VERSION"
    echo ""
    list_releases
    exit 1
  fi
  if [ "$TARGET_DIR" = "$CURRENT_LINK" ]; then
    log_warn "已经是目标版本，无需回滚"
    exit 0
  fi
else
  # 自动选择上一个版本
  PREVIOUS=""

  if [ -d "$DEPLOY_DIR/releases" ]; then
    if [ -n "$CURRENT_LINK" ]; then
      # 排除当前版本
      PREVIOUS=$(ls -ltd "$DEPLOY_DIR/releases"/*/ 2>/dev/null | grep -v "$CURRENT_LINK/" | head -1 | awk '{print $NF}')
    else
      PREVIOUS=$(ls -ltd "$DEPLOY_DIR/releases"/*/ 2>/dev/null | head -1 | awk '{print $NF}')
    fi
  fi

  if [ -z "$PREVIOUS" ] || [ ! -d "$PREVIOUS" ]; then
    log_error "没有找到可回滚的版本"
    echo ""
    list_releases
    exit 1
  fi

  TARGET_DIR="$PREVIOUS"
fi

TARGET_NAME=$(basename "$TARGET_DIR")
log_info "目标版本: $TARGET_NAME"

# 确认操作
if [ "${AUTO_CONFIRM:-0}" != "1" ]; then
  echo ""
  read -p "确认回滚到 $TARGET_NAME? [y/N] " -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消回滚"
    exit 0
  fi
fi

# 执行回滚
echo ""

# 更新 current 软链接
if [ -L "$DEPLOY_DIR/current" ]; then
  rm -f "$DEPLOY_DIR/current"
fi
ln -s "$TARGET_DIR" "$DEPLOY_DIR/current"
log_info "软链接已更新: current -> $TARGET_NAME"

# 记录回滚日志
if [ -d "$DEPLOY_DIR/releases/$TARGET_NAME" ]; then
  ROLLBACK_LOG="$DEPLOY_DIR/releases/$TARGET_NAME/rollback.log"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - 回滚到此版本" >> "$ROLLBACK_LOG" 2>/dev/null || true
fi

# 重启服务
echo ""
if command -v systemctl >/dev/null 2>&1; then
  log_info "正在重启服务..."
  if systemctl restart "$SERVICE_NAME" 2>/dev/null; then
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      log_info "服务已重启"
      systemctl status "$SERVICE_NAME" --no-pager -l || true
    else
      log_warn "服务启动状态未知，请手动检查"
    fi
  else
    log_warn "无法通过 systemctl 重启服务，请手动重启"
  fi
elif command -v service >/dev/null 2>&1; then
  log_info "正在重启服务..."
  service "$SERVICE_NAME" restart 2>/dev/null || log_warn "无法通过 service 重启服务"
elif pgrep -f "server.py" > /dev/null; then
  log_info "正在重启 Python 服务..."
  pkill -f "server.py" 2>/dev/null || true
  sleep 1
  cd "$DEPLOY_DIR/current"
  nohup python3 server.py > /var/log/xdu-whisperbox.log 2>&1 &
  sleep 2
  if pgrep -f "server.py" > /dev/null; then
    log_info "服务已重启"
  else
    log_warn "服务启动失败，请检查日志"
  fi
else
  log_warn "未找到服务管理工具，请手动重启服务"
fi

echo ""
log_info "回滚完成"
echo "当前版本: $TARGET_NAME"
echo "部署目录: $TARGET_DIR"
