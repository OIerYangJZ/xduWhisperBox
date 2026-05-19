#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$ROOT_DIR/scripts/start_backend.sh"
status=$?

if [[ $status -ne 0 ]]; then
  echo
  echo "[backend] startup failed with exit code $status"
  if [[ -t 0 ]]; then
    read -r -p "Press Enter to close this window..." _
  fi
fi

exit "$status"
