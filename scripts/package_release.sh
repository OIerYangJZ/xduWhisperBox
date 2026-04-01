#!/usr/bin/env bash
# scripts/package_release.sh
# 打包发布脚本：将前端、后端、部署配置打包成可分发的归档文件。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT_DIR="$ROOT_DIR/scripts"

# 加载版本信息
if [ -f "$SCRIPT_DIR/version.sh" ]; then
  source "$SCRIPT_DIR/version.sh"
fi

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
ARCHIVE_VERSION="${FULL_VERSION:-$(date +%Y%m%d%H%M%S)}"
ARCHIVE_PATH="$DIST_DIR/xdu-whisperbox-${ARCHIVE_VERSION}.tar.gz"

# 验证构建产物存在
if [[ ! -f "$ROOT_DIR/build/web/index.html" || "${FORCE_BUILD:-0}" == "1" ]]; then
  echo "[package] Building web first..."
  FLUTTER_BIN="$FLUTTER_BIN" bash "$SCRIPT_DIR/build_web_production.sh"
fi

# 确保输出目录存在
mkdir -p "$DIST_DIR"

export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

echo "[package] === 西电树洞打包发布 ==="
echo "[package] Version  : $ARCHIVE_VERSION"
echo "[package] GIT Hash: ${GIT_HASH:-unknown}"
echo "[package] Output  : $ARCHIVE_PATH"

# 写入版本信息到归档中
mkdir -p "$ROOT_DIR/.release-meta"
cat > "$ROOT_DIR/.release-meta/version.json" << EOF
{
  "version": "${ARCHIVE_VERSION}",
  "gitHash": "${GIT_HASH:-unknown}",
  "buildDate": "${BUILD_DATE:-$(date -u +%Y-%m-%d)}",
  "buildTime": "${BUILD_TIME:-$(date -u +%H:%M:%S)}",
  "packageTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# 创建归档
tar \
  --exclude='backend/__pycache__' \
  --exclude='backend/data' \
  --exclude='backend/storage' \
  --exclude='.release-meta' \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='.dart_tool' \
  --exclude='.flutter-plugins' \
  --exclude='.flutter-plugins-dependencies' \
  -czf "$ARCHIVE_PATH" \
  .release-meta/version.json \
  backend \
  build/web \
  deploy \
  scripts \
  README.md \
  pubspec.yaml

# 清理临时文件
rm -rf "$ROOT_DIR/.release-meta"

# 输出文件大小
FILE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
echo "[package] Archive size: $FILE_SIZE"
echo "[package] Done: $ARCHIVE_PATH"

# 输出归档路径
echo "$ARCHIVE_PATH"
