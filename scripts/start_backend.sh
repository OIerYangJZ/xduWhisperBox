#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

load_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  echo "[backend] loading env: ${file#$ROOT_DIR/}"
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      if [[ "${value:0:1}" == "\"" && "${value: -1}" == "\"" ]]; then
        value="${value:1:${#value}-2}"
      elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
        value="${value:1:${#value}-2}"
      fi
      export "$key=$value"
    else
      echo "[backend] skip invalid env line in ${file#$ROOT_DIR/}: $line"
    fi
  done < "$file"
}

load_env_file "$ROOT_DIR/.env"
load_env_file "$ROOT_DIR/.env.local"
load_env_file "$ROOT_DIR/backend/.env"
load_env_file "$ROOT_DIR/backend/.env.local"

export BACKEND_HOST="${BACKEND_HOST:-0.0.0.0}"
export BACKEND_PORT="${BACKEND_PORT:-8080}"
export BACKEND_DB_FILE="${BACKEND_DB_FILE:-$ROOT_DIR/backend/data/treehole.db}"
export BACKEND_STORAGE_DIR="${BACKEND_STORAGE_DIR:-$ROOT_DIR/backend/storage/objects}"
export BACKEND_OBJECT_STORAGE_BACKEND="${BACKEND_OBJECT_STORAGE_BACKEND:-local}"
export BACKEND_WEB_ROOT="${BACKEND_WEB_ROOT:-$ROOT_DIR/build/web}"
export PYTHONUNBUFFERED="${PYTHONUNBUFFERED:-1}"

PYTHON_BIN="${PYTHON_BIN:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  if [[ -x "$ROOT_DIR/.venv/bin/python3" ]]; then
    PYTHON_BIN="$ROOT_DIR/.venv/bin/python3"
  elif [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
    PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
  else
    PYTHON_BIN="python3"
  fi
fi

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1 && [[ ! -x "$PYTHON_BIN" ]]; then
  echo "[backend] Python not found: $PYTHON_BIN"
  echo "[backend] Install Python 3, or set PYTHON_BIN=/path/to/python3 before starting."
  exit 1
fi

mkdir -p "$(dirname "$BACKEND_DB_FILE")" "$BACKEND_STORAGE_DIR"

echo "[backend] project: $ROOT_DIR"
echo "[backend] listen : http://$BACKEND_HOST:$BACKEND_PORT/api"
echo "[backend] python : $PYTHON_BIN"
echo "[backend] db     : $BACKEND_DB_FILE"
echo "[backend] storage: $BACKEND_STORAGE_DIR"
echo "[backend] press Ctrl-C to stop"

exec "$PYTHON_BIN" "$ROOT_DIR/backend/server.py"
