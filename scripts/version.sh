#!/usr/bin/env bash
# scripts/version.sh
# 生成版本标识信息，供构建脚本和部署流程使用。
#
# 使用方式：
#   source version.sh                    # 加载所有版本变量
#   source version.sh && echo $GIT_HASH # 使用版本变量
#   ./version.sh                         # 输出 JSON 格式
#   ./version.sh --json                  # 输出 JSON 格式
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Git 信息
GIT_HASH="$(cd "$ROOT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
GIT_BRANCH="$(cd "$ROOT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
GIT_TAG="$(cd "$ROOT_DIR" && git describe --tags --exact-match 2>/dev/null || echo "")"
GIT_DIRTY="$(cd "$ROOT_DIR" && git diff --stat 2>/dev/null | tail -1 | grep -q "0 files" && echo "false" || echo "true")"

# 构建时间
BUILD_DATE="$(date -u +%Y-%m-%d)"
BUILD_TIME="$(date -u +%H:%M:%S)"
BUILD_TIMESTAMP="$(date -u +%Y%m%d%H%M%S)"

# 默认版本号从 pubspec.yaml 读取
if [ -f "$ROOT_DIR/pubspec.yaml" ]; then
  APP_VERSION=$(grep -m1 '^version:' "$ROOT_DIR/pubspec.yaml" | sed 's/version: *//' | tr -d ' ')
else
  APP_VERSION="0.0.0+1"
fi

# 构建类型（可由调用方覆盖）
BUILD_TYPE="${BUILD_TYPE:-release}"

# 完整版本标识
FULL_VERSION="${APP_VERSION}+${GIT_HASH}"

# Git 描述（如果有 tag）
if [ -n "$GIT_TAG" ]; then
  FULL_VERSION="${GIT_TAG}"
fi

# 输出函数
output_json() {
  cat << EOF
{
  "appVersion": "$APP_VERSION",
  "gitHash": "$GIT_HASH",
  "gitBranch": "$GIT_BRANCH",
  "gitTag": "$GIT_TAG",
  "gitDirty": $GIT_DIRTY,
  "buildDate": "$BUILD_DATE",
  "buildTime": "$BUILD_TIME",
  "buildTimestamp": "$BUILD_TIMESTAMP",
  "buildType": "$BUILD_TYPE",
  "fullVersion": "$FULL_VERSION"
}
EOF
}

output_shell() {
  echo "APP_VERSION=$APP_VERSION"
  echo "GIT_HASH=$GIT_HASH"
  echo "GIT_BRANCH=$GIT_BRANCH"
  echo "GIT_TAG=$GIT_TAG"
  echo "GIT_DIRTY=$GIT_DIRTY"
  echo "BUILD_DATE=$BUILD_DATE"
  echo "BUILD_TIME=$BUILD_TIME"
  echo "BUILD_TIMESTAMP=$BUILD_TIMESTAMP"
  echo "BUILD_TYPE=$BUILD_TYPE"
  echo "FULL_VERSION=$FULL_VERSION"
}

# 支持参数
if [ "${1:-}" = "--json" ] || [ "${1:-}" = "-j" ]; then
  output_json
elif [ "${1:-}" = "--env" ]; then
  output_shell
else
  # 默认输出格式（可读性较好）
  output_shell
fi

# 支持以环境变量形式导出供调用方使用
export APP_VERSION GIT_HASH GIT_BRANCH GIT_TAG GIT_DIRTY
export BUILD_DATE BUILD_TIME BUILD_TIMESTAMP BUILD_TYPE FULL_VERSION
