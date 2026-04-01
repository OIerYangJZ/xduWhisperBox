#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-}"
DEPLOY_PORT="${DEPLOY_PORT:-22}"
DEPLOY_SSH_KEY="${DEPLOY_SSH_KEY:-}"
REMOTE_TMP="${REMOTE_TMP:-/tmp/xdu-whisperbox-deploy}"

if [[ -z "$DEPLOY_HOST" || -z "$DEPLOY_USER" ]]; then
  echo "[deploy] set DEPLOY_HOST and DEPLOY_USER"
  echo "[deploy] optional: DEPLOY_PORT DEPLOY_SSH_KEY"
  exit 1
fi

SSH_OPTS=(-p "$DEPLOY_PORT" -o StrictHostKeyChecking=accept-new)
SCP_OPTS=(-P "$DEPLOY_PORT" -o StrictHostKeyChecking=accept-new)
if [[ -n "$DEPLOY_SSH_KEY" ]]; then
  SSH_OPTS+=(-i "$DEPLOY_SSH_KEY")
  SCP_OPTS+=(-i "$DEPLOY_SSH_KEY")
fi

ARCHIVE_PATH="$(bash "$ROOT_DIR/scripts/package_release.sh" | tail -n 1)"
ARCHIVE_NAME="$(basename "$ARCHIVE_PATH")"
REMOTE_TARGET="$DEPLOY_USER@$DEPLOY_HOST"

ssh "${SSH_OPTS[@]}" "$REMOTE_TARGET" "mkdir -p '$REMOTE_TMP'"
scp "${SCP_OPTS[@]}" "$ARCHIVE_PATH" "$ROOT_DIR/scripts/install_tencent_host.sh" "$REMOTE_TARGET:$REMOTE_TMP/"

if [[ "$DEPLOY_USER" == "root" ]]; then
  REMOTE_INSTALL_PREFIX="bash"
else
  REMOTE_INSTALL_PREFIX="sudo bash"
fi

ssh "${SSH_OPTS[@]}" "$REMOTE_TARGET" "$REMOTE_INSTALL_PREFIX '$REMOTE_TMP/install_tencent_host.sh' '$REMOTE_TMP/$ARCHIVE_NAME'"

echo "[deploy] done: http://$DEPLOY_HOST/"
echo "[deploy] update secrets in /etc/xdu-whisperbox.env if needed"
