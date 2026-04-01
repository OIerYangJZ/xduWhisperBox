#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "[install] run as root"
  exit 1
fi

ARCHIVE_PATH="${1:-}"
if [[ -z "$ARCHIVE_PATH" || ! -f "$ARCHIVE_PATH" ]]; then
  echo "[install] usage: sudo bash scripts/install_tencent_host.sh /tmp/xdu-whisperbox-release.tar.gz"
  exit 1
fi

APP_DIR="${APP_DIR:-/opt/xdu-whisperbox}"
APP_USER="${APP_USER:-xdu}"
ENV_FILE="${ENV_FILE:-/etc/xdu-whisperbox.env}"
RELEASES_DIR="$APP_DIR/releases"
SHARED_DIR="$APP_DIR/shared"
CURRENT_LINK="$APP_DIR/current"
RELEASE_ID="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_ID"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl nginx openssl python3 python3-pil python3-requests python3-venv

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER"
fi

mkdir -p "$RELEASE_DIR"
mkdir -p "$SHARED_DIR/backend/data"
mkdir -p "$SHARED_DIR/backend/storage/objects"

tar -xzf "$ARCHIVE_PATH" -C "$RELEASE_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$RELEASE_DIR/deploy/tencent/backend.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "[install] created $ENV_FILE"
  echo "[install] update admin password and SMTP settings after deployment"
fi

ensure_env_value() {
  local key="$1"
  local value="$2"
  if ! grep -q "^${key}=" "$ENV_FILE"; then
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

ensure_env_value "BACKEND_ENV" "production"
ensure_env_value "BACKEND_DB_FILE" "$SHARED_DIR/backend/data/treehole.db"
ensure_env_value "BACKEND_STORAGE_DIR" "$SHARED_DIR/backend/storage/objects"
ensure_env_value "BACKEND_XIDIAN_PUBLIC_ORIGIN" ""

install -m 0644 "$RELEASE_DIR/deploy/tencent/xdu-whisperbox.service" /etc/systemd/system/xdu-whisperbox.service
install -m 0644 "$RELEASE_DIR/deploy/tencent/nginx-xdu-whisperbox.conf" /etc/nginx/sites-available/xdu-whisperbox.conf

ln -sfn /etc/nginx/sites-available/xdu-whisperbox.conf /etc/nginx/sites-enabled/xdu-whisperbox.conf
rm -f /etc/nginx/sites-enabled/default

ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
chmod 600 "$ENV_FILE"

nginx -t
systemctl daemon-reload
systemctl enable xdu-whisperbox
systemctl restart xdu-whisperbox
systemctl enable nginx
systemctl restart nginx

if ! grep -q '^BACKEND_XIDIAN_PUBLIC_ORIGIN=https://' "$ENV_FILE"; then
  echo "[install] WARNING: BACKEND_XIDIAN_PUBLIC_ORIGIN is empty or not HTTPS"
  echo "[install] WARNING: IDS browser/mobile login will fail with '应用未注册' until you set the IDS-registered HTTPS origin"
fi

for _ in $(seq 1 15); do
  if curl -fsS http://127.0.0.1:8080/api/channels >/dev/null; then
    echo "[install] ok"
    echo "[install] app dir: $APP_DIR"
    echo "[install] env file: $ENV_FILE"
    exit 0
  fi
  sleep 1
done

echo "[install] backend health check failed" >&2
exit 1
