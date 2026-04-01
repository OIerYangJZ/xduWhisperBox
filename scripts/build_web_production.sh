#!/usr/bin/env bash
# scripts/build_web_production.sh
# 生产构建脚本：生成版本标识并注入到 Flutter Web 构建产物中。
#
# 使用方式：
#   ./build_web_production.sh              # 默认构建
#   FLUTTER_BIN=/path/to/flutter ./build_web_production.sh  # 指定 Flutter 路径
#   BUILD_TYPE=beta ./build_web_production.sh              # beta 构建
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# 加载版本信息
source "$SCRIPT_DIR/version.sh"

# 构建类型
BUILD_TYPE="${BUILD_TYPE:-release}"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "[build] Flutter not found: $FLUTTER_BIN"
  echo "[build] Set FLUTTER_BIN to absolute path, e.g. FLUTTER_BIN=/Users/yangjinsey/flutter/bin/flutter"
  exit 1
fi

echo "[build] === 西电树洞生产构建 ==="
echo "[build] APP_VERSION : $APP_VERSION"
echo "[build] GIT_HASH    : $GIT_HASH"
echo "[build] GIT_BRANCH  : $GIT_BRANCH"
echo "[build] BUILD_DATE  : $BUILD_DATE"
echo "[build] BUILD_TYPE  : $BUILD_TYPE"
echo "[build] FULL_VERSION: $FULL_VERSION"
echo "[build] DIRTY       : $GIT_DIRTY"

# 清理旧构建（可选）
if [ "${CLEAN_BUILD:-0}" = "1" ]; then
  echo "[build] Cleaning old build artifacts..."
  rm -rf "$ROOT_DIR/build/web"
fi

# 写入版本信息文件，供前端和部署流程读取
mkdir -p "$ROOT_DIR/build/web"
cat > "$ROOT_DIR/build/web/.version.json" << EOF
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
echo "[build] Version info written to build/web/.version.json"

# 执行 Flutter Web 构建，注入版本标识
echo "[build] Running flutter pub get..."
"$FLUTTER_BIN" pub get

echo "[build] Running flutter build web..."
"$FLUTTER_BIN" build web --release \
  --dart-define=API_BASE_URL=/api \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --dart-define=FLUTTER_WEB_USE_SKWASM=true \
  --dart-define=APP_VERSION="$FULL_VERSION" \
  --dart-define=APP_BUILD_TYPE="$BUILD_TYPE"

# 向 index.html 注入版本号 meta tag（便于快速确认当前运行的版本）
if [ -f "$ROOT_DIR/build/web/index.html" ]; then
  python3 -c "
import sys
import os
index_path = os.path.join('$ROOT_DIR', 'build', 'web', 'index.html')
with open(index_path, 'r', encoding='utf-8') as f:
    content = f.read()

version_tag = '  <meta name=\"app-version\" content=\"$FULL_VERSION\">'
git_tag = '  <meta name=\"app-git-hash\" content=\"$GIT_HASH\">'
build_tag = '  <meta name=\"app-build-date\" content=\"$BUILD_DATE\">'

if 'app-version' not in content:
    content = content.replace('<head>', '<head>\n' + version_tag + '\n' + git_tag + '\n' + build_tag, 1)
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[build] Injected version meta tags into index.html')
else:
    print('[build] Version meta tags already present')
"
fi

# 生成内容哈希用于长期缓存
if [ -f "$ROOT_DIR/build/web/flutter.js" ]; then
  echo "[build] Checking main.dart.js hash for cache busting..."
  if command -v sha256sum > /dev/null 2>&1; then
    JS_HASH=$(sha256sum "$ROOT_DIR/build/web/main.dart.js" 2>/dev/null | cut -d' ' -f1 | cut -c1-16)
    echo "[build] main.dart.js hash: $JS_HASH"
    echo "$JS_HASH" > "$ROOT_DIR/build/web/.main_hash"
  fi
fi

echo "[build] === 构建完成 ==="
echo "[build] 输出目录: $ROOT_DIR/build/web"
echo "[build] 完整版本: $FULL_VERSION"
echo "[build] Git 哈希: $GIT_HASH"
if [ "$GIT_DIRTY" = "true" ]; then
  echo "[build] 警告: 构建包含未提交的更改"
fi
