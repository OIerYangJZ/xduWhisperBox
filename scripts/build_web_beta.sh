#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "[build] Flutter not found: $FLUTTER_BIN"
  echo "[build] Set FLUTTER_BIN to absolute path, e.g. FLUTTER_BIN=/Users/yangjinsey/flutter/bin/flutter"
  exit 1
fi

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build web --release --dart-define=API_BASE_URL=/api

echo "[build] done: $ROOT_DIR/build/web"
