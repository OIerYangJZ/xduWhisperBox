#!/usr/bin/env python3
from __future__ import annotations

import base64
import csv
import email.utils
import io
import json
import math
import mimetypes
import os
import random
import re
import secrets
import hashlib
import hmac
import smtplib
import subprocess
import threading
import time
from email.message import EmailMessage
from collections import deque
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse

from object_storage import build_object_storage_from_env
from sql_repository import SqliteTreeholeRepository

ROOT_DIR = Path(__file__).resolve().parent
DATA_DIR = ROOT_DIR / "data"
LEGACY_DB_FILE = DATA_DIR / "db.json"
SQL_DB_FILE = Path(os.environ.get("BACKEND_DB_FILE", str(DATA_DIR / "treehole.db")))
OBJECT_STORAGE_DIR = Path(os.environ.get("BACKEND_STORAGE_DIR", str(ROOT_DIR / "storage" / "objects")))
WEB_ROOT_DIR = Path(os.environ.get("BACKEND_WEB_ROOT", str(ROOT_DIR.parent / "build" / "web"))).resolve()
DB_LOCK = threading.Lock()

REPOSITORY = SqliteTreeholeRepository(SQL_DB_FILE)
OBJECT_STORAGE = build_object_storage_from_env(
    local_root_dir=OBJECT_STORAGE_DIR,
    local_public_prefix="/api/storage",
)

_BACKEND_VERSION = "0.2"


def _get_version_info() -> dict[str, Any]:
    git_hash = "unknown"
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(ROOT_DIR),
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            git_hash = result.stdout.strip()
    except Exception:
        pass
    return {
        "version": f"XduTreeholeBackend/{_BACKEND_VERSION}",
        "backendVersion": _BACKEND_VERSION,
        "gitHash": git_hash,
        "buildDate": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    lowered = raw.strip().lower()
    if lowered in {"1", "true", "yes", "on"}:
        return True
    if lowered in {"0", "false", "no", "off"}:
        return False
    return default


def env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return int(raw.strip())
    except (TypeError, ValueError):
        return default

DEFAULT_CHANNELS = [
    "综合",
    "找对象",
    "找搭子",
    "交友扩列",
    "吐槽日常",
    "八卦吃瓜",
    "求助问答",
    "失物招领",
    "二手交易",
    "学习交流",
    "活动拼车",
    "其他",
]

DEFAULT_TAGS = [
    "学习",
    "北校区",
    "南校区",
    "运动",
    "周末",
    "食堂",
    "日常",
    "数码",
    "毕业季",
]

DEFAULT_SETTINGS = {
    "postRateLimit": 5,
    "commentRateLimit": 20,
    "messageRateLimit": 30,
    "uploadRateLimit": 30,
    "imageMaxMB": 5,
    "reportRateLimit": 10,
    "dmRequestRateLimit": 20,
}

DEFAULT_SENSITIVE_WORDS = ["引流", "广告", "辱骂", "诈骗"]
DEMO_USER_ID = "u1"
DEMO_USER_EMAIL = "demo@stu.xidian.edu.cn"
DEMO_USER_PASSWORD = "123456"

PASSWORD_HASH_SCHEME = "pbkdf2_sha256"
PASSWORD_HASH_ITERATIONS = 240000
PASSWORD_SALT_BYTES = 16

ADMIN_USERNAME_SETTING_KEY = "adminUsername"
ADMIN_PASSWORD_HASH_SETTING_KEY = "adminPasswordHash"
DEFAULT_ADMIN_USERNAME = os.environ.get("BACKEND_ADMIN_USERNAME", "admin")
DEFAULT_ADMIN_PASSWORD = os.environ.get("BACKEND_ADMIN_PASSWORD", "admin123456")
ADMIN_ROLE_PRIMARY = "primary"
ADMIN_ROLE_SECONDARY = "secondary"
USER_LEVEL_ONE = 1
USER_LEVEL_TWO = 2
PIN_DURATION_OPTIONS: dict[int, str] = {
    30: "30 分钟",
    60: "1 小时",
    120: "2 小时",
    180: "3 小时",
    1440: "1 天",
    4320: "3 天",
}
ADMIN_SESSIONS: dict[str, str] = {}
ADMIN_SESSION_LOCK = threading.Lock()

SMTP_HOST = os.environ.get("BACKEND_SMTP_HOST", "").strip()
SMTP_PORT = env_int("BACKEND_SMTP_PORT", 465)
SMTP_USERNAME = os.environ.get("BACKEND_SMTP_USERNAME", "").strip()
SMTP_PASSWORD = os.environ.get("BACKEND_SMTP_PASSWORD", "").strip()
SMTP_FROM_EMAIL = os.environ.get("BACKEND_SMTP_FROM_EMAIL", SMTP_USERNAME).strip()
SMTP_FROM_NAME = os.environ.get("BACKEND_SMTP_FROM_NAME", "西电树洞").strip() or "西电树洞"
SMTP_USE_SSL = env_bool("BACKEND_SMTP_USE_SSL", True)
SMTP_USE_STARTTLS = env_bool("BACKEND_SMTP_USE_STARTTLS", False)
ALLOW_DEBUG_VERIFY_CODE = env_bool("BACKEND_ALLOW_DEBUG_VERIFY_CODE", False)
INCLUDE_DEBUG_CODE_IN_RESPONSE = env_bool("BACKEND_INCLUDE_DEBUG_CODE", False)
PASSWORD_RESET_CODE_PREFIX = "reset::"

RATE_LIMIT_WINDOWS_SECONDS = {
    "post": 3600,
    "comment": 3600,
    "message": 3600,
    "report": 3600,
    "dm_request": 3600,
    "upload": 3600,
}
RATE_LIMIT_EVENT_MAX = 300
RATE_LIMIT_EVENTS: dict[tuple[str, str], deque[float]] = {}
RATE_LIMIT_LOCK = threading.Lock()

IP_RATE_LIMIT_EVENTS: dict[str, dict[str, deque[float]]] = {}
IP_RATE_LIMIT_LOCK = threading.Lock()

IP_RATE_LIMITS = {
    "post": {"limit": 20, "window": 3600},
    "comment": {"limit": 40, "window": 3600},
    "message": {"limit": 60, "window": 3600},
    "upload": {"limit": 30, "window": 3600},
}

SPAM_REPEAT_REGEX = re.compile(r"(.)\1{8,}", re.DOTALL)

SEED_POSTS = [
    {
        "title": "求助：图书馆哪里插座最多？",
        "content": "这周赶大作业，想找一个相对安静而且插座多的位置，北校区优先。",
        "channel": "求助问答",
        "tags": ["学习", "北校区"],
        "hasImage": False,
        "status": "ongoing",
        "allowComment": True,
        "allowDm": True,
        "authorAlias": "洞主-青橙",
        "authorId": "seed-user-1",
    },
    {
        "title": "找周末羽毛球搭子",
        "content": "周六下午操场旁边羽毛球馆，水平一般，主打一起运动。",
        "channel": "找搭子",
        "tags": ["运动", "周末"],
        "hasImage": True,
        "status": "ongoing",
        "allowComment": True,
        "allowDm": True,
        "authorAlias": "洞主-极光",
        "authorId": "seed-user-1",
    },
    {
        "title": "二手显示器出一个 24 寸",
        "content": "毕业清东西，成色还不错，支持当面看货。",
        "channel": "二手交易",
        "tags": ["数码", "毕业季"],
        "hasImage": True,
        "status": "ongoing",
        "allowComment": True,
        "allowDm": True,
        "authorAlias": "洞主-小行星",
        "authorId": "seed-user-2",
    },
    {
        "title": "吐槽：食堂晚高峰排队太久",
        "content": "今天排了 25 分钟，想知道有没有错峰吃饭攻略。",
        "channel": "吐槽日常",
        "tags": ["食堂", "日常"],
        "hasImage": False,
        "status": "resolved",
        "allowComment": True,
        "allowDm": False,
        "authorAlias": "洞主-银杏",
        "authorId": "seed-user-2",
    },
]


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def now_iso() -> str:
    return now_utc().isoformat()


def date_to_timestamp(date_str: str) -> float:
    try:
        return datetime.fromisoformat(date_str.replace("Z", "+00:00")).timestamp()
    except Exception:
        return 0.0


def parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def is_today_iso(value: str | None) -> bool:
    dt = parse_iso(value)
    if dt is None:
        return False
    return dt.astimezone(timezone.utc).date() == now_utc().date()


CHINA_TZ = timezone(timedelta(hours=8))


def is_campus_email(email: str) -> bool:
    lower = email.lower().strip()
    return lower.endswith("@stu.xidian.edu.cn") or lower.endswith("@xidian.edu.cn")


def random_code() -> str:
    return "".join(random.choice("0123456789") for _ in range(6))


def parse_bool(value: str | None) -> bool | None:
    if value is None:
        return None
    lowered = value.strip().lower()
    if lowered in {"1", "true", "yes"}:
        return True
    if lowered in {"0", "false", "no"}:
        return False
    return None


def parse_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(x).strip() for x in value if str(x).strip()]
    if isinstance(value, str):
        return [x.strip() for x in value.split(",") if x.strip()]
    return []


def is_valid_student_id(student_id: str) -> bool:
    return bool(re.fullmatch(r"[0-9A-Za-z]{6,20}", student_id.strip()))


def student_id_from_email(email: str) -> str:
    local = email.strip().split("@", 1)[0]
    return local.strip()


def normalize_avatar_url(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    lowered = text.lower()
    if lowered.startswith("/api/storage/"):
        return text
    if lowered.startswith("http://") or lowered.startswith("https://"):
        return text
    return ""


def extract_local_object_key_from_url(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    marker = "/api/storage/"
    idx = text.find(marker)
    if idx < 0:
        return ""
    key = text[idx + len(marker) :].strip().lstrip("/")
    if not key or ".." in key:
        return ""
    return key


def sanitize_alias(value: str, *, fallback: str = "匿名同学") -> str:
    text = " ".join(value.strip().split())
    if not text:
        return fallback
    if len(text) > 24:
        return text[:24]
    return text


def password_reset_code_key(email: str) -> str:
    return f"{PASSWORD_RESET_CODE_PREFIX}{email.strip().lower()}"


def smtp_configured() -> bool:
    return bool(SMTP_HOST and SMTP_PORT > 0 and SMTP_FROM_EMAIL)


def verify_code_debug_enabled() -> bool:
    return ALLOW_DEBUG_VERIFY_CODE or not smtp_configured()


def is_email_not_found_error(error: Exception) -> bool:
    if isinstance(error, smtplib.SMTPRecipientsRefused):
        return True
    if isinstance(error, smtplib.SMTPResponseException):
        code = int(getattr(error, "smtp_code", 0) or 0)
        raw = getattr(error, "smtp_error", b"")
        if isinstance(raw, bytes):
            msg = raw.decode("utf-8", errors="ignore").lower()
        else:
            msg = str(raw).lower()
        if code in {550, 551, 553, 554}:
            markers = (
                "user unknown",
                "unknown user",
                "no such user",
                "recipient address rejected",
                "mailbox unavailable",
                "not found",
                "invalid recipient",
            )
            if any(marker in msg for marker in markers):
                return True
    text = str(error).lower()
    return "user unknown" in text or "recipient address rejected" in text or "no such user" in text


def verification_send_error_message(error: Exception) -> str:
    if is_email_not_found_error(error):
        return "该校园邮箱不存在或不可达，请检查邮箱是否真实有效"
    return "验证码邮件发送失败，请稍后重试"


def send_verification_email(*, to_email: str, code: str, expires_in_minutes: int = 10) -> None:
    if not smtp_configured():
        raise RuntimeError("邮件服务未配置，请设置 BACKEND_SMTP_* 环境变量")

    msg = EmailMessage()
    msg["Subject"] = "西电树洞邮箱验证码"
    msg["From"] = email.utils.formataddr((SMTP_FROM_NAME, SMTP_FROM_EMAIL))
    msg["To"] = to_email
    msg.set_content(
        (
            "你好，\n\n"
            "你的西电树洞验证码为："
            f"{code}\n"
            f"该验证码将在 {expires_in_minutes} 分钟后过期。\n\n"
            "如果这不是你的操作，请忽略本邮件。"
        )
    )

    timeout_seconds = 10
    if SMTP_USE_SSL:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=timeout_seconds) as server:
            if SMTP_USERNAME:
                server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        return

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=timeout_seconds) as server:
        server.ehlo()
        if SMTP_USE_STARTTLS:
            server.starttls()
            server.ehlo()
        if SMTP_USERNAME:
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
        server.send_message(msg)


def send_password_reset_email(*, to_email: str, code: str, expires_in_minutes: int = 10) -> None:
    if not smtp_configured():
        raise RuntimeError("邮件服务未配置，请设置 BACKEND_SMTP_* 环境变量")

    msg = EmailMessage()
    msg["Subject"] = "西电树洞密码重置验证码"
    msg["From"] = email.utils.formataddr((SMTP_FROM_NAME, SMTP_FROM_EMAIL))
    msg["To"] = to_email
    msg.set_content(
        (
            "你好，\n\n"
            "你正在进行西电树洞密码重置，验证码为："
            f"{code}\n"
            f"该验证码将在 {expires_in_minutes} 分钟后过期。\n\n"
            "如果这不是你的操作，请忽略本邮件。"
        )
    )

    timeout_seconds = 10
    if SMTP_USE_SSL:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=timeout_seconds) as server:
            if SMTP_USERNAME:
                server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        return

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=timeout_seconds) as server:
        server.ehlo()
        if SMTP_USE_STARTTLS:
            server.starttls()
            server.ehlo()
        if SMTP_USERNAME:
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
        server.send_message(msg)


def decode_base64_payload(value: str) -> bytes:
    text = value.strip()
    if "," in text and "base64" in text[:64]:
        text = text.split(",", 1)[1]
    missing_padding = len(text) % 4
    if missing_padding:
        text += "=" * (4 - missing_padding)
    return base64.b64decode(text, validate=False)


def detect_image_type(data: bytes) -> str | None:
    if len(data) < 12:
        return None
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"GIF87a") or data.startswith(b"GIF89a"):
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def calc_sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def is_password_hashed(value: str | None) -> bool:
    if not value:
        return False
    parts = value.split("$")
    return len(parts) == 4 and parts[0] == PASSWORD_HASH_SCHEME


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(PASSWORD_SALT_BYTES)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        PASSWORD_HASH_ITERATIONS,
    )
    return (
        f"{PASSWORD_HASH_SCHEME}"
        f"${PASSWORD_HASH_ITERATIONS}"
        f"${salt.hex()}"
        f"${digest.hex()}"
    )


def verify_password(stored: str | None, candidate: str) -> bool:
    if not stored:
        return False

    # Legacy plain-text support during migration.
    if not is_password_hashed(stored):
        return hmac.compare_digest(stored, candidate)

    parts = stored.split("$")
    if len(parts) != 4 or parts[0] != PASSWORD_HASH_SCHEME:
        return False

    try:
        iterations = int(parts[1])
        salt = bytes.fromhex(parts[2])
        expected = bytes.fromhex(parts[3])
    except (TypeError, ValueError):
        return False

    actual = hashlib.pbkdf2_hmac(
        "sha256",
        candidate.encode("utf-8"),
        salt,
        iterations,
    )
    return hmac.compare_digest(actual, expected)


def get_setting_int(db: dict[str, Any], key: str, default: int, *, minimum: int = 1) -> int:
    settings = db.get("settings", {})
    if isinstance(settings, dict):
        try:
            return max(minimum, int(settings.get(key, default)))
        except (TypeError, ValueError):
            return max(minimum, default)
    return max(minimum, default)


def ensure_admin_auth_settings(db: dict[str, Any]) -> bool:
    settings = db.get("settings")
    if not isinstance(settings, dict):
        settings = {}
        db["settings"] = settings

    changed = False
    username = str(settings.get(ADMIN_USERNAME_SETTING_KEY, "")).strip()
    if not username:
        settings[ADMIN_USERNAME_SETTING_KEY] = DEFAULT_ADMIN_USERNAME
        changed = True

    stored_password = str(settings.get(ADMIN_PASSWORD_HASH_SETTING_KEY, "")).strip()
    if not stored_password:
        settings[ADMIN_PASSWORD_HASH_SETTING_KEY] = hash_password(DEFAULT_ADMIN_PASSWORD)
        changed = True
    elif not is_password_hashed(stored_password):
        settings[ADMIN_PASSWORD_HASH_SETTING_KEY] = hash_password(stored_password)
        changed = True

    return changed


def get_admin_auth_credentials(db: dict[str, Any]) -> tuple[str, str]:
    ensure_admin_auth_settings(db)
    settings = db.get("settings", {})
    username = str(settings.get(ADMIN_USERNAME_SETTING_KEY, DEFAULT_ADMIN_USERNAME)).strip() or DEFAULT_ADMIN_USERNAME
    password_hash = str(settings.get(ADMIN_PASSWORD_HASH_SETTING_KEY, "")).strip()
    if not password_hash:
        password_hash = hash_password(DEFAULT_ADMIN_PASSWORD)
        settings[ADMIN_PASSWORD_HASH_SETTING_KEY] = password_hash
    return username, password_hash


def normalize_admin_username(value: str) -> str:
    return value.strip().lower()


def is_valid_admin_username(value: str) -> bool:
    return bool(re.fullmatch(r"[A-Za-z0-9_.-]{3,32}", value.strip()))


def normalize_admin_role(value: Any) -> str:
    role = str(value).strip().lower()
    if role == ADMIN_ROLE_PRIMARY:
        return ADMIN_ROLE_PRIMARY
    return ADMIN_ROLE_SECONDARY


def admin_role_label(role: str) -> str:
    return "一级管理员" if normalize_admin_role(role) == ADMIN_ROLE_PRIMARY else "二级管理员"


def normalize_user_level(value: Any) -> int:
    try:
        level = int(value)
    except (TypeError, ValueError):
        return USER_LEVEL_TWO
    return USER_LEVEL_ONE if level == USER_LEVEL_ONE else USER_LEVEL_TWO


def user_level_label(level: Any) -> str:
    return "一级用户" if normalize_user_level(level) == USER_LEVEL_ONE else "二级用户"


def parse_pin_duration_minutes(value: Any) -> int | None:
    try:
        duration = int(value)
    except (TypeError, ValueError):
        return None
    return duration if duration in PIN_DURATION_OPTIONS else None


def pin_duration_label(duration_minutes: Any) -> str:
    try:
        duration = int(duration_minutes)
    except (TypeError, ValueError):
        return ""
    return PIN_DURATION_OPTIONS.get(duration, "")


def build_admin_account(
    *,
    admin_id: str,
    username: str,
    password_hash: str,
    role: str,
    active: bool = True,
    created_at: str,
    updated_at: str,
    created_by: str = "",
) -> dict[str, Any]:
    return {
        "id": admin_id,
        "username": normalize_admin_username(username) or normalize_admin_username(DEFAULT_ADMIN_USERNAME),
        "passwordHash": password_hash,
        "role": normalize_admin_role(role),
        "active": bool(active),
        "createdAt": created_at,
        "updatedAt": updated_at,
        "createdBy": created_by.strip(),
    }


def find_admin_account_by_username(
    db: dict[str, Any],
    username: str,
    *,
    include_inactive: bool = False,
) -> dict[str, Any] | None:
    target = normalize_admin_username(username)
    if not target:
        return None
    for account in db.get("adminAccounts", []):
        if normalize_admin_username(str(account.get("username", ""))) != target:
            continue
        if not include_inactive and not bool(account.get("active", True)):
            continue
        return account
    return None


def find_admin_account_by_id(
    db: dict[str, Any],
    admin_id: str,
    *,
    include_inactive: bool = False,
) -> dict[str, Any] | None:
    target = str(admin_id).strip()
    if not target:
        return None
    for account in db.get("adminAccounts", []):
        if str(account.get("id", "")).strip() != target:
            continue
        if not include_inactive and not bool(account.get("active", True)):
            continue
        return account
    return None


def clear_admin_sessions_for_account(admin_id: str) -> None:
    target = str(admin_id).strip()
    if not target:
        return
    with ADMIN_SESSION_LOCK:
        expired_tokens = [
            token
            for token, session_admin_id in ADMIN_SESSIONS.items()
            if str(session_admin_id).strip() == target
        ]
        for token in expired_tokens:
            ADMIN_SESSIONS.pop(token, None)


def build_authenticated_admin(account: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(account.get("role"))
    return {
        "id": "",
        "adminId": str(account.get("id", "")).strip(),
        "username": normalize_admin_username(str(account.get("username", ""))),
        "role": role,
        "roleLabel": admin_role_label(role),
        "isPrimary": role == ADMIN_ROLE_PRIMARY,
        "isAdmin": True,
    }


def serialize_admin_auth_payload(admin: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(admin.get("role"))
    return {
        "username": str(admin.get("username", "")).strip(),
        "role": role,
        "roleLabel": admin_role_label(role),
        "isPrimary": role == ADMIN_ROLE_PRIMARY,
        "authenticated": True,
    }


def serialize_admin_account(account: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(account.get("role"))
    active = bool(account.get("active", True))
    return {
        "id": str(account.get("id", "")).strip(),
        "username": normalize_admin_username(str(account.get("username", ""))),
        "role": role,
        "roleLabel": admin_role_label(role),
        "active": active,
        "statusLabel": "启用中" if active else "已注销",
        "createdAt": str(account.get("createdAt", "")).strip(),
        "updatedAt": str(account.get("updatedAt", "")).strip(),
        "createdBy": str(account.get("createdBy", "")).strip(),
    }


def build_admin_account_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    rows = [
        serialize_admin_account(account)
        for account in db.get("adminAccounts", [])
        if normalize_admin_role(account.get("role")) == ADMIN_ROLE_SECONDARY
    ]
    rows.sort(
        key=lambda item: (
            0 if bool(item.get("active")) else 1,
            str(item.get("createdAt", "")),
            str(item.get("id", "")),
        ),
        reverse=False,
    )
    return rows


def ensure_admin_accounts(db: dict[str, Any]) -> bool:
    changed = False
    seq = db.get("seq")
    if not isinstance(seq, dict):
        seq = {}
        db["seq"] = seq
        changed = True
    if "adminAccount" not in seq:
        seq["adminAccount"] = 0
        changed = True
    raw_accounts = db.get("adminAccounts")
    if not isinstance(raw_accounts, list):
        raw_accounts = []
        db["adminAccounts"] = raw_accounts
        changed = True

    sanitized_accounts: list[dict[str, Any]] = []
    seen_usernames: set[str] = set()
    timestamp = now_iso()
    for row in raw_accounts:
        if not isinstance(row, dict):
            changed = True
            continue
        admin_id = str(row.get("id", "")).strip()
        username = normalize_admin_username(str(row.get("username", "")))
        password_hash = str(row.get("passwordHash", "")).strip()
        if not admin_id or not username or not password_hash:
            changed = True
            continue
        if not is_password_hashed(password_hash):
            password_hash = hash_password(password_hash)
            changed = True
        if username in seen_usernames:
            changed = True
            continue
        seen_usernames.add(username)
        role = normalize_admin_role(row.get("role"))
        active = bool(row.get("active", True))
        created_at = str(row.get("createdAt", "")).strip() or timestamp
        updated_at = str(row.get("updatedAt", "")).strip() or created_at
        created_by = str(row.get("createdBy", "")).strip()
        sanitized_accounts.append(
            build_admin_account(
                admin_id=admin_id,
                username=username,
                password_hash=password_hash,
                role=role,
                active=active,
                created_at=created_at,
                updated_at=updated_at,
                created_by=created_by,
            )
        )
        if (
            username != str(row.get("username", "")).strip()
            or password_hash != str(row.get("passwordHash", "")).strip()
            or role != str(row.get("role", "")).strip().lower()
            or created_at != str(row.get("createdAt", "")).strip()
            or updated_at != str(row.get("updatedAt", "")).strip()
            or created_by != str(row.get("createdBy", "")).strip()
            or active != bool(row.get("active", True))
        ):
            changed = True

    db["adminAccounts"] = sanitized_accounts

    legacy_username, legacy_password_hash = get_admin_auth_credentials(db)
    legacy_username = normalize_admin_username(legacy_username) or normalize_admin_username(DEFAULT_ADMIN_USERNAME)
    if not is_password_hashed(legacy_password_hash):
        legacy_password_hash = hash_password(legacy_password_hash)
        changed = True

    if not db["adminAccounts"]:
        db["adminAccounts"].append(
            build_admin_account(
                admin_id=next_id(db, "adminAccount", "adm"),
                username=legacy_username,
                password_hash=legacy_password_hash,
                role=ADMIN_ROLE_PRIMARY,
                active=True,
                created_at=timestamp,
                updated_at=timestamp,
                created_by="system",
            )
        )
        changed = True

    default_admin = find_admin_account_by_username(
        db,
        DEFAULT_ADMIN_USERNAME,
        include_inactive=True,
    )
    if default_admin is not None:
        if normalize_admin_role(default_admin.get("role")) != ADMIN_ROLE_PRIMARY:
            default_admin["role"] = ADMIN_ROLE_PRIMARY
            default_admin["updatedAt"] = timestamp
            changed = True
        if not bool(default_admin.get("active", True)):
            default_admin["active"] = True
            default_admin["updatedAt"] = timestamp
            changed = True

    if not any(
        normalize_admin_role(account.get("role")) == ADMIN_ROLE_PRIMARY
        for account in db.get("adminAccounts", [])
    ):
        first_account = db["adminAccounts"][0]
        first_account["role"] = ADMIN_ROLE_PRIMARY
        first_account["updatedAt"] = timestamp
        changed = True

    return changed


def consume_rate_limit(
    db: dict[str, Any],
    *,
    user_id: str,
    action: str,
    setting_key: str,
    default_limit: int,
) -> tuple[bool, int]:
    limit = get_setting_int(db, setting_key, default_limit, minimum=1)
    window_seconds = RATE_LIMIT_WINDOWS_SECONDS.get(action, 3600)
    now = time.time()
    key = (user_id, action)

    with RATE_LIMIT_LOCK:
        queue = RATE_LIMIT_EVENTS.setdefault(key, deque())
        while queue and now - queue[0] >= window_seconds:
            queue.popleft()

        if len(queue) >= limit:
            retry_after = max(1, int(window_seconds - (now - queue[0])))
            return False, retry_after

        queue.append(now)
        while len(queue) > RATE_LIMIT_EVENT_MAX:
            queue.popleft()
        return True, 0


def get_client_ip(handler: BaseHTTPRequestHandler) -> str:
    x_forwarded_for = handler.headers.get("X-Forwarded-For", "")
    if x_forwarded_for:
        return x_forwarded_for.split(",")[0].strip()
    x_real_ip = handler.headers.get("X-Real-IP", "")
    if x_real_ip:
        return x_real_ip.strip()
    return handler.client_address[0] or "unknown"


def check_ip_rate_limit(
    handler: BaseHTTPRequestHandler,
    action: str,
) -> tuple[bool, int]:
    ip = get_client_ip(handler)
    limits = IP_RATE_LIMITS.get(action)
    if not limits:
        return True, 0
    limit = limits["limit"]
    window_seconds = limits["window"]
    now = time.time()

    with IP_RATE_LIMIT_LOCK:
        ip_events = IP_RATE_LIMIT_EVENTS.setdefault(ip, {})
        queue = ip_events.setdefault(action, deque())
        while queue and now - queue[0] >= window_seconds:
            queue.popleft()

        if len(queue) >= limit:
            retry_after = max(1, int(window_seconds - (now - queue[0])))
            return False, retry_after

        queue.append(now)
        return True, 0


def check_duplicate_image_hash(db: dict[str, Any], image_hash: str) -> bool:
    if not image_hash:
        return False
    return any(
        upload.get("hash") == image_hash
        for upload in db.get("mediaUploads", [])
        if upload.get("hash")
    )


def send_rate_limit_error(
    handler: BaseHTTPRequestHandler,
    *,
    action_text: str,
    retry_after_seconds: int,
) -> None:
    send_json(
        handler,
        HTTPStatus.TOO_MANY_REQUESTS,
        {
            "message": f"{action_text}过于频繁，请在 {retry_after_seconds} 秒后重试",
            "data": {"retryAfterSeconds": retry_after_seconds},
        },
    )


def assess_text_risk(db: dict[str, Any], text: str) -> tuple[bool, bool, list[str]]:
    normalized = text.strip()
    if not normalized:
        return False, False, []

    reasons: list[str] = []
    high_risk = False

    hit_words = [
        str(word).strip()
        for word in db.get("sensitiveWords", [])
        if str(word).strip() and str(word).strip() in normalized
    ]
    if hit_words:
        reasons.append(f"命中敏感词: {','.join(hit_words[:3])}")

    if SPAM_REPEAT_REGEX.search(normalized):
        reasons.append("疑似重复刷屏文本")
    if len(normalized) > 5000:
        reasons.append("文本长度异常")

    risk_marked = bool(reasons)
    return risk_marked, high_risk, reasons


def read_json_body(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length_str = handler.headers.get("Content-Length", "0")
    try:
        length = int(length_str)
    except ValueError:
        length = 0
    if length <= 0:
        return {}

    raw = handler.rfile.read(length)
    if not raw:
        return {}

    try:
        data = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError:
        return {}

    if isinstance(data, dict):
        return data
    return {}


def send_json(handler: BaseHTTPRequestHandler, status: int, payload: dict[str, Any]) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
    handler.end_headers()
    handler.wfile.write(body)


def json_error(handler: BaseHTTPRequestHandler, status: int, message: str) -> None:
    send_json(handler, status, {"message": message})


def send_binary(handler: BaseHTTPRequestHandler, status: int, data: bytes, content_type: str) -> None:
    handler.send_response(status)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
    handler.end_headers()
    handler.wfile.write(data)


def send_static_file(handler: BaseHTTPRequestHandler, file_path: Path) -> None:
    try:
        data = file_path.read_bytes()
    except OSError:
        json_error(handler, HTTPStatus.NOT_FOUND, "Not Found")
        return

    content_type, _ = mimetypes.guess_type(str(file_path))
    if file_path.suffix == ".wasm":
        content_type = "application/wasm"
    if not content_type:
        content_type = "application/octet-stream"

    handler.send_response(HTTPStatus.OK)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
    # Beta deployment prefers freshness over caching to avoid stale Flutter bundles.
    handler.send_header("Cache-Control", "no-cache")
    handler.end_headers()
    handler.wfile.write(data)


def resolve_web_asset_path(path: str) -> Path | None:
    raw = unquote(path or "/")
    normalized = raw.lstrip("/")
    if not normalized:
        target = WEB_ROOT_DIR / "index.html"
    else:
        target = (WEB_ROOT_DIR / normalized).resolve()
    try:
        target.relative_to(WEB_ROOT_DIR)
    except ValueError:
        return None
    if target.is_dir():
        target = target / "index.html"
    return target


def should_fallback_to_spa(path: str) -> bool:
    normalized = unquote(path or "/").lstrip("/")
    if not normalized:
        return True
    last = normalized.split("/")[-1]
    return "." not in last


def default_db() -> dict[str, Any]:
    created = now_iso()
    db: dict[str, Any] = {
        "seq": {
            "user": 1,
            "adminAccount": 1,
            "post": 0,
            "comment": 0,
            "report": 0,
            "cancellation": 0,
            "request": 0,
            "conversation": 0,
            "notification": 0,
            "announcement": 0,
            "appeal": 0,
            "pinRequest": 0,
            "levelRequest": 0,
            "audit": 0,
            "upload": 0,
        },
        "users": [
            {
                "id": DEMO_USER_ID,
                "email": DEMO_USER_EMAIL,
                "password": hash_password(DEMO_USER_PASSWORD),
                "alias": "洞主-雾蓝",
                "nickname": "洞主-雾蓝",
                "studentId": "2023000001",
                "avatarUrl": "",
                "userLevel": USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": True,
                "showContactable": True,
                "createdAt": created,
                "deleted": False,
                "isAdmin": False,
                "banned": False,
                "muted": False,
            },
            {
                "id": "seed-user-1",
                "email": "seed1@xidian.edu.cn",
                "password": "",
                "alias": "洞主-极光",
                "nickname": "洞主-极光",
                "studentId": "2023000002",
                "avatarUrl": "",
                "userLevel": USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": False,
                "showContactable": False,
                "createdAt": created,
                "deleted": False,
                "isAdmin": False,
                "banned": False,
                "muted": False,
            },
            {
                "id": "seed-user-2",
                "email": "seed2@xidian.edu.cn",
                "password": "",
                "alias": "洞主-银杏",
                "nickname": "洞主-银杏",
                "studentId": "2023000003",
                "avatarUrl": "",
                "userLevel": USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": False,
                "showContactable": False,
                "createdAt": created,
                "deleted": False,
                "isAdmin": False,
                "banned": False,
                "muted": False,
            },
        ],
        "sessions": {},
        "emailCodes": {},
        "channels": list(DEFAULT_CHANNELS),
        "tags": list(DEFAULT_TAGS),
        "sensitiveWords": list(DEFAULT_SENSITIVE_WORDS),
        "settings": {
            **dict(DEFAULT_SETTINGS),
            ADMIN_USERNAME_SETTING_KEY: DEFAULT_ADMIN_USERNAME,
            ADMIN_PASSWORD_HASH_SETTING_KEY: hash_password(DEFAULT_ADMIN_PASSWORD),
        },
        "adminAccounts": [
            build_admin_account(
                admin_id="adm1",
                username=DEFAULT_ADMIN_USERNAME,
                password_hash=hash_password(DEFAULT_ADMIN_PASSWORD),
                role=ADMIN_ROLE_PRIMARY,
                active=True,
                created_at=created,
                updated_at=created,
                created_by="system",
            )
        ],
        "posts": [],
        "comments": [],
        "likes": [],
        "favorites": [],
        "reports": [],
        "dmRequests": [],
        "userBlocks": [],
        "conversations": [],
        "directMessages": [],
        "systemAnnouncements": [],
        "notifications": [],
        "appeals": [],
        "postPinRequests": [],
        "userLevelRequests": [],
        "auditLogs": [],
        "accountCancellationRequests": [],
        "mediaUploads": [],
    }

    for row in SEED_POSTS:
        db["seq"]["post"] += 1
        post_id = f"p{db['seq']['post']}"
        db["posts"].append(
            {
                "id": post_id,
                "title": row["title"],
                "content": row["content"],
                "channel": row["channel"],
                "tags": row["tags"],
                "hasImage": row["hasImage"],
                "status": row["status"],
                "allowComment": row["allowComment"],
                "allowDm": row["allowDm"],
                "authorAlias": row["authorAlias"],
                "authorId": row["authorId"],
                "pinStartedAt": "",
                "pinExpiresAt": "",
                "pinDurationMinutes": 0,
                "createdAt": created,
                "updatedAt": created,
                "deleted": False,
                "reviewStatus": "approved",
                "riskMarked": False,
            }
        )

    db["favorites"].append({"userId": "u1", "postId": "p1"})
    db["favorites"].append({"userId": "u1", "postId": "p2"})

    db["dmRequests"].append(
        {
            "id": "req1",
            "toUserId": "u1",
            "fromAlias": "同学-海盐",
            "fromUserId": "seed-user-1",
            "fromAvatarUrl": "",
            "reason": "想咨询图书馆座位信息",
            "createdAt": created,
            "status": "pending",
        }
    )
    db["dmRequests"].append(
        {
            "id": "req2",
            "toUserId": "u1",
            "fromAlias": "同学-留白",
            "fromUserId": "seed-user-2",
            "fromAvatarUrl": "",
            "reason": "想问二手显示器细节",
            "createdAt": created,
            "status": "pending",
        }
    )
    db["seq"]["request"] = 2

    db["conversations"].append(
        {
            "id": "c1",
            "userId": "u1",
            "peerUserId": "seed-user-1",
            "name": "洞主-极光",
            "avatarUrl": "",
            "lastMessage": "谢谢，已经找到位置了。",
            "unreadCount": 0,
            "lastReadAt": created,
            "updatedAt": created,
            "deleted": False,
        }
    )
    db["seq"]["conversation"] = 1
    db["directMessages"].append(
        {
            "id": "m1",
            "conversationKey": "seed-user-1::u1",
            "senderUserId": "seed-user-1",
            "receiverUserId": "u1",
            "content": "谢谢，已经找到位置了。",
            "createdAt": created,
            "readAt": created,
            "deleted": False,
        }
    )
    db["seq"]["message"] = 1

    db["comments"].append(
        {
            "id": "cm1",
            "postId": "p1",
            "userId": "seed-user-2",
            "authorAlias": "匿名同学-1",
            "content": "教研楼三层东边插座比较多。",
            "createdAt": created,
            "deleted": False,
            "likeCount": 0,
            "reviewStatus": "approved",
            "riskMarked": False,
        }
    )
    db["comments"].append(
        {
            "id": "cm2",
            "postId": "p1",
            "userId": "seed-user-1",
            "authorAlias": "匿名同学-2",
            "content": "新图二层靠窗位置不错，但中午人多。",
            "createdAt": created,
            "deleted": False,
            "likeCount": 0,
            "reviewStatus": "approved",
            "riskMarked": False,
        }
    )
    db["seq"]["comment"] = 2

    db["reports"].append(
        {
            "id": "r1",
            "userId": "u1",
            "reporterAlias": "洞主-雾蓝",
            "targetType": "post",
            "targetId": "p2",
            "reason": "广告引流",
            "description": "疑似卖课引流",
            "status": "pending",
            "result": "",
            "createdAt": created,
            "handledAt": "",
            "handledBy": "",
        }
    )
    db["seq"]["report"] = 1

    return db


def ensure_db() -> None:
    SQL_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    first_boot = not SQL_DB_FILE.exists()
    REPOSITORY.initialize(default_db)

    if first_boot and LEGACY_DB_FILE.exists():
        try:
            with LEGACY_DB_FILE.open("r", encoding="utf-8") as f:
                legacy_db = json.load(f)
            if isinstance(legacy_db, dict):
                migrate_db(legacy_db)
                REPOSITORY.save_state(legacy_db)
        except Exception:
            # Keep seeded SQL database when legacy import fails.
            pass


def save_db(db: dict[str, Any]) -> None:
    SQL_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    REPOSITORY.save_state(db)


def migrate_db(db: dict[str, Any]) -> bool:
    changed = False

    if "channels" not in db:
        db["channels"] = list(DEFAULT_CHANNELS)
        changed = True
    elif not isinstance(db.get("channels"), list):
        db["channels"] = list(DEFAULT_CHANNELS)
        changed = True
    else:
        for default_channel in DEFAULT_CHANNELS:
            if default_channel not in db["channels"]:
                db["channels"].append(default_channel)
                changed = True
    if "tags" not in db:
        db["tags"] = list(DEFAULT_TAGS)
        changed = True
    if "sensitiveWords" not in db:
        db["sensitiveWords"] = list(DEFAULT_SENSITIVE_WORDS)
        changed = True
    if "settings" not in db or not isinstance(db["settings"], dict):
        db["settings"] = dict(DEFAULT_SETTINGS)
        changed = True
    for key, value in DEFAULT_SETTINGS.items():
        if key not in db["settings"]:
            db["settings"][key] = value
            changed = True
    if ensure_admin_auth_settings(db):
        changed = True
    if ensure_admin_accounts(db):
        changed = True

    if "auditLogs" not in db:
        db["auditLogs"] = []
        changed = True
    if "userFollows" not in db or not isinstance(db.get("userFollows"), list):
        db["userFollows"] = []
        changed = True
    if "appeals" not in db or not isinstance(db.get("appeals"), list):
        db["appeals"] = []
        changed = True
    if "postPinRequests" not in db or not isinstance(db.get("postPinRequests"), list):
        db["postPinRequests"] = []
        changed = True
    if "userLevelRequests" not in db or not isinstance(db.get("userLevelRequests"), list):
        db["userLevelRequests"] = []
        changed = True
    if "accountCancellationRequests" not in db or not isinstance(
        db.get("accountCancellationRequests"), list
    ):
        db["accountCancellationRequests"] = []
        changed = True
    if "mediaUploads" not in db:
        db["mediaUploads"] = []
        changed = True
    if "emailCodes" not in db or not isinstance(db.get("emailCodes"), dict):
        db["emailCodes"] = {}
        changed = True

    if "seq" not in db:
        db["seq"] = {}
        changed = True
    for key in [
        "user",
        "adminAccount",
        "post",
        "comment",
        "report",
        "cancellation",
        "request",
        "conversation",
        "message",
        "notification",
        "announcement",
        "appeal",
        "pinRequest",
        "levelRequest",
        "audit",
        "upload",
    ]:
        if key not in db["seq"]:
            db["seq"][key] = 0
            changed = True

    for user in db.get("users", []):
        if "nickname" not in user or not str(user.get("nickname", "")).strip():
            user["nickname"] = sanitize_alias(str(user.get("alias", "")), fallback="匿名同学")
            changed = True
        if "alias" not in user or not str(user.get("alias", "")).strip():
            user["alias"] = sanitize_alias(str(user.get("nickname", "")), fallback="匿名同学")
            changed = True
        if "studentId" not in user or not str(user.get("studentId", "")).strip():
            user["studentId"] = student_id_from_email(str(user.get("email", "")))
            changed = True
        if "avatarUrl" not in user:
            user["avatarUrl"] = ""
            changed = True
        else:
            normalized_avatar = normalize_avatar_url(str(user.get("avatarUrl", "")))
            if normalized_avatar != str(user.get("avatarUrl", "")):
                user["avatarUrl"] = normalized_avatar
                changed = True
        if "userLevel" not in user:
            user["userLevel"] = USER_LEVEL_TWO
            changed = True
        else:
            normalized_level = normalize_user_level(user.get("userLevel"))
            if normalized_level != user.get("userLevel"):
                user["userLevel"] = normalized_level
                changed = True
        if "isAdmin" not in user:
            user["isAdmin"] = False
            changed = True
        if "banned" not in user:
            user["banned"] = False
            changed = True
        if "muted" not in user:
            user["muted"] = False
            changed = True
        if "deleted" not in user:
            user["deleted"] = False
            changed = True
        current_password = str(user.get("password", ""))
        if current_password and not is_password_hashed(current_password):
            user["password"] = hash_password(current_password)
            changed = True

    demo_user: dict[str, Any] | None = None
    for user in db.get("users", []):
        if str(user.get("email", "")).strip().lower() == DEMO_USER_EMAIL:
            demo_user = user
            break
    if demo_user is not None:
        if demo_user.get("deleted"):
            demo_user["deleted"] = False
            changed = True
        if demo_user.get("banned"):
            demo_user["banned"] = False
            changed = True
        if demo_user.get("muted"):
            demo_user["muted"] = False
            changed = True
        if not str(demo_user.get("password", "")).strip():
            demo_user["password"] = hash_password(DEMO_USER_PASSWORD)
            changed = True

    for post in db.get("posts", []):
        if "tags" not in post or not isinstance(post.get("tags"), list):
            post["tags"] = []
            changed = True
        if "hasImage" not in post:
            post["hasImage"] = False
            changed = True
        if "reviewStatus" not in post:
            post["reviewStatus"] = "approved"
            changed = True
        if "riskMarked" not in post:
            post["riskMarked"] = False
            changed = True
        if "pinStartedAt" not in post:
            post["pinStartedAt"] = ""
            changed = True
        if "pinExpiresAt" not in post:
            post["pinExpiresAt"] = ""
            changed = True
        raw_pin_duration = post.get("pinDurationMinutes")
        normalized_pin_duration = parse_pin_duration_minutes(raw_pin_duration) or 0
        if "pinDurationMinutes" not in post or normalized_pin_duration != raw_pin_duration:
            post["pinDurationMinutes"] = normalized_pin_duration
            changed = True
        normalized_is_anonymous = is_post_anonymous(db, post)
        if post.get("isAnonymous") is not normalized_is_anonymous:
            post["isAnonymous"] = normalized_is_anonymous
            changed = True
        normalized_allow_dm = bool(post.get("allowDm", False)) and not normalized_is_anonymous
        if bool(post.get("allowDm", False)) != normalized_allow_dm:
            post["allowDm"] = normalized_allow_dm
            changed = True

    for comment in db.get("comments", []):
        if "reviewStatus" not in comment:
            comment["reviewStatus"] = "approved"
            changed = True
        if "riskMarked" not in comment:
            comment["riskMarked"] = False
            changed = True
        if "likeCount" not in comment:
            comment["likeCount"] = 0
            changed = True
        if "parentId" not in comment:
            comment["parentId"] = ""
            changed = True

    for report in db.get("reports", []):
        if "status" not in report:
            report["status"] = "pending"
            changed = True
        if "result" not in report:
            report["result"] = ""
            changed = True
        if "reporterAlias" not in report:
            uid = report.get("userId")
            alias = "匿名同学"
            for user in db.get("users", []):
                if user.get("id") == uid:
                    alias = user_nickname(user)
                    break
            report["reporterAlias"] = alias
            changed = True
        if "handledAt" not in report:
            report["handledAt"] = ""
            changed = True
        if "handledBy" not in report:
            report["handledBy"] = ""
            changed = True

    for dm_request in db.get("dmRequests", []):
        if "fromUserId" not in dm_request:
            dm_request["fromUserId"] = ""
            changed = True
        if "fromAvatarUrl" not in dm_request:
            dm_request["fromAvatarUrl"] = ""
            changed = True

    if "userBlocks" not in db or not isinstance(db.get("userBlocks"), list):
        db["userBlocks"] = []
        changed = True
    normalized_follows: list[dict[str, Any]] = []
    seen_follow_pairs: set[tuple[str, str]] = set()
    for follow in db.get("userFollows", []):
        if not isinstance(follow, dict):
            changed = True
            continue
        follower_user_id = str(follow.get("followerUserId", "")).strip()
        followee_user_id = str(follow.get("followeeUserId", "")).strip()
        if (
            not follower_user_id
            or not followee_user_id
            or follower_user_id == followee_user_id
            or find_user_by_id(db, follower_user_id) is None
            or find_user_by_id(db, followee_user_id) is None
        ):
            changed = True
            continue
        pair = (follower_user_id, followee_user_id)
        if pair in seen_follow_pairs:
            changed = True
            continue
        seen_follow_pairs.add(pair)
        normalized_follows.append(
            {
                "followerUserId": follower_user_id,
                "followeeUserId": followee_user_id,
                "createdAt": str(follow.get("createdAt", "")).strip() or now_iso(),
            }
        )
    if normalized_follows != db.get("userFollows", []):
        db["userFollows"] = normalized_follows
        changed = True

    for conversation in db.get("conversations", []):
        if "peerUserId" not in conversation:
            conversation["peerUserId"] = ""
            changed = True
        if "avatarUrl" not in conversation:
            conversation["avatarUrl"] = ""
            changed = True
        if "unreadCount" not in conversation:
            conversation["unreadCount"] = 0
            changed = True
        if "lastReadAt" not in conversation:
            conversation["lastReadAt"] = ""
            changed = True
        if "deleted" not in conversation:
            conversation["deleted"] = False
            changed = True

    if "directMessages" not in db or not isinstance(db.get("directMessages"), list):
        db["directMessages"] = []
        changed = True
    for message in db.get("directMessages", []):
        if "conversationKey" not in message:
            sender_user_id = str(message.get("senderUserId", "")).strip()
            receiver_user_id = str(message.get("receiverUserId", "")).strip()
            if sender_user_id and receiver_user_id:
                message["conversationKey"] = "::".join(sorted([sender_user_id, receiver_user_id]))
            else:
                message["conversationKey"] = ""
            changed = True
        if "deleted" not in message:
            message["deleted"] = False
            changed = True
        if "readAt" not in message:
            message["readAt"] = ""
            changed = True

    if "systemAnnouncements" not in db or not isinstance(db.get("systemAnnouncements"), list):
        db["systemAnnouncements"] = []
        changed = True
    for announcement in db.get("systemAnnouncements", []):
        if "title" not in announcement:
            announcement["title"] = ""
            changed = True
        if "content" not in announcement:
            announcement["content"] = ""
            changed = True
        if "createdAt" not in announcement:
            announcement["createdAt"] = now_iso()
            changed = True
        if "createdBy" not in announcement:
            announcement["createdBy"] = ""
            changed = True

    if "notifications" not in db or not isinstance(db.get("notifications"), list):
        db["notifications"] = []
        changed = True
    for notification in db.get("notifications", []):
        if "type" not in notification:
            notification["type"] = "system"
            changed = True
        if "title" not in notification:
            notification["title"] = ""
            changed = True
        if "content" not in notification:
            notification["content"] = ""
            changed = True
        if "relatedType" not in notification:
            notification["relatedType"] = ""
            changed = True
        if "relatedId" not in notification:
            notification["relatedId"] = ""
            changed = True
        if "postId" not in notification:
            notification["postId"] = ""
            changed = True
        if "actorId" not in notification:
            notification["actorId"] = ""
            changed = True
        if "actorAlias" not in notification:
            notification["actorAlias"] = ""
            changed = True
        if "createdAt" not in notification:
            notification["createdAt"] = now_iso()
            changed = True
        if "readAt" not in notification:
            notification["readAt"] = ""
            changed = True
        if "deleted" not in notification:
            notification["deleted"] = False
            changed = True

    for appeal in db.get("appeals", []):
        if "userId" not in appeal:
            appeal["userId"] = ""
            changed = True
        if "userEmail" not in appeal:
            appeal["userEmail"] = ""
            changed = True
        if "studentId" not in appeal:
            appeal["studentId"] = ""
            changed = True
        if "userNickname" not in appeal:
            appeal["userNickname"] = "匿名同学"
            changed = True
        if "appealType" not in appeal:
            appeal["appealType"] = "other"
            changed = True
        if "targetType" not in appeal:
            appeal["targetType"] = ""
            changed = True
        if "targetId" not in appeal:
            appeal["targetId"] = ""
            changed = True
        if "title" not in appeal:
            appeal["title"] = ""
            changed = True
        if "content" not in appeal:
            appeal["content"] = ""
            changed = True
        if "status" not in appeal:
            appeal["status"] = "pending"
            changed = True
        if "adminNote" not in appeal:
            appeal["adminNote"] = ""
            changed = True
        if "createdAt" not in appeal:
            appeal["createdAt"] = now_iso()
            changed = True
        if "handledAt" not in appeal:
            appeal["handledAt"] = ""
            changed = True
        if "handledBy" not in appeal:
            appeal["handledBy"] = ""
            changed = True

    for request in db.get("postPinRequests", []):
        if "postId" not in request:
            request["postId"] = ""
            changed = True
        if "userId" not in request:
            request["userId"] = ""
            changed = True
        raw_duration = request.get("durationMinutes")
        normalized_duration = parse_pin_duration_minutes(raw_duration) or 0
        if "durationMinutes" not in request or normalized_duration != raw_duration:
            request["durationMinutes"] = normalized_duration
            changed = True
        if "reason" not in request:
            request["reason"] = ""
            changed = True
        if "status" not in request:
            request["status"] = "pending"
            changed = True
        if "adminNote" not in request:
            request["adminNote"] = ""
            changed = True
        if "createdAt" not in request:
            request["createdAt"] = now_iso()
            changed = True
        if "handledAt" not in request:
            request["handledAt"] = ""
            changed = True
        if "handledBy" not in request:
            request["handledBy"] = ""
            changed = True

    for request in db.get("userLevelRequests", []):
        if "userId" not in request:
            request["userId"] = ""
            changed = True
        normalized_current = normalize_user_level(request.get("currentLevel"))
        if "currentLevel" not in request or normalized_current != request.get("currentLevel"):
            request["currentLevel"] = normalized_current
            changed = True
        normalized_target = USER_LEVEL_ONE if normalize_user_level(request.get("targetLevel")) == USER_LEVEL_ONE else USER_LEVEL_ONE
        if "targetLevel" not in request or normalized_target != request.get("targetLevel"):
            request["targetLevel"] = normalized_target
            changed = True
        if "reason" not in request:
            request["reason"] = ""
            changed = True
        if "status" not in request:
            request["status"] = "pending"
            changed = True
        if "adminNote" not in request:
            request["adminNote"] = ""
            changed = True
        if "createdAt" not in request:
            request["createdAt"] = now_iso()
            changed = True
        if "handledAt" not in request:
            request["handledAt"] = ""
            changed = True
        if "handledBy" not in request:
            request["handledBy"] = ""
            changed = True

    for upload in db.get("mediaUploads", []):
        if "moderationReason" not in upload:
            upload["moderationReason"] = ""
            changed = True
        if "reviewNote" not in upload:
            upload["reviewNote"] = ""
            changed = True
        if "reviewedBy" not in upload:
            upload["reviewedBy"] = ""
            changed = True
        if "reviewedAt" not in upload:
            upload["reviewedAt"] = ""
            changed = True
        if "postId" not in upload:
            upload["postId"] = ""
            changed = True
        if "deleted" not in upload:
            upload["deleted"] = False
            changed = True
        if "status" not in upload:
            upload["status"] = "pending"
            changed = True

    for request in db.get("accountCancellationRequests", []):
        if "userEmail" not in request:
            request["userEmail"] = ""
            changed = True
        if "userNickname" not in request:
            request["userNickname"] = "匿名同学"
            changed = True
        if "studentId" not in request:
            request["studentId"] = ""
            changed = True
        if "avatarUrl" not in request:
            request["avatarUrl"] = ""
            changed = True
        else:
            normalized_avatar = normalize_avatar_url(str(request.get("avatarUrl", "")))
            if normalized_avatar != str(request.get("avatarUrl", "")):
                request["avatarUrl"] = normalized_avatar
                changed = True
        if "reason" not in request:
            request["reason"] = ""
            changed = True
        if "status" not in request:
            request["status"] = "pending"
            changed = True
        if "reviewNote" not in request:
            request["reviewNote"] = ""
            changed = True
        if "handledAt" not in request:
            request["handledAt"] = ""
            changed = True
        if "handledBy" not in request:
            request["handledBy"] = ""
            changed = True

    for post in db.get("posts", []):
        post_id = str(post.get("id", "")).strip()
        if not post_id:
            continue
        has_image = any(
            (not upload.get("deleted"))
            and upload.get("postId") == post_id
            and str(upload.get("status", "pending")).lower() in {"pending", "approved", "risk"}
            for upload in db.get("mediaUploads", [])
        )
        if bool(post.get("hasImage", False)) != has_image:
            post["hasImage"] = has_image
            changed = True

    return changed


def load_db() -> dict[str, Any]:
    ensure_db()
    db = REPOSITORY.load_state()
    if migrate_db(db):
        save_db(db)
    return db


def next_id(db: dict[str, Any], key: str, prefix: str) -> str:
    db["seq"][key] += 1
    return f"{prefix}{db['seq'][key]}"


def add_audit_log(db: dict[str, Any], actor_id: str, action: str, detail: str) -> None:
    db["auditLogs"].append(
        {
            "id": next_id(db, "audit", "a"),
            "actorId": actor_id,
            "action": action,
            "detail": detail,
            "createdAt": now_iso(),
        }
    )


def find_user_by_email(
    db: dict[str, Any],
    email: str,
    *,
    include_deleted: bool = False,
) -> dict[str, Any] | None:
    target = email.lower().strip()
    for user in db["users"]:
        if user.get("deleted") and not include_deleted:
            continue
        if user.get("email", "").lower().strip() == target:
            return user
    return None


def find_user_by_student_id(
    db: dict[str, Any],
    student_id: str,
    *,
    include_deleted: bool = False,
) -> dict[str, Any] | None:
    target = student_id.strip()
    if not target:
        return None
    for user in db["users"]:
        if user.get("deleted") and not include_deleted:
            continue
        if str(user.get("studentId", "")).strip() == target:
            return user
    return None


def find_user_by_id(
    db: dict[str, Any],
    user_id: str,
    *,
    include_deleted: bool = False,
) -> dict[str, Any] | None:
    for user in db["users"]:
        if user.get("deleted") and not include_deleted:
            continue
        if user.get("id") == user_id:
            return user
    return None


def user_nickname(user: dict[str, Any] | None) -> str:
    if not user:
        return "匿名同学"
    nickname = sanitize_alias(str(user.get("nickname", "")), fallback="")
    if nickname:
        return nickname
    return sanitize_alias(str(user.get("alias", "")), fallback="匿名同学")


def user_avatar_url(user: dict[str, Any] | None) -> str:
    if not user:
        return ""
    return normalize_avatar_url(str(user.get("avatarUrl", "")))


def normalize_optional_bool(value: Any) -> bool | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off"}:
            return False
    return None


def is_post_anonymous(db: dict[str, Any], post: dict[str, Any]) -> bool:
    normalized = normalize_optional_bool(post.get("isAnonymous"))
    if normalized is not None:
        return normalized

    author_id = str(post.get("authorId", "")).strip()
    author_alias = sanitize_alias(str(post.get("authorAlias", "")), fallback="")
    if not author_id or not author_alias:
        return True

    author_user = find_user_by_id(db, author_id, include_deleted=True)
    if author_user is None:
        return True
    return author_alias != user_nickname(author_user)


def effective_post_allow_dm(db: dict[str, Any], post: dict[str, Any]) -> bool:
    return bool(post.get("allowDm", False)) and not is_post_anonymous(db, post)


def is_user_following(
    db: dict[str, Any],
    follower_user_id: str,
    followee_user_id: str,
) -> bool:
    follower_user_id = follower_user_id.strip()
    followee_user_id = followee_user_id.strip()
    if not follower_user_id or not followee_user_id or follower_user_id == followee_user_id:
        return False
    return any(
        row
        for row in db.get("userFollows", [])
        if str(row.get("followerUserId", "")).strip() == follower_user_id
        and str(row.get("followeeUserId", "")).strip() == followee_user_id
    )


def count_following(db: dict[str, Any], user_id: str) -> int:
    target_user_id = user_id.strip()
    return sum(
        1
        for row in db.get("userFollows", [])
        if str(row.get("followerUserId", "")).strip() == target_user_id
        and find_user_by_id(db, str(row.get("followeeUserId", "")).strip()) is not None
    )


def count_followers(db: dict[str, Any], user_id: str) -> int:
    target_user_id = user_id.strip()
    return sum(
        1
        for row in db.get("userFollows", [])
        if str(row.get("followeeUserId", "")).strip() == target_user_id
        and find_user_by_id(db, str(row.get("followerUserId", "")).strip()) is not None
    )


def build_follow_user_item(
    db: dict[str, Any],
    *,
    target_user_id: str,
    viewer_user_id: str,
) -> dict[str, Any] | None:
    target_user = find_user_by_id(db, target_user_id)
    if target_user is None:
        return None
    return {
        "userId": str(target_user.get("id", "")).strip(),
        "nickname": user_nickname(target_user),
        "avatarUrl": user_avatar_url(target_user),
        "isFollowing": is_user_following(db, viewer_user_id, target_user_id),
        "isFollower": is_user_following(db, target_user_id, viewer_user_id),
    }


def list_following_users(
    db: dict[str, Any],
    *,
    user_id: str,
    viewer_user_id: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for follow in db.get("userFollows", []):
        if str(follow.get("followerUserId", "")).strip() != user_id.strip():
            continue
        item = build_follow_user_item(
            db,
            target_user_id=str(follow.get("followeeUserId", "")).strip(),
            viewer_user_id=viewer_user_id,
        )
        if item is not None:
            item["_createdAt"] = str(follow.get("createdAt", ""))
            rows.append(item)
    rows.sort(key=lambda item: (str(item.get("_createdAt", "")), str(item.get("userId", ""))), reverse=True)
    for item in rows:
        item.pop("_createdAt", None)
    return rows


def list_follower_users(
    db: dict[str, Any],
    *,
    user_id: str,
    viewer_user_id: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for follow in db.get("userFollows", []):
        if str(follow.get("followeeUserId", "")).strip() != user_id.strip():
            continue
        item = build_follow_user_item(
            db,
            target_user_id=str(follow.get("followerUserId", "")).strip(),
            viewer_user_id=viewer_user_id,
        )
        if item is not None:
            item["_createdAt"] = str(follow.get("createdAt", ""))
            rows.append(item)
    rows.sort(key=lambda item: (str(item.get("_createdAt", "")), str(item.get("userId", ""))), reverse=True)
    for item in rows:
        item.pop("_createdAt", None)
    return rows


def list_friend_users(
    db: dict[str, Any],
    *,
    user_id: str,
) -> list[dict[str, Any]]:
    following_ids = {
        str(row.get("followeeUserId", "")).strip()
        for row in db.get("userFollows", [])
        if str(row.get("followerUserId", "")).strip() == user_id.strip()
    }
    follower_ids = {
        str(row.get("followerUserId", "")).strip()
        for row in db.get("userFollows", [])
        if str(row.get("followeeUserId", "")).strip() == user_id.strip()
    }
    mutual_ids = sorted(following_ids & follower_ids)
    rows: list[dict[str, Any]] = []
    for target_user_id in mutual_ids:
        item = build_follow_user_item(
            db,
            target_user_id=target_user_id,
            viewer_user_id=user_id,
        )
        if item is not None:
            rows.append(item)
    rows.sort(key=lambda item: (str(item.get("nickname", "")), str(item.get("userId", ""))))
    return rows


def can_request_dm_to_user(
    db: dict[str, Any],
    *,
    viewer_user_id: str,
    target_user_id: str,
) -> bool:
    viewer_user_id = viewer_user_id.strip()
    target_user_id = target_user_id.strip()
    if not viewer_user_id or not target_user_id or viewer_user_id == target_user_id:
        return False

    viewer_user = find_user_by_id(db, viewer_user_id)
    target_user = find_user_by_id(db, target_user_id)
    if viewer_user is None or target_user is None:
        return False
    if not bool(target_user.get("showContactable", True)):
        return False
    if not bool(target_user.get("allowStrangerDm", True)):
        return False
    if is_user_blocked(db, viewer_user_id, target_user_id):
        return False
    if is_user_blocked(db, target_user_id, viewer_user_id):
        return False
    return True


def serialize_public_user_profile(
    db: dict[str, Any],
    *,
    target_user: dict[str, Any],
    viewer_user_id: str,
) -> dict[str, Any]:
    target_user_id = str(target_user.get("id", "")).strip()
    return {
        "id": target_user_id,
        "alias": user_nickname(target_user),
        "nickname": user_nickname(target_user),
        "avatarUrl": user_avatar_url(target_user),
        "verified": bool(target_user.get("verified", False)),
        "verifiedAt": str(target_user.get("verifiedAt", "")),
        "userLevel": current_user_level(target_user),
        "userLevelLabel": user_level_label(current_user_level(target_user)),
        "isLevelOneUser": is_level_one_user(target_user),
        "favoriteCount": 0,
        "postCount": sum(
            1
            for post in list_posts(db)
            if str(post.get("authorId", "")).strip() == target_user_id
            and not is_post_anonymous(db, post)
        ),
        "followingCount": count_following(db, target_user_id),
        "followerCount": count_followers(db, target_user_id),
        "isFollowing": is_user_following(db, viewer_user_id, target_user_id),
        "isFollower": is_user_following(db, target_user_id, viewer_user_id),
        "isOwnProfile": bool(viewer_user_id and viewer_user_id == target_user_id),
        "canFollow": bool(viewer_user_id and viewer_user_id != target_user_id),
        "canDirectMessage": can_request_dm_to_user(
            db,
            viewer_user_id=viewer_user_id,
            target_user_id=target_user_id,
        ),
    }


def current_user_level(user: dict[str, Any] | None) -> int:
    if not user:
        return USER_LEVEL_TWO
    return normalize_user_level(user.get("userLevel"))


def is_level_one_user(user: dict[str, Any] | None) -> bool:
    return current_user_level(user) == USER_LEVEL_ONE


def apply_post_pin(
    post: dict[str, Any],
    *,
    duration_minutes: int,
    started_at: str | None = None,
) -> None:
    pin_started_at = started_at or now_iso()
    started_dt = parse_iso(pin_started_at)
    if started_dt is None:
        started_dt = now_utc()
        pin_started_at = started_dt.isoformat()
    post["pinStartedAt"] = pin_started_at
    post["pinExpiresAt"] = (started_dt + timedelta(minutes=duration_minutes)).isoformat()
    post["pinDurationMinutes"] = duration_minutes
    post["updatedAt"] = now_iso()


def is_post_pin_active(post: dict[str, Any]) -> bool:
    expires_at = parse_iso(str(post.get("pinExpiresAt", "")))
    duration_minutes = parse_pin_duration_minutes(post.get("pinDurationMinutes"))
    if expires_at is None or duration_minutes is None:
        return False
    return expires_at > now_utc()


def latest_pending_post_pin_request_for_post(
    db: dict[str, Any],
    post_id: str,
) -> dict[str, Any] | None:
    rows = [
        row
        for row in db.get("postPinRequests", [])
        if str(row.get("postId", "")).strip() == post_id.strip()
        and str(row.get("status", "pending")).strip().lower() == "pending"
    ]
    if not rows:
        return None
    rows.sort(
        key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))),
        reverse=True,
    )
    return rows[0]


def latest_user_level_request_for_user(
    db: dict[str, Any],
    user_id: str,
    *,
    status: str = "",
) -> dict[str, Any] | None:
    normalized_status = status.strip().lower()
    rows = [
        row
        for row in db.get("userLevelRequests", [])
        if str(row.get("userId", "")).strip() == user_id.strip()
        and (
            not normalized_status
            or str(row.get("status", "pending")).strip().lower() == normalized_status
        )
    ]
    if not rows:
        return None
    rows.sort(
        key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))),
        reverse=True,
    )
    return rows[0]


def conversation_key_for_users(user_a_id: str, user_b_id: str) -> str:
    left = user_a_id.strip()
    right = user_b_id.strip()
    if not left or not right:
        return ""
    return "::".join(sorted([left, right]))


def is_user_blocked(db: dict[str, Any], blocker_user_id: str, blocked_user_id: str) -> bool:
    blocker = blocker_user_id.strip()
    blocked = blocked_user_id.strip()
    if not blocker or not blocked:
        return False
    return any(
        str(row.get("blockerUserId", "")).strip() == blocker
        and str(row.get("blockedUserId", "")).strip() == blocked
        for row in db.get("userBlocks", [])
    )


def conversation_block_state(
    db: dict[str, Any],
    *,
    viewer_user_id: str,
    peer_user_id: str,
) -> tuple[bool, bool]:
    return (
        is_user_blocked(db, viewer_user_id, peer_user_id),
        is_user_blocked(db, peer_user_id, viewer_user_id),
    )


def upsert_conversation_for_user(
    db: dict[str, Any],
    *,
    user_id: str,
    peer_user_id: str,
    last_message: str,
    updated_at: str,
    unread_count: int | None = None,
    last_read_at: str | None = None,
    deleted: bool | None = None,
) -> dict[str, Any] | None:
    user = find_user_by_id(db, user_id)
    peer_user = find_user_by_id(db, peer_user_id)
    if user is None or peer_user is None:
        return None

    row = next(
        (
            item
            for item in db.get("conversations", [])
            if item.get("userId") == user_id and item.get("peerUserId") == peer_user_id
        ),
        None,
    )
    if row is None:
        row = {
            "id": next_id(db, "conversation", "c"),
            "userId": user_id,
            "peerUserId": peer_user_id,
            "name": user_nickname(peer_user),
            "avatarUrl": user_avatar_url(peer_user),
            "lastMessage": last_message,
            "unreadCount": max(0, int(unread_count or 0)),
            "lastReadAt": last_read_at or "",
            "updatedAt": updated_at,
            "deleted": bool(deleted) if deleted is not None else False,
        }
        db["conversations"].append(row)
        return row

    row["name"] = user_nickname(peer_user)
    row["avatarUrl"] = user_avatar_url(peer_user)
    row["lastMessage"] = last_message
    row["updatedAt"] = updated_at
    if unread_count is not None:
        row["unreadCount"] = max(0, int(unread_count))
    if last_read_at is not None:
        row["lastReadAt"] = last_read_at
    if deleted is not None:
        row["deleted"] = bool(deleted)
    return row


def sync_conversation_pair(
    db: dict[str, Any],
    *,
    left_user_id: str,
    right_user_id: str,
    last_message: str,
    updated_at: str,
) -> None:
    if not left_user_id.strip() or not right_user_id.strip():
        return
    upsert_conversation_for_user(
        db,
        user_id=left_user_id,
        peer_user_id=right_user_id,
        last_message=last_message,
        updated_at=updated_at,
        deleted=False,
    )
    upsert_conversation_for_user(
        db,
        user_id=right_user_id,
        peer_user_id=left_user_id,
        last_message=last_message,
        updated_at=updated_at,
        deleted=False,
    )


def deliver_message_to_conversation_pair(
    db: dict[str, Any],
    *,
    sender_user_id: str,
    receiver_user_id: str,
    last_message: str,
    updated_at: str,
) -> None:
    sender_row = next(
        (
            item
            for item in db.get("conversations", [])
            if item.get("userId") == sender_user_id and item.get("peerUserId") == receiver_user_id
        ),
        None,
    )
    receiver_row = next(
        (
            item
            for item in db.get("conversations", [])
            if item.get("userId") == receiver_user_id and item.get("peerUserId") == sender_user_id
        ),
        None,
    )
    upsert_conversation_for_user(
        db,
        user_id=sender_user_id,
        peer_user_id=receiver_user_id,
        last_message=last_message,
        updated_at=updated_at,
        unread_count=int(sender_row.get("unreadCount", 0)) if sender_row else 0,
        last_read_at=updated_at,
        deleted=False,
    )
    upsert_conversation_for_user(
        db,
        user_id=receiver_user_id,
        peer_user_id=sender_user_id,
        last_message=last_message,
        updated_at=updated_at,
        unread_count=(int(receiver_row.get("unreadCount", 0)) if receiver_row else 0) + 1,
        deleted=False,
    )


def mark_conversation_read(
    db: dict[str, Any],
    *,
    user_id: str,
    conversation: dict[str, Any],
) -> bool:
    peer_user_id = str(conversation.get("peerUserId", "")).strip()
    if not peer_user_id:
        return False
    conversation_key = conversation_key_for_users(user_id, peer_user_id)
    if not conversation_key:
        return False
    read_at = now_iso()
    changed = False
    for row in db.get("directMessages", []):
        if row.get("deleted"):
            continue
        if str(row.get("conversationKey", "")).strip() != conversation_key:
            continue
        if str(row.get("receiverUserId", "")).strip() != user_id:
            continue
        if str(row.get("readAt", "")).strip():
            continue
        row["readAt"] = read_at
        changed = True
    if int(conversation.get("unreadCount", 0) or 0) != 0:
        conversation["unreadCount"] = 0
        changed = True
    if conversation.get("lastReadAt") != read_at:
        conversation["lastReadAt"] = read_at
        changed = True
    return changed


def reject_pending_dm_requests_between(
    db: dict[str, Any],
    *,
    left_user_id: str,
    right_user_id: str,
    updated_at: str,
) -> bool:
    changed = False
    for row in db.get("dmRequests", []):
        if str(row.get("status", "pending")).strip().lower() != "pending":
            continue
        from_user_id = str(row.get("fromUserId", "")).strip()
        to_user_id = str(row.get("toUserId", "")).strip()
        if {from_user_id, to_user_id} != {left_user_id.strip(), right_user_id.strip()}:
            continue
        row["status"] = "rejected"
        row["updatedAt"] = updated_at
        changed = True
    return changed


def serialize_direct_message(
    db: dict[str, Any],
    row: dict[str, Any],
    *,
    viewer_user_id: str,
) -> dict[str, Any]:
    sender_user_id = str(row.get("senderUserId", ""))
    sender_user = find_user_by_id(db, sender_user_id, include_deleted=True)
    read_at = str(row.get("readAt", "")).strip()
    return {
        "id": str(row.get("id", "")),
        "content": str(row.get("content", "")),
        "createdAt": str(row.get("createdAt", "")),
        "timeText": iso_to_time_text(str(row.get("createdAt", ""))),
        "fromMe": viewer_user_id == sender_user_id,
        "senderUserId": sender_user_id,
        "senderAlias": user_nickname(sender_user),
        "readAt": read_at,
        "isRead": bool(read_at),
        "deliveryStatus": "read" if read_at else "sent",
    }


def create_notification(
    db: dict[str, Any],
    *,
    user_id: str,
    notification_type: str,
    title: str,
    content: str,
    related_type: str = "",
    related_id: str = "",
    post_id: str = "",
    actor_id: str = "",
    actor_alias: str = "",
) -> dict[str, Any] | None:
    target_user = find_user_by_id(db, user_id, include_deleted=True)
    if target_user is None or target_user.get("deleted"):
        return None
    row = {
        "id": next_id(db, "notification", "n"),
        "userId": user_id.strip(),
        "type": notification_type.strip() or "system",
        "title": title.strip(),
        "content": content.strip(),
        "relatedType": related_type.strip(),
        "relatedId": related_id.strip(),
        "postId": post_id.strip(),
        "actorId": actor_id.strip(),
        "actorAlias": actor_alias.strip(),
        "createdAt": now_iso(),
        "readAt": "",
        "deleted": False,
    }
    db.setdefault("notifications", []).append(row)
    return row


def serialize_notification(row: dict[str, Any]) -> dict[str, Any]:
    created_at = str(row.get("createdAt", ""))
    read_at = str(row.get("readAt", "")).strip()
    return {
        "id": str(row.get("id", "")),
        "type": str(row.get("type", "system")),
        "title": str(row.get("title", "")),
        "content": str(row.get("content", "")),
        "relatedType": str(row.get("relatedType", "")),
        "relatedId": str(row.get("relatedId", "")),
        "postId": str(row.get("postId", "")),
        "actorId": str(row.get("actorId", "")),
        "actorAlias": str(row.get("actorAlias", "")),
        "createdAt": created_at,
        "timeText": iso_to_time_text(created_at),
        "readAt": read_at,
        "isRead": bool(read_at),
    }


def serialize_system_announcement(row: dict[str, Any]) -> dict[str, Any]:
    created_at = str(row.get("createdAt", ""))
    return {
        "id": str(row.get("id", "")),
        "title": str(row.get("title", "")),
        "content": str(row.get("content", "")),
        "createdAt": created_at,
        "timeText": iso_to_time_text(created_at),
        "createdBy": str(row.get("createdBy", "")),
    }


def publish_system_announcement(
    db: dict[str, Any],
    *,
    admin: dict[str, Any],
    title: str,
    content: str,
) -> dict[str, Any]:
    announcement = {
        "id": next_id(db, "announcement", "ann"),
        "title": title.strip(),
        "content": content.strip(),
        "createdAt": now_iso(),
        "createdBy": str(admin.get("id", "")).strip(),
    }
    db.setdefault("systemAnnouncements", []).append(announcement)
    for user in db.get("users", []):
        if user.get("deleted"):
            continue
        create_notification(
            db,
            user_id=str(user.get("id", "")),
            notification_type="system_announcement",
            title=announcement["title"],
            content=announcement["content"],
            related_type="announcement",
            related_id=announcement["id"],
            actor_id=str(admin.get("id", "")),
            actor_alias="管理员",
        )
    return announcement


def account_cancellation_status_label(status: str) -> str:
    normalized = status.strip().lower() or "pending"
    return {
        "pending": "待审核",
        "approved": "已通过",
        "rejected": "已驳回",
    }.get(normalized, normalized)


def latest_account_cancellation_request_for_user(
    db: dict[str, Any],
    user_id: str,
    *,
    status: str | None = None,
) -> dict[str, Any] | None:
    rows: list[dict[str, Any]] = []
    normalized_status = (status or "").strip().lower()
    for row in db.get("accountCancellationRequests", []):
        if str(row.get("userId", "")) != user_id:
            continue
        row_status = str(row.get("status", "pending")).strip().lower() or "pending"
        if normalized_status and row_status != normalized_status:
            continue
        rows.append(row)
    if not rows:
        return None
    rows.sort(
        key=lambda item: (
            str(item.get("createdAt", "")),
            str(item.get("id", "")),
        ),
        reverse=True,
    )
    return rows[0]


def serialize_account_cancellation_request(row: dict[str, Any]) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    return {
        "id": str(row.get("id", "")),
        "userId": str(row.get("userId", "")),
        "userEmail": str(row.get("userEmail", "")),
        "userNickname": sanitize_alias(str(row.get("userNickname", "")), fallback="匿名同学"),
        "studentId": str(row.get("studentId", "")),
        "avatarUrl": normalize_avatar_url(str(row.get("avatarUrl", ""))),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": account_cancellation_status_label(status),
        "reviewNote": str(row.get("reviewNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
    }


def appeal_status_label(status: str) -> str:
    normalized = status.strip().lower() or "pending"
    return {
        "pending": "待处理",
        "approved": "已通过",
        "rejected": "已驳回",
        "closed": "已关闭",
    }.get(normalized, normalized)


def appeal_type_label(appeal_type: str) -> str:
    normalized = appeal_type.strip().lower() or "other"
    return {
        "account_restore": "账号恢复申诉",
        "account_status": "账号状态申诉",
        "content_review": "内容审核申诉",
        "other": "其他申诉",
    }.get(normalized, normalized)


def serialize_appeal(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    user = find_user_by_id(
        db,
        str(row.get("userId", "")).strip(),
        include_deleted=True,
    )
    nickname = sanitize_alias(
        str(row.get("userNickname", "")),
        fallback=user_nickname(user),
    )
    return {
        "id": str(row.get("id", "")),
        "userId": str(row.get("userId", "")),
        "userEmail": str(row.get("userEmail", "")),
        "studentId": str(row.get("studentId", "")),
        "userNickname": nickname,
        "appealType": str(row.get("appealType", "other")),
        "appealTypeLabel": appeal_type_label(str(row.get("appealType", "other"))),
        "targetType": str(row.get("targetType", "")),
        "targetId": str(row.get("targetId", "")),
        "title": str(row.get("title", "")),
        "content": str(row.get("content", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
        "userDeleted": bool(user.get("deleted", False)) if user else False,
        "userBanned": bool(user.get("banned", False)) if user else False,
        "userMuted": bool(user.get("muted", False)) if user else False,
    }


def serialize_user_level_request_summary(
    row: dict[str, Any] | None,
) -> dict[str, Any] | None:
    if row is None:
        return None
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    current_level = normalize_user_level(row.get("currentLevel"))
    target_level = normalize_user_level(row.get("targetLevel"))
    return {
        "id": str(row.get("id", "")),
        "currentLevel": current_level,
        "currentLevelLabel": user_level_label(current_level),
        "targetLevel": target_level,
        "targetLevelLabel": user_level_label(target_level),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
    }


def serialize_admin_post_pin_request(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    post = next(
        (
            item
            for item in db.get("posts", [])
            if str(item.get("id", "")).strip() == str(row.get("postId", "")).strip()
        ),
        None,
    )
    user = find_user_by_id(
        db,
        str(row.get("userId", "")).strip(),
        include_deleted=True,
    )
    duration_minutes = parse_pin_duration_minutes(row.get("durationMinutes")) or 0
    return {
        "id": str(row.get("id", "")),
        "postId": str(row.get("postId", "")),
        "postTitle": str(post.get("title", "")) if post else "",
        "userId": str(row.get("userId", "")),
        "userEmail": str(user.get("email", "")) if user else "",
        "userNickname": user_nickname(user),
        "userLevel": current_user_level(user),
        "userLevelLabel": user_level_label(current_user_level(user)),
        "durationMinutes": duration_minutes,
        "durationLabel": pin_duration_label(duration_minutes),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
        "postDeleted": bool(post.get("deleted", False)) if post else True,
        "postPinned": is_post_pin_active(post or {}),
    }


def serialize_admin_user_level_request(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    user = find_user_by_id(
        db,
        str(row.get("userId", "")).strip(),
        include_deleted=True,
    )
    current_level = normalize_user_level(row.get("currentLevel"))
    target_level = normalize_user_level(row.get("targetLevel"))
    return {
        "id": str(row.get("id", "")),
        "userId": str(row.get("userId", "")),
        "userEmail": str(user.get("email", "")) if user else "",
        "studentId": str(user.get("studentId", "")) if user else "",
        "userNickname": user_nickname(user),
        "currentLevel": current_level,
        "currentLevelLabel": user_level_label(current_level),
        "targetLevel": target_level,
        "targetLevelLabel": user_level_label(target_level),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
        "userDeleted": bool(user.get("deleted", False)) if user else True,
        "userCurrentLevel": current_user_level(user),
        "userCurrentLevelLabel": user_level_label(current_user_level(user)),
    }


def latest_pending_appeal_for_user(
    db: dict[str, Any],
    user_id: str,
    *,
    appeal_type: str = "",
) -> dict[str, Any] | None:
    normalized_type = appeal_type.strip().lower()
    rows: list[dict[str, Any]] = []
    for row in db.get("appeals", []):
        if str(row.get("userId", "")).strip() != user_id.strip():
            continue
        if str(row.get("status", "pending")).strip().lower() != "pending":
            continue
        if normalized_type and str(row.get("appealType", "")).strip().lower() != normalized_type:
            continue
        rows.append(row)
    if not rows:
        return None
    rows.sort(
        key=lambda item: (
            str(item.get("createdAt", "")),
            str(item.get("id", "")),
        ),
        reverse=True,
    )
    return rows[0]


def restore_user_account(
    db: dict[str, Any],
    user: dict[str, Any],
    *,
    actor_id: str,
    detail: str,
) -> None:
    user["deleted"] = False
    add_audit_log(db, actor_id, "restore_account", detail)


def sync_cancellation_requests_after_admin_cancel(
    db: dict[str, Any],
    *,
    user_id: str,
    handled_by: str,
    review_note: str,
) -> None:
    handled_at = now_iso()
    for row in db.get("accountCancellationRequests", []):
        if str(row.get("userId", "")).strip() != user_id.strip():
            continue
        if str(row.get("status", "pending")).strip().lower() != "pending":
            continue
        row["status"] = "approved"
        row["handledAt"] = handled_at
        row["handledBy"] = handled_by
        row["reviewNote"] = review_note or "管理员直接注销违规账号，申请已同步完成"


def cancel_user_account(
    db: dict[str, Any],
    user: dict[str, Any],
    *,
    actor_id: str,
    detail: str,
) -> None:
    user_id = str(user.get("id", "")).strip()
    user["deleted"] = True

    email = str(user.get("email", "")).strip().lower()
    if email:
        db["emailCodes"].pop(email, None)
        db["emailCodes"].pop(password_reset_code_key(email), None)

    for token, uid in list(db["sessions"].items()):
        if uid == user_id:
            db["sessions"].pop(token, None)

    db["dmRequests"] = [
        row
        for row in db.get("dmRequests", [])
        if row.get("toUserId") != user_id and row.get("fromUserId") != user_id
    ]
    db["userBlocks"] = [
        row
        for row in db.get("userBlocks", [])
        if row.get("blockerUserId") != user_id and row.get("blockedUserId") != user_id
    ]
    db["conversations"] = [
        row
        for row in db.get("conversations", [])
        if row.get("userId") != user_id and row.get("peerUserId") != user_id
    ]
    db["directMessages"] = [
        row
        for row in db.get("directMessages", [])
        if row.get("senderUserId") != user_id and row.get("receiverUserId") != user_id
    ]
    db["notifications"] = [
        row
        for row in db.get("notifications", [])
        if row.get("userId") != user_id and row.get("actorId") != user_id
    ]

    avatar_key = extract_local_object_key_from_url(user_avatar_url(user))
    if avatar_key:
        try:
            OBJECT_STORAGE.delete(avatar_key)
        except Exception:
            pass
    user["avatarUrl"] = ""

    affected_post_ids: set[str] = set()
    for upload in db.get("mediaUploads", []):
        if upload.get("uploaderId") != user.get("id") or upload.get("deleted"):
            continue
        upload["deleted"] = True
        post_id = str(upload.get("postId", "")).strip()
        if post_id:
            affected_post_ids.add(post_id)
        object_key = str(upload.get("objectKey", "")).strip()
        if object_key:
            try:
                OBJECT_STORAGE.delete(object_key)
            except Exception:
                pass

    for post_id in affected_post_ids:
        recalc_post_has_image(db, post_id)

    add_audit_log(db, actor_id, "cancel_account", detail)


def auth_user(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None

    token = auth_header[7:].strip()
    if not token:
        return None, None

    user_id = db["sessions"].get(token)
    if not user_id:
        return None, token

    user = find_user_by_id(db, user_id)
    return user, token


def auth_admin(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None

    token = auth_header[7:].strip()
    if not token:
        return None, None

    with ADMIN_SESSION_LOCK:
        admin_id = ADMIN_SESSIONS.get(token)

    if not admin_id:
        return None, token

    account = find_admin_account_by_id(db, admin_id, include_inactive=True)
    if account is None or not bool(account.get("active", True)):
        with ADMIN_SESSION_LOCK:
            ADMIN_SESSIONS.pop(token, None)
        return None, token

    return build_authenticated_admin(account), token


def iso_to_time_text(value: str | None) -> str:
    if not value:
        return "-"
    dt = parse_iso(value)
    if dt is None:
        return value
    return dt.astimezone(CHINA_TZ).strftime("%Y-%m-%d %H:%M")


def post_counts(db: dict[str, Any], post_id: str) -> tuple[int, int, int]:
    comment_count = sum(1 for c in db["comments"] if c.get("postId") == post_id and not c.get("deleted"))
    like_count = sum(1 for x in db["likes"] if x.get("postId") == post_id)
    favorite_count = sum(1 for x in db["favorites"] if x.get("postId") == post_id)
    return comment_count, like_count, favorite_count


def list_post_images(
    db: dict[str, Any],
    post_id: str,
    *,
    include_unapproved: bool = False,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for upload in db.get("mediaUploads", []):
        if upload.get("deleted"):
            continue
        if upload.get("postId") != post_id:
            continue
        status = str(upload.get("status", "pending")).lower()
        if not include_unapproved and status not in {"approved", "pending", "risk"}:
            continue
        rows.append(
            {
                "id": upload.get("id", ""),
                "url": upload.get("url", ""),
                "status": status,
                "contentType": upload.get("contentType", ""),
                "sizeBytes": int(upload.get("sizeBytes", 0)),
            }
        )
    rows.sort(key=lambda x: str(x.get("id", "")))
    return rows


def recalc_post_has_image(db: dict[str, Any], post_id: str) -> bool:
    post = next((p for p in db["posts"] if p.get("id") == post_id), None)
    if post is None:
        return False

    has_image = any(
        (not upload.get("deleted"))
        and upload.get("postId") == post_id
        and str(upload.get("status", "pending")).lower() in {"pending", "approved", "risk"}
        for upload in db.get("mediaUploads", [])
    )
    if bool(post.get("hasImage", False)) != has_image:
        post["hasImage"] = has_image
        post["updatedAt"] = now_iso()
    return has_image


def serialize_post(
    db: dict[str, Any],
    post: dict[str, Any],
    include_admin_fields: bool = False,
    include_unapproved_images: bool = False,
    viewer_user_id: str = "",
) -> dict[str, Any]:
    comment_count, like_count, favorite_count = post_counts(db, post["id"])
    liked = bool(
        viewer_user_id
        and any(
            x
            for x in db["likes"]
            if x.get("userId") == viewer_user_id and x.get("postId") == post["id"]
        )
    )
    favorited = bool(
        viewer_user_id
        and any(
            x
            for x in db["favorites"]
            if x.get("userId") == viewer_user_id and x.get("postId") == post["id"]
        )
    )
    images = list_post_images(db, post.get("id", ""), include_unapproved=include_unapproved_images)
    image_urls = [img["url"] for img in images if img.get("url")]
    uploaded_image_ids = [img["id"] for img in images if img.get("id")]
    author_id = str(post.get("authorId", "")).strip()
    is_anonymous = is_post_anonymous(db, post)
    author_user = find_user_by_id(db, author_id) if author_id else None
    can_view_author_profile = bool(
        viewer_user_id
        and not is_anonymous
        and author_id
        and author_user is not None
    )
    can_follow_author = bool(
        can_view_author_profile
        and viewer_user_id != author_id
    )
    is_following_author = bool(
        can_follow_author
        and is_user_following(db, viewer_user_id, author_id)
    )
    can_message_author = bool(
        can_view_author_profile
        and viewer_user_id != author_id
        and effective_post_allow_dm(db, post)
        and can_request_dm_to_user(
            db,
            viewer_user_id=viewer_user_id,
            target_user_id=author_id,
        )
    )
    data: dict[str, Any] = {
        "id": post["id"],
        "title": post.get("title", ""),
        "content": post.get("content", ""),
        "channel": post.get("channel", "未分类"),
        "tags": post.get("tags", []),
        "authorAlias": post.get("authorAlias", "匿名同学"),
        "isAnonymous": is_anonymous,
        "authorAvatarUrl": "" if is_anonymous else user_avatar_url(author_user),
        "authorUserId": author_id if can_view_author_profile else "",
        "createdAt": post.get("createdAt", now_iso()),
        "hasImage": bool(post.get("hasImage", False)) or bool(images),
        "images": images,
        "imageUrls": image_urls,
        "uploadedImageIds": uploaded_image_ids,
        "commentCount": comment_count,
        "likeCount": like_count,
        "favoriteCount": favorite_count,
        "liked": liked,
        "favorited": favorited,
        "status": post.get("status", "ongoing"),
        "allowComment": bool(post.get("allowComment", True)),
        "allowDm": effective_post_allow_dm(db, post),
        "isPinned": is_post_pin_active(post),
        "pinStartedAt": str(post.get("pinStartedAt", "")),
        "pinExpiresAt": str(post.get("pinExpiresAt", "")),
        "pinDurationMinutes": parse_pin_duration_minutes(post.get("pinDurationMinutes")) or 0,
        "pinDurationLabel": pin_duration_label(post.get("pinDurationMinutes")),
        "canViewAuthorProfile": can_view_author_profile,
        "canFollowAuthor": can_follow_author,
        "isFollowingAuthor": is_following_author,
        "canMessageAuthor": can_message_author,
        "isOwnPost": bool(viewer_user_id and viewer_user_id == author_id),
    }
    if include_admin_fields:
        data["reviewStatus"] = post.get("reviewStatus", "approved")
        data["riskMarked"] = bool(post.get("riskMarked", False))
        data["authorId"] = post.get("authorId", "")
    return data


def sort_posts_for_view(
    db: dict[str, Any],
    rows: list[dict[str, Any]],
    *,
    sort_by: str = "latest",
) -> list[dict[str, Any]]:
    active_pinned = [row for row in rows if is_post_pin_active(row)]
    normal_rows = [row for row in rows if not is_post_pin_active(row)]
    active_pinned.sort(
        key=lambda row: (
            str(row.get("pinStartedAt", "")),
            str(row.get("createdAt", "")),
            str(row.get("id", "")),
        ),
        reverse=True,
    )
    if sort_by == "hot":
        # Reddit hot ranking: Score = log10(max(1, ups - downs)) + t_post / 45000
        # denominator 45000 = 12.5 hours in seconds
        now_ts = time.time()
        normal_rows.sort(
            key=lambda row: (
                math.log10(max(1, post_counts(db, row.get("id", ""))[1] or 0)),
                (now_ts - date_to_timestamp(row.get("createdAt", ""))) / 45000.0,
            ),
            reverse=True,
        )
    elif sort_by == "likes":
        normal_rows.sort(
            key=lambda row: (
                post_counts(db, row.get("id", ""))[1],
                str(row.get("createdAt", "")),
                str(row.get("id", "")),
            ),
            reverse=True,
        )
    else:  # latest
        normal_rows.sort(
            key=lambda row: (
                str(row.get("createdAt", "")),
                str(row.get("id", "")),
            ),
            reverse=True,
        )
    return [*active_pinned, *normal_rows]


def list_posts(
    db: dict[str, Any],
    include_rejected: bool = False,
    *,
    sort_by: str = "latest",
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for post in db["posts"]:
        if post.get("deleted"):
            continue
        if not include_rejected and post.get("reviewStatus") == "rejected":
            continue
        rows.append(post)
    return sort_posts_for_view(db, rows, sort_by=sort_by)


def list_comments(db: dict[str, Any], include_rejected: bool = False) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for comment in db["comments"]:
        if comment.get("deleted"):
            continue
        if not include_rejected and comment.get("reviewStatus") == "rejected":
            continue
        rows.append(comment)
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


def target_owner(db: dict[str, Any], target_type: str, target_id: str) -> str | None:
    if target_type == "post":
        post = next((p for p in db["posts"] if p.get("id") == target_id), None)
        return post.get("authorId") if post else None
    if target_type == "comment":
        comment = next((c for c in db["comments"] if c.get("id") == target_id), None)
        return comment.get("userId") if comment else None
    return None


def require_authorized_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> tuple[dict[str, Any] | None, str | None]:
    user, token = auth_user(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None, token
    if user.get("banned"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被封禁")
        return None, token
    return user, token


def require_admin_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> tuple[dict[str, Any] | None, str | None]:
    admin, token = auth_admin(handler, db)
    if admin is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "管理员未登录或登录已过期")
        return None, token
    return admin, token


def require_primary_admin_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> tuple[dict[str, Any] | None, str | None]:
    admin, token = require_admin_user(handler, db)
    if admin is None:
        return None, token
    if not bool(admin.get("isPrimary")):
        json_error(handler, HTTPStatus.FORBIDDEN, "仅一级管理员可执行此操作")
        return None, token
    return admin, token


def build_overview(db: dict[str, Any]) -> dict[str, Any]:
    today_new_users = sum(1 for u in db["users"] if not u.get("deleted") and is_today_iso(u.get("createdAt")))
    today_posts = sum(1 for p in db["posts"] if not p.get("deleted") and is_today_iso(p.get("createdAt")))
    today_comments = sum(1 for c in db["comments"] if not c.get("deleted") and is_today_iso(c.get("createdAt")))
    today_reports = sum(1 for r in db["reports"] if is_today_iso(r.get("createdAt")))
    pending_text_reviews = sum(
        1 for p in db["posts"] if not p.get("deleted") and p.get("reviewStatus") == "pending"
    ) + sum(1 for c in db["comments"] if not c.get("deleted") and c.get("reviewStatus") == "pending")
    pending_image_reviews = sum(
        1
        for upload in db.get("mediaUploads", [])
        if not upload.get("deleted") and str(upload.get("status", "pending")).lower() == "pending"
    )
    pending_cancellation_requests = sum(
        1
        for request in db.get("accountCancellationRequests", [])
        if str(request.get("status", "pending")).lower() == "pending"
    )
    pending_reviews = pending_text_reviews + pending_image_reviews
    banned_users = sum(1 for u in db["users"] if not u.get("deleted") and u.get("banned"))
    muted_users = sum(1 for u in db["users"] if not u.get("deleted") and u.get("muted"))
    active_users = sum(1 for u in db["users"] if not u.get("deleted"))

    return {
        "todayNewUsers": today_new_users,
        "todayPosts": today_posts,
        "todayComments": today_comments,
        "todayReports": today_reports,
        "pendingReviews": pending_reviews,
        "pendingTextReviews": pending_text_reviews,
        "pendingImageReviews": pending_image_reviews,
        "pendingCancellationRequests": pending_cancellation_requests,
        "bannedUsers": banned_users,
        "mutedUsers": muted_users,
        "activeUsers": active_users,
    }


ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}


def get_image_max_bytes(db: dict[str, Any]) -> int:
    settings = db.get("settings", {})
    mb = DEFAULT_SETTINGS["imageMaxMB"]
    if isinstance(settings, dict):
        raw = settings.get("imageMaxMB")
        try:
            mb = max(1, int(raw))
        except (TypeError, ValueError):
            mb = DEFAULT_SETTINGS["imageMaxMB"]
    return mb * 1024 * 1024


def public_system_settings(db: dict[str, Any]) -> dict[str, Any]:
    settings = db.get("settings", {})
    if not isinstance(settings, dict):
        return dict(DEFAULT_SETTINGS)
    return {
        "postRateLimit": get_setting_int(db, "postRateLimit", DEFAULT_SETTINGS["postRateLimit"]),
        "commentRateLimit": get_setting_int(db, "commentRateLimit", DEFAULT_SETTINGS["commentRateLimit"]),
        "messageRateLimit": get_setting_int(db, "messageRateLimit", DEFAULT_SETTINGS["messageRateLimit"]),
        "imageMaxMB": get_setting_int(db, "imageMaxMB", DEFAULT_SETTINGS["imageMaxMB"]),
    }


def moderate_image_upload(
    *,
    file_name: str,
    content_type: str,
    size_bytes: int,
    db: dict[str, Any],
) -> tuple[str, str]:
    if content_type not in ALLOWED_IMAGE_TYPES:
        return "rejected", f"不支持的图片格式：{content_type}"

    max_bytes = get_image_max_bytes(db)
    if size_bytes > max_bytes:
        return "rejected", f"图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）"

    lowered_name = file_name.lower()
    hit_words = [word for word in db.get("sensitiveWords", []) if str(word).strip() and str(word) in lowered_name]
    if hit_words:
        return "approved", ""

    return "approved", ""


def get_upload_by_id(db: dict[str, Any], upload_id: str) -> dict[str, Any] | None:
    for row in db.get("mediaUploads", []):
        if row.get("id") == upload_id:
            return row
    return None


def serialize_upload(
    db: dict[str, Any],
    upload: dict[str, Any],
    *,
    include_admin_fields: bool = False,
) -> dict[str, Any]:
    uploader = find_user_by_id(db, str(upload.get("uploaderId", "")))
    data: dict[str, Any] = {
        "id": upload.get("id", ""),
        "url": upload.get("url", ""),
        "objectKey": upload.get("objectKey", ""),
        "fileName": upload.get("fileName", ""),
        "contentType": upload.get("contentType", ""),
        "sizeBytes": int(upload.get("sizeBytes", 0)),
        "sha256": upload.get("sha256", ""),
        "status": upload.get("status", "pending"),
        "moderationReason": upload.get("moderationReason", ""),
        "createdAt": upload.get("createdAt", ""),
        "postId": upload.get("postId", ""),
        "uploaderId": upload.get("uploaderId", ""),
        "uploaderAlias": user_nickname(uploader),
    }
    if include_admin_fields:
        data["reviewNote"] = upload.get("reviewNote", "")
        data["reviewedBy"] = upload.get("reviewedBy", "")
        data["reviewedAt"] = upload.get("reviewedAt", "")
        data["deleted"] = bool(upload.get("deleted", False))
    return data


def build_admin_review_rows(
    db: dict[str, Any],
    *,
    target_type: str,
    status: str,
) -> list[dict[str, Any]]:
    normalized_type = target_type.strip().lower() or "post"
    normalized_status = status.strip().lower() or "pending"
    result: list[dict[str, Any]] = []

    if normalized_type == "post":
        rows = list_posts(db, include_rejected=True)
        for post in rows:
            row_status = str(post.get("reviewStatus", "approved")).lower()
            if normalized_status != "all" and row_status != normalized_status:
                continue
            author_user = find_user_by_id(
                db,
                str(post.get("authorId", "")),
                include_deleted=True,
            )
            result.append(
                {
                    "id": post.get("id"),
                    "targetType": "post",
                    "title": post.get("title", ""),
                    "content": post.get("content", ""),
                    "authorAlias": post.get("authorAlias", "匿名同学"),
                    "authorUserId": str(post.get("authorId", "")),
                    "authorNickname": user_nickname(author_user),
                    "authorEmail": str(author_user.get("email", "")) if author_user else "",
                    "authorStudentId": str(author_user.get("studentId", "")) if author_user else "",
                    "createdAt": post.get("createdAt", ""),
                    "reviewStatus": row_status,
                    "riskMarked": bool(post.get("riskMarked", False)),
                    "deleted": bool(post.get("deleted", False)),
                }
            )
        return result

    if normalized_type == "comment":
        rows = list_comments(db, include_rejected=True)
        for comment in rows:
            row_status = str(comment.get("reviewStatus", "approved")).lower()
            if normalized_status != "all" and row_status != normalized_status:
                continue
            author_user = find_user_by_id(
                db,
                str(comment.get("userId", "")),
                include_deleted=True,
            )
            result.append(
                {
                    "id": comment.get("id"),
                    "targetType": "comment",
                    "title": f"评论 @ 帖子 {comment.get('postId', '-')}",
                    "content": comment.get("content", ""),
                    "authorAlias": comment.get("authorAlias", "匿名同学"),
                    "authorUserId": str(comment.get("userId", "")),
                    "authorNickname": user_nickname(author_user),
                    "authorEmail": str(author_user.get("email", "")) if author_user else "",
                    "authorStudentId": str(author_user.get("studentId", "")) if author_user else "",
                    "createdAt": comment.get("createdAt", ""),
                    "reviewStatus": row_status,
                    "riskMarked": bool(comment.get("riskMarked", False)),
                    "deleted": bool(comment.get("deleted", False)),
                }
            )
        return result

    raise ValueError("type 仅支持 post/comment")


def build_admin_report_rows(
    db: dict[str, Any],
    *,
    status: str,
    reason: str,
) -> list[dict[str, Any]]:
    normalized_status = status.strip().lower() or "all"
    normalized_reason = reason.strip()
    rows: list[dict[str, Any]] = []
    for report in db["reports"]:
        row_status = str(report.get("status", "pending")).lower()
        if normalized_status != "all" and row_status != normalized_status:
            continue
        if normalized_reason and str(report.get("reason", "")) != normalized_reason:
            continue
        rows.append(
            {
                "id": report.get("id"),
                "targetType": report.get("targetType", "other"),
                "targetId": report.get("targetId", "unknown"),
                "reason": report.get("reason", "其他"),
                "description": report.get("description", ""),
                "status": row_status,
                "result": report.get("result", ""),
                "reporterAlias": report.get("reporterAlias", "匿名同学"),
                "createdAt": report.get("createdAt", ""),
                "handledAt": report.get("handledAt", ""),
                "handledBy": report.get("handledBy", ""),
            }
        )
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    return rows


def build_admin_user_rows(
    db: dict[str, Any],
    *,
    include_deleted: bool = True,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for user in db["users"]:
        if user.get("deleted") and not include_deleted:
            continue
        uid = str(user.get("id", ""))
        pending_cancellation = latest_account_cancellation_request_for_user(
            db,
            uid,
            status="pending",
        )
        pending_appeal = latest_pending_appeal_for_user(db, uid)
        pending_level_request = latest_user_level_request_for_user(
            db,
            uid,
            status="pending",
        )
        post_count = sum(
            1
            for post in db["posts"]
            if not post.get("deleted") and str(post.get("authorId", "")) == uid
        )
        comment_count = sum(
            1
            for comment in db["comments"]
            if not comment.get("deleted") and str(comment.get("userId", "")) == uid
        )
        report_count = sum(1 for report in db["reports"] if str(report.get("userId", "")) == uid)
        rows.append(
            {
                "id": uid,
                "email": user.get("email", ""),
                "studentId": str(user.get("studentId", "")),
                "alias": user_nickname(user),
                "avatarUrl": user_avatar_url(user),
                "verified": bool(user.get("verified", False)),
                "userLevel": current_user_level(user),
                "userLevelLabel": user_level_label(current_user_level(user)),
                "banned": bool(user.get("banned", False)),
                "muted": bool(user.get("muted", False)),
                "deleted": bool(user.get("deleted", False)),
                "postCount": post_count,
                "commentCount": comment_count,
                "reportCount": report_count,
                "createdAt": user.get("createdAt", ""),
                "hasPendingCancellationRequest": pending_cancellation is not None,
                "hasPendingAppeal": pending_appeal is not None,
                "hasPendingLevelUpgradeRequest": pending_level_request is not None,
            }
        )
    rows.sort(
        key=lambda item: (
            0 if item.get("deleted") else 1,
            str(item.get("createdAt", "")),
        ),
        reverse=True,
    )
    return rows


def build_admin_account_cancellation_rows(
    db: dict[str, Any],
    *,
    status: str,
    keyword: str,
) -> list[dict[str, Any]]:
    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for request in db.get("accountCancellationRequests", []):
        row_status = str(request.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        if normalized_keyword:
            merged = " ".join(
                [
                    str(request.get("userNickname", "")).lower(),
                    str(request.get("userEmail", "")).lower(),
                    str(request.get("studentId", "")).lower(),
                    str(request.get("reason", "")).lower(),
                    str(request.get("userId", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialize_account_cancellation_request(request))
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


def build_admin_appeal_rows(
    db: dict[str, Any],
    *,
    status: str,
    keyword: str,
) -> list[dict[str, Any]]:
    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for appeal in db.get("appeals", []):
        row_status = str(appeal.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        if normalized_keyword:
            merged = " ".join(
                [
                    str(appeal.get("userEmail", "")).lower(),
                    str(appeal.get("studentId", "")).lower(),
                    str(appeal.get("userNickname", "")).lower(),
                    str(appeal.get("appealType", "")).lower(),
                    str(appeal.get("title", "")).lower(),
                    str(appeal.get("content", "")).lower(),
                    str(appeal.get("targetId", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialize_appeal(db, appeal))
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


def build_admin_post_pin_request_rows(
    db: dict[str, Any],
    *,
    status: str,
    keyword: str,
) -> list[dict[str, Any]]:
    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for request in db.get("postPinRequests", []):
        row_status = str(request.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        serialized = serialize_admin_post_pin_request(db, request)
        if normalized_keyword:
            merged = " ".join(
                [
                    str(serialized.get("postId", "")).lower(),
                    str(serialized.get("postTitle", "")).lower(),
                    str(serialized.get("userId", "")).lower(),
                    str(serialized.get("userEmail", "")).lower(),
                    str(serialized.get("userNickname", "")).lower(),
                    str(serialized.get("reason", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialized)
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


def build_admin_user_level_request_rows(
    db: dict[str, Any],
    *,
    status: str,
    keyword: str,
) -> list[dict[str, Any]]:
    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for request in db.get("userLevelRequests", []):
        row_status = str(request.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        serialized = serialize_admin_user_level_request(db, request)
        if normalized_keyword:
            merged = " ".join(
                [
                    str(serialized.get("userId", "")).lower(),
                    str(serialized.get("userEmail", "")).lower(),
                    str(serialized.get("studentId", "")).lower(),
                    str(serialized.get("userNickname", "")).lower(),
                    str(serialized.get("reason", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialized)
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


def apply_admin_review_action(
    db: dict[str, Any],
    *,
    target_type: str,
    target_id: str,
    action: str,
) -> None:
    normalized_type = target_type.strip().lower()
    normalized_action = action.strip().lower()

    if normalized_type == "post":
        row = next((post for post in db["posts"] if post.get("id") == target_id), None)
    elif normalized_type == "comment":
        row = next((comment for comment in db["comments"] if comment.get("id") == target_id), None)
    else:
        raise ValueError("type 仅支持 post/comment")

    if row is None or row.get("deleted"):
        raise LookupError("内容不存在")

    if normalized_action == "approve":
        row["reviewStatus"] = "approved"
    elif normalized_action == "reject":
        row["reviewStatus"] = "rejected"
    elif normalized_action == "delete":
        row["deleted"] = True
        if normalized_type == "post":
            for upload in db.get("mediaUploads", []):
                if upload.get("postId") == target_id and not upload.get("deleted"):
                    upload["deleted"] = True
    elif normalized_action == "risk":
        row["riskMarked"] = True
    else:
        raise ValueError("不支持的审核动作")

    if normalized_type == "post":
        row["updatedAt"] = now_iso()


def build_export_payload(
    db: dict[str, Any],
    *,
    scope: str,
    export_format: str,
    review_type: str,
    review_status: str,
    report_status: str,
    appeal_status: str,
) -> dict[str, Any]:
    normalized_scope = scope.strip().lower() or "users"
    normalized_format = export_format.strip().lower() or "csv"

    if normalized_scope == "users":
        rows = build_admin_user_rows(db, include_deleted=True)
        file_prefix = "admin-users"
        fieldnames = [
            "id",
            "email",
            "studentId",
            "alias",
            "verified",
            "banned",
            "muted",
            "deleted",
            "postCount",
            "commentCount",
            "reportCount",
            "createdAt",
            "hasPendingCancellationRequest",
            "hasPendingAppeal",
        ]
    elif normalized_scope == "reviews":
        rows = build_admin_review_rows(
            db,
            target_type=review_type,
            status=review_status,
        )
        file_prefix = "admin-reviews"
        fieldnames = [
            "id",
            "targetType",
            "title",
            "content",
            "authorAlias",
            "authorUserId",
            "authorNickname",
            "authorEmail",
            "authorStudentId",
            "createdAt",
            "reviewStatus",
            "riskMarked",
            "deleted",
        ]
    elif normalized_scope == "reports":
        rows = build_admin_report_rows(
            db,
            status=report_status,
            reason="",
        )
        file_prefix = "admin-reports"
        fieldnames = [
            "id",
            "targetType",
            "targetId",
            "reason",
            "description",
            "status",
            "result",
            "reporterAlias",
            "createdAt",
            "handledAt",
            "handledBy",
        ]
    elif normalized_scope == "cancellations":
        rows = build_admin_account_cancellation_rows(
            db,
            status="all",
            keyword="",
        )
        file_prefix = "admin-cancellations"
        fieldnames = [
            "id",
            "userId",
            "userEmail",
            "userNickname",
            "studentId",
            "reason",
            "status",
            "statusLabel",
            "reviewNote",
            "createdAt",
            "handledAt",
            "handledBy",
        ]
    elif normalized_scope == "appeals":
        rows = build_admin_appeal_rows(
            db,
            status=appeal_status,
            keyword="",
        )
        file_prefix = "admin-appeals"
        fieldnames = [
            "id",
            "userId",
            "userEmail",
            "studentId",
            "userNickname",
            "appealType",
            "appealTypeLabel",
            "targetType",
            "targetId",
            "title",
            "content",
            "status",
            "statusLabel",
            "adminNote",
            "createdAt",
            "handledAt",
            "handledBy",
            "userDeleted",
            "userBanned",
            "userMuted",
        ]
    else:
        raise ValueError("不支持的导出范围")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    if normalized_format == "json":
        content = json.dumps(rows, ensure_ascii=False, indent=2)
        content_type = "application/json; charset=utf-8"
        extension = "json"
    elif normalized_format == "csv":
        stream = io.StringIO()
        writer = csv.DictWriter(stream, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    key: (
                        json.dumps(row.get(key), ensure_ascii=False)
                        if isinstance(row.get(key), (list, dict))
                        else row.get(key, "")
                    )
                    for key in fieldnames
                }
            )
        content = stream.getvalue()
        content_type = "text/csv; charset=utf-8"
        extension = "csv"
    else:
        raise ValueError("导出格式仅支持 csv/json")

    return {
        "fileName": f"{file_prefix}-{timestamp}.{extension}",
        "contentType": content_type,
        "content": content,
        "rowCount": len(rows),
    }


class TreeholeHandler(BaseHTTPRequestHandler):
    server_version = "XduTreeholeBackend/0.2"

    def do_OPTIONS(self) -> None:  # noqa: N802
        send_json(self, HTTPStatus.OK, {"message": "ok"})

    def do_GET(self) -> None:  # noqa: N802
        self._handle("GET")

    def do_POST(self) -> None:  # noqa: N802
        self._handle("POST")

    def do_PATCH(self) -> None:  # noqa: N802
        self._handle("PATCH")

    def do_DELETE(self) -> None:  # noqa: N802
        self._handle("DELETE")

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        return

    def _handle(self, method: str) -> None:
        try:
            parsed = urlparse(self.path)
            path = parsed.path
            query = parse_qs(parsed.query)
            if not path.startswith("/api"):
                if method == "GET":
                    self._handle_web_get(path)
                    return
                json_error(self, HTTPStatus.NOT_FOUND, "Not Found")
                return

            if method == "GET":
                self._handle_get(path, query)
                return
            if method == "POST":
                self._handle_post(path)
                return
            if method == "PATCH":
                self._handle_patch(path)
                return
            if method == "DELETE":
                self._handle_delete(path)
                return

            json_error(self, HTTPStatus.METHOD_NOT_ALLOWED, "Method not allowed")
        except Exception as error:  # pragma: no cover
            json_error(self, HTTPStatus.INTERNAL_SERVER_ERROR, f"Internal server error: {error}")

    def _handle_web_get(self, path: str) -> None:
        index_file = WEB_ROOT_DIR / "index.html"
        if not WEB_ROOT_DIR.exists() or not index_file.exists():
            json_error(
                self,
                HTTPStatus.NOT_FOUND,
                f"Web bundle not found, run flutter build web first ({WEB_ROOT_DIR})",
            )
            return

        target = resolve_web_asset_path(path)
        if target and target.exists() and target.is_file():
            send_static_file(self, target)
            return

        if should_fallback_to_spa(path):
            send_static_file(self, index_file)
            return

        json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_get(self, path: str, query: dict[str, list[str]]) -> None:
        if path == "/api/health":
            db_ok = False
            storage_ok = False
            try:
                with DB_LOCK:
                    test_db = load_db()
                    db_ok = isinstance(test_db, dict)
            except Exception:
                pass
            try:
                storage_ok = OBJECT_STORAGE.get_bytes("__health_check__") is not None or True
            except Exception:
                pass
            status = "healthy" if (db_ok and storage_ok) else "degraded"
            http_status = HTTPStatus.OK if db_ok else HTTPStatus.SERVICE_UNAVAILABLE
            send_json(self, http_status, {
                "status": status,
                "version": "XduTreeholeBackend/0.2",
                "database": "ok" if db_ok else "error",
                "smtp": "ok" if smtp_configured() else "not_configured",
                "storage": "ok" if storage_ok else "error",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })
            return

        if path == "/api/version":
            send_json(self, HTTPStatus.OK, _get_version_info())
            return

        if path.startswith("/api/storage/"):
            object_key = path[len("/api/storage/") :].strip("/")
            if not object_key:
                json_error(self, HTTPStatus.NOT_FOUND, "文件不存在")
                return
            try:
                result = OBJECT_STORAGE.get_bytes(object_key)
            except ValueError:
                json_error(self, HTTPStatus.BAD_REQUEST, "非法文件路径")
                return
            if result is None:
                json_error(self, HTTPStatus.NOT_FOUND, "文件不存在")
                return
            data, content_type = result
            send_binary(self, HTTPStatus.OK, data, content_type)
            return

        with DB_LOCK:
            db = load_db()

            if path == "/api/channels":
                send_json(self, HTTPStatus.OK, {"data": db.get("channels", DEFAULT_CHANNELS)})
                return

            if path == "/api/notifications":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                rows = [
                    serialize_notification(row)
                    for row in db.get("notifications", [])
                    if str(row.get("userId", "")).strip() == str(user.get("id", "")).strip()
                    and not row.get("deleted")
                ]
                rows.sort(key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))), reverse=True)
                unread_count = sum(1 for item in rows if not item.get("isRead"))
                send_json(
                    self,
                    HTTPStatus.OK,
                    {"data": {"items": rows, "unreadCount": unread_count}},
                )
                return

            if path == "/api/posts":
                viewer, _ = auth_user(self, db)
                viewer_user_id = str(viewer.get("id", "")) if viewer else ""
                keyword = (query.get("keyword", [""])[0] or "").strip().lower()
                channel = (query.get("channel", [""])[0] or "").strip()
                has_image = parse_bool(query.get("hasImage", [None])[0])
                allow_dm = parse_bool(query.get("allowDm", [None])[0])
                status = (query.get("status", [""])[0] or "").strip().lower()
                sort_by = (query.get("sort", ["latest"])[0] or "latest").strip().lower()
                author_id = (query.get("authorId", [""])[0] or "").strip()

                filtered_posts = []
                for post in list_posts(db, sort_by=sort_by):
                    if channel and post.get("channel") != channel:
                        continue
                    if status and str(post.get("status", "")).lower() != status:
                        continue
                    if has_image is not None and bool(post.get("hasImage", False)) != has_image:
                        continue
                    if allow_dm is not None and effective_post_allow_dm(db, post) != allow_dm:
                        continue
                    if author_id and str(post.get("authorId", "")).strip() != author_id:
                        continue

                    if keyword:
                        text = " ".join(
                            [
                                str(post.get("title", "")).lower(),
                                str(post.get("content", "")).lower(),
                                str(post.get("channel", "")).lower(),
                                " ".join(str(tag).lower() for tag in post.get("tags", [])),
                            ]
                        )
                        if keyword not in text:
                            continue

                    filtered_posts.append(post)

                filtered_posts = sort_posts_for_view(db, filtered_posts, sort_by=sort_by)

                rows = [serialize_post(db, post, viewer_user_id=viewer_user_id) for post in filtered_posts]

                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/posts/mine":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                rows = [p for p in list_posts(db, include_rejected=True) if p.get("authorId") == user["id"]]
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": [
                            serialize_post(
                                db,
                                p,
                                include_unapproved_images=True,
                                viewer_user_id=user["id"],
                            )
                            for p in rows
                        ]
                    },
                )
                return

            if path == "/api/posts/favorites":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                fav_post_ids = {f["postId"] for f in db["favorites"] if f.get("userId") == user["id"]}
                rows = [p for p in list_posts(db) if p.get("id") in fav_post_ids]
                send_json(
                    self,
                    HTTPStatus.OK,
                    {"data": [serialize_post(db, p, viewer_user_id=user["id"]) for p in rows]},
                )
                return

            if path == "/api/uploads/mine":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                rows = [
                    serialize_upload(db, row)
                    for row in db.get("mediaUploads", [])
                    if not row.get("deleted") and row.get("uploaderId") == user["id"]
                ]
                rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/comments/mine":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                result = []
                for comment in db["comments"]:
                    if comment.get("deleted"):
                        continue
                    if comment.get("userId") != user["id"]:
                        continue
                    post = next(
                        (
                            p
                            for p in db["posts"]
                            if p.get("id") == comment.get("postId") and not p.get("deleted")
                        ),
                        None,
                    )
                    result.append(
                        {
                            "id": comment.get("id"),
                            "postTitle": post.get("title") if post else "原帖",
                            "content": comment.get("content", ""),
                            "timeText": iso_to_time_text(comment.get("createdAt")),
                        }
                    )
                result.sort(key=lambda x: x.get("timeText", ""), reverse=True)
                send_json(self, HTTPStatus.OK, {"data": result})
                return

            if path == "/api/reports/mine":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                result = []
                for report in db["reports"]:
                    if report.get("userId") != user["id"]:
                        continue
                    target_type = str(report.get("targetType", "other"))
                    target_id = str(report.get("targetId", "unknown"))
                    target_title = ""
                    if target_type == "post":
                        post = next(
                            (
                                p
                                for p in db["posts"]
                                if p.get("id") == target_id and not p.get("deleted")
                            ),
                            None,
                        )
                        if post is not None:
                            target_title = str(post.get("title", "")).strip()
                    elif target_type == "comment":
                        comment = next(
                            (
                                c
                                for c in db["comments"]
                                if c.get("id") == target_id and not c.get("deleted")
                            ),
                            None,
                        )
                        if comment is not None:
                            target_title = str(comment.get("content", "")).strip()[:50]
                    result.append(
                        {
                            "id": report.get("id"),
                            "target": f"{target_type}: {target_id}",
                            "targetType": target_type,
                            "targetId": target_id,
                            "targetTitle": target_title,
                            "reason": report.get("reason", "-"),
                            "status": report.get("status", "pending"),
                            "description": report.get("description", ""),
                            "result": report.get("result", ""),
                            "createdAt": report.get("createdAt", ""),
                            "handledAt": report.get("handledAt", ""),
                        }
                    )
                result.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
                send_json(self, HTTPStatus.OK, {"data": result})
                return

            if path == "/api/messages/requests":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                requests = []
                for row in db["dmRequests"]:
                    if row.get("toUserId") != user["id"]:
                        continue
                    status = str(row.get("status", "pending")).strip().lower() or "pending"
                    from_user = find_user_by_id(db, str(row.get("fromUserId", "")))
                    from_alias = user_nickname(from_user) if from_user else sanitize_alias(
                        str(row.get("fromAlias", "")),
                        fallback="匿名同学",
                    )
                    from_avatar_url = user_avatar_url(from_user)
                    if not from_avatar_url:
                        from_avatar_url = normalize_avatar_url(str(row.get("fromAvatarUrl", "")))
                    status_label = {
                        "pending": "待处理",
                        "accepted": "已同意",
                        "rejected": "已拒绝",
                    }.get(status, status)
                    requests.append(
                        {
                            "id": row.get("id"),
                            "fromAlias": from_alias,
                            "fromAvatarUrl": from_avatar_url,
                            "reason": row.get("reason", "请求联系"),
                            "timeText": iso_to_time_text(row.get("createdAt")),
                            "status": status,
                            "statusLabel": status_label,
                            "createdAt": row.get("createdAt", ""),
                            "updatedAt": row.get("updatedAt", ""),
                        }
                    )
                requests.sort(
                    key=lambda x: x.get("updatedAt", "") or x.get("createdAt", ""),
                    reverse=True,
                )
                requests.sort(key=lambda x: 0 if x.get("status") == "pending" else 1)
                send_json(self, HTTPStatus.OK, {"data": requests})
                return

            if path == "/api/messages/conversations":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                rows = [
                    x
                    for x in db["conversations"]
                    if x.get("userId") == user["id"] and not x.get("deleted")
                ]
                rows.sort(key=lambda x: x.get("updatedAt", ""), reverse=True)
                result = []
                for row in rows:
                    peer_user_id = str(row.get("peerUserId", "")).strip()
                    peer_user = find_user_by_id(db, peer_user_id)
                    name = user_nickname(peer_user) if peer_user else sanitize_alias(
                        str(row.get("name", "")),
                        fallback="匿名同学",
                    )
                    avatar_url = user_avatar_url(peer_user)
                    if not avatar_url:
                        avatar_url = normalize_avatar_url(str(row.get("avatarUrl", "")))
                    blocked_by_me, blocked_by_peer = conversation_block_state(
                        db,
                        viewer_user_id=str(user.get("id", "")),
                        peer_user_id=peer_user_id,
                    )
                    unread_count = max(0, int(row.get("unreadCount", 0) or 0))
                    result.append(
                        {
                            "id": row.get("id"),
                            "peerUserId": peer_user_id,
                            "name": name,
                            "avatarUrl": avatar_url,
                            "lastMessage": row.get("lastMessage", "") or "开始聊天吧",
                            "timeText": iso_to_time_text(row.get("updatedAt")),
                            "unreadCount": unread_count,
                            "hasUnread": unread_count > 0,
                            "blockedByMe": blocked_by_me,
                            "blockedByPeer": blocked_by_peer,
                        }
                    )
                send_json(self, HTTPStatus.OK, {"data": result})
                return

            # POST /api/messages/conversations/direct  — 直接创建/查找会话（微信模式，无需申请）
            if method == "POST" and path == "/api/messages/conversations/direct":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                body = read_json_body(self)
                target_user_id = str(body.get("targetUserId", "")).strip()
                if not target_user_id:
                    json_error(self, HTTPStatus.BAD_REQUEST, "缺少目标用户")
                    return
                if target_user_id == user["id"]:
                    json_error(self, HTTPStatus.BAD_REQUEST, "不能给自己发私信")
                    return
                target_user = find_user_by_id(db, target_user_id)
                if target_user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "目标用户不存在")
                    return
                if is_user_blocked(db, user["id"], target_user_id):
                    json_error(self, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发私信")
                    return
                if is_user_blocked(db, target_user_id, user["id"]):
                    json_error(self, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发私信")
                    return
                now = now_iso()
                # 查找已有会话
                existing = next(
                    (
                        row
                        for row in db.get("conversations", [])
                        if row.get("userId") == user["id"]
                        and row.get("peerUserId") == target_user_id
                    ),
                    None,
                )
                if existing is not None:
                    existing["deleted"] = False
                    existing["updatedAt"] = now
                    save_db(db)
                    blocked_by_me, blocked_by_peer = conversation_block_state(
                        db,
                        viewer_user_id=str(user.get("id", "")),
                        peer_user_id=target_user_id,
                    )
                    send_json(
                        self,
                        HTTPStatus.OK,
                        {
                            "data": {
                                "id": existing.get("id", ""),
                                "peerUserId": target_user_id,
                                "name": user_nickname(target_user),
                                "avatarUrl": user_avatar_url(target_user),
                                "lastMessage": existing.get("lastMessage", "") or "开始聊天吧",
                                "timeText": iso_to_time_text(existing.get("updatedAt")),
                                "unreadCount": max(0, int(existing.get("unreadCount", 0))),
                                "hasUnread": int(existing.get("unreadCount", 0)) > 0,
                                "blockedByMe": blocked_by_me,
                                "blockedByPeer": blocked_by_peer,
                            }
                        },
                    )
                    return
                # 创建新会话
                sync_conversation_pair(
                    db,
                    left_user_id=user["id"],
                    right_user_id=target_user_id,
                    last_message="开始聊天吧",
                    updated_at=now,
                )
                new_conv = next(
                    (
                        row
                        for row in db.get("conversations", [])
                        if row.get("userId") == user["id"]
                        and row.get("peerUserId") == target_user_id
                    ),
                    None,
                )
                save_db(db)
                if new_conv:
                    send_json(
                        self,
                        HTTPStatus.CREATED,
                        {
                            "data": {
                                "id": new_conv.get("id", ""),
                                "peerUserId": target_user_id,
                                "name": user_nickname(target_user),
                                "avatarUrl": user_avatar_url(target_user),
                                "lastMessage": "开始聊天吧",
                                "timeText": iso_to_time_text(now),
                                "unreadCount": 0,
                                "hasUnread": False,
                                "blockedByMe": False,
                                "blockedByPeer": False,
                            }
                        },
                    )
                else:
                    json_error(self, HTTPStatus.INTERNAL_SERVER_ERROR, "会话创建失败")
                return

            if path == "/api/users/me/following":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": list_following_users(
                            db,
                            user_id=str(user.get("id", "")),
                            viewer_user_id=str(user.get("id", "")),
                        )
                    },
                )
                return

            if path == "/api/users/me/followers":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": list_follower_users(
                            db,
                            user_id=str(user.get("id", "")),
                            viewer_user_id=str(user.get("id", "")),
                        )
                    },
                )
                return

            if path == "/api/users/me/friends":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": list_friend_users(
                            db,
                            user_id=str(user.get("id", "")),
                        )
                    },
                )
                return

            match_conversation_messages = re.fullmatch(
                r"/api/messages/conversations/([^/]+)/messages",
                path,
            )
            if match_conversation_messages:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                conversation_id = match_conversation_messages.group(1)
                conversation = next(
                    (
                        row
                        for row in db.get("conversations", [])
                        if row.get("id") == conversation_id
                        and row.get("userId") == user["id"]
                        and not row.get("deleted")
                    ),
                    None,
                )
                if conversation is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "会话不存在")
                    return
                peer_user_id = str(conversation.get("peerUserId", "")).strip()
                if not peer_user_id:
                    send_json(self, HTTPStatus.OK, {"data": []})
                    return
                conversation_key = conversation_key_for_users(user["id"], peer_user_id)
                changed = mark_conversation_read(
                    db,
                    user_id=str(user.get("id", "")),
                    conversation=conversation,
                )
                rows = [
                    serialize_direct_message(db, row, viewer_user_id=user["id"])
                    for row in db.get("directMessages", [])
                    if not row.get("deleted")
                    and row.get("conversationKey") == conversation_key
                ]
                rows.sort(key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))))
                if changed:
                    save_db(db)
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/users/me":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                latest_cancellation_request = latest_account_cancellation_request_for_user(
                    db,
                    str(user.get("id", "")),
                )
                latest_level_request = latest_user_level_request_for_user(
                    db,
                    str(user.get("id", "")),
                )
                favorite_post_ids = {
                    str(x.get("postId", ""))
                    for x in db["favorites"]
                    if x.get("userId") == user["id"]
                }
                favorite_count = sum(
                    1
                    for post in list_posts(db)
                    if str(post.get("id", "")) in favorite_post_ids
                )
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": {
                            "alias": user_nickname(user),
                            "nickname": user_nickname(user),
                            "studentId": str(user.get("studentId", "")),
                            "avatarUrl": user_avatar_url(user),
                            "verified": bool(user.get("verified", False)),
                            "verifiedAt": user.get("verifiedAt", "-"),
                            "allowStrangerDm": bool(user.get("allowStrangerDm", True)),
                            "showContactable": bool(user.get("showContactable", True)),
                            "favoriteCount": favorite_count,
                            "isAdmin": bool(user.get("isAdmin", False)),
                            "userLevel": current_user_level(user),
                            "userLevelLabel": user_level_label(current_user_level(user)),
                            "isLevelOneUser": is_level_one_user(user),
                            "email": user.get("email", ""),
                            "levelUpgradeRequest": serialize_user_level_request_summary(
                                latest_level_request
                            ),
                            "accountCancellationRequest": serialize_account_cancellation_request(
                                latest_cancellation_request
                            )
                            if latest_cancellation_request is not None
                            else None,
                        }
                    },
                )
                return

            match_user_profile = re.fullmatch(r"/api/users/([^/]+)", path)
            if match_user_profile:
                viewer, _ = require_authorized_user(self, db)
                if viewer is None:
                    return
                target_user_id = match_user_profile.group(1)
                target_user = find_user_by_id(db, target_user_id)
                if target_user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "用户不存在")
                    return
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": serialize_public_user_profile(
                            db,
                            target_user=target_user,
                            viewer_user_id=str(viewer.get("id", "")),
                        )
                    },
                )
                return

            if path == "/api/admin/auth/me":
                admin, _ = require_admin_user(self, db)
                if admin is None:
                    return
                send_json(
                    self,
                    HTTPStatus.OK,
                    {"data": serialize_admin_auth_payload(admin)},
                )
                return

            if path == "/api/admin/overview":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                send_json(self, HTTPStatus.OK, {"data": build_overview(db)})
                return

            if path == "/api/admin/reviews":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                target_type = (query.get("type", ["post"])[0] or "post").strip().lower()
                status = (query.get("status", ["pending"])[0] or "pending").strip().lower()
                try:
                    result = build_admin_review_rows(
                        db,
                        target_type=target_type,
                        status=status,
                    )
                except ValueError:
                    json_error(self, HTTPStatus.BAD_REQUEST, "type 仅支持 post/comment")
                    return

                send_json(self, HTTPStatus.OK, {"data": result})
                return

            if path == "/api/admin/reports":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                status = (query.get("status", ["all"])[0] or "all").strip().lower()
                reason = (query.get("reason", [""])[0] or "").strip()
                rows = build_admin_report_rows(
                    db,
                    status=status,
                    reason=reason,
                )
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/admin/images/reviews":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                status = (query.get("status", ["pending"])[0] or "pending").strip().lower()
                keyword = (query.get("keyword", [""])[0] or "").strip().lower()

                rows: list[dict[str, Any]] = []
                for upload in db.get("mediaUploads", []):
                    if upload.get("deleted"):
                        continue
                    row_status = str(upload.get("status", "pending")).lower()
                    if status != "all" and row_status != status:
                        continue
                    if keyword:
                        joined = " ".join(
                            [
                                str(upload.get("fileName", "")).lower(),
                                str(upload.get("moderationReason", "")).lower(),
                                str(upload.get("uploaderId", "")).lower(),
                            ]
                        )
                        if keyword not in joined:
                            continue
                    rows.append(serialize_upload(db, upload, include_admin_fields=True))

                rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/admin/users":
                admin, _ = require_admin_user(self, db)
                if admin is None:
                    return
                rows = build_admin_user_rows(db, include_deleted=True)
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/admin/post-pin-requests":
                admin, _ = require_admin_user(self, db)
                if admin is None:
                    return
                status = (query.get("status", ["all"])[0] or "all").strip().lower()
                keyword = (query.get("keyword", [""])[0] or "").strip().lower()
                rows = build_admin_post_pin_request_rows(
                    db,
                    status=status,
                    keyword=keyword,
                )
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/admin/user-level-requests":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                status = (query.get("status", ["all"])[0] or "all").strip().lower()
                keyword = (query.get("keyword", [""])[0] or "").strip().lower()
                rows = build_admin_user_level_request_rows(
                    db,
                    status=status,
                    keyword=keyword,
                )
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/admin/admin-accounts":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                send_json(self, HTTPStatus.OK, {"data": build_admin_account_rows(db)})
                return

            if path == "/api/admin/account-cancellation-requests":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                status = (query.get("status", ["all"])[0] or "all").strip().lower()
                keyword = (query.get("keyword", [""])[0] or "").strip().lower()
                rows = build_admin_account_cancellation_rows(
                    db,
                    status=status,
                    keyword=keyword,
                )
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/admin/appeals":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                status = (query.get("status", ["all"])[0] or "all").strip().lower()
                keyword = (query.get("keyword", [""])[0] or "").strip().lower()
                rows = build_admin_appeal_rows(
                    db,
                    status=status,
                    keyword=keyword,
                )
                send_json(self, HTTPStatus.OK, {"data": rows})
                return

            if path == "/api/admin/export":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                scope = (query.get("scope", ["users"])[0] or "users").strip().lower()
                export_format = (query.get("format", ["csv"])[0] or "csv").strip().lower()
                review_type = (query.get("reviewType", ["post"])[0] or "post").strip().lower()
                review_status = (query.get("reviewStatus", ["all"])[0] or "all").strip().lower()
                report_status = (query.get("reportStatus", ["all"])[0] or "all").strip().lower()
                appeal_status = (query.get("appealStatus", ["all"])[0] or "all").strip().lower()
                try:
                    payload = build_export_payload(
                        db,
                        scope=scope,
                        export_format=export_format,
                        review_type=review_type,
                        review_status=review_status,
                        report_status=report_status,
                        appeal_status=appeal_status,
                    )
                except ValueError as error:
                    json_error(self, HTTPStatus.BAD_REQUEST, str(error))
                    return
                send_json(self, HTTPStatus.OK, {"data": payload})
                return

            if path == "/api/admin/channels-tags":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": {
                            "channels": db.get("channels", []),
                            "tags": db.get("tags", []),
                        }
                    },
                )
                return

            if path == "/api/admin/config":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": {
                            "sensitiveWords": db.get("sensitiveWords", []),
                            "settings": public_system_settings(db),
                        }
                    },
                )
                return

            if path == "/api/admin/announcements":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                rows = [
                    serialize_system_announcement(row)
                    for row in db.get("systemAnnouncements", [])
                ]
                rows.sort(key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))), reverse=True)
                send_json(self, HTTPStatus.OK, {"data": rows[:20]})
                return

            match_post_comments = re.fullmatch(r"/api/posts/([^/]+)/comments", path)
            if match_post_comments:
                post_id = match_post_comments.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                comments = []
                for comment in list_comments(db):
                    if comment.get("postId") != post_id:
                        continue
                    author_user = find_user_by_id(db, comment.get("userId", ""))
                    comments.append(
                        {
                            "id": comment.get("id"),
                            "authorAlias": comment.get("authorAlias", "匿名同学"),
                            "content": comment.get("content", ""),
                            "createdAt": comment.get("createdAt", now_iso()),
                            "likeCount": int(comment.get("likeCount", 0)),
                            "parentId": comment.get("parentId") or "",
                            "authorAvatar": user_avatar_url(author_user) if author_user else "",
                            "authorUserId": str(comment.get("userId", "")),
                        }
                    )
                comments.sort(key=lambda x: x.get("createdAt", ""))
                send_json(self, HTTPStatus.OK, {"data": comments})
                return

            match_post = re.fullmatch(r"/api/posts/([^/]+)", path)
            if match_post:
                post_id = match_post.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                if post.get("reviewStatus") == "rejected":
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                viewer, _ = auth_user(self, db)
                admin_viewer, _ = auth_admin(self, db)
                include_unapproved = bool(
                    admin_viewer
                    or (viewer and viewer.get("id") == post.get("authorId"))
                )
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": serialize_post(
                            db,
                            post,
                            include_unapproved_images=include_unapproved,
                            viewer_user_id=str(viewer.get("id", "")) if viewer else "",
                        )
                    },
                )
                return

            match_report_detail = re.fullmatch(r"/api/reports/([^/]+)", path)
            if match_report_detail:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                report_id = match_report_detail.group(1)
                report = next(
                    (
                        row
                        for row in db["reports"]
                        if row.get("id") == report_id and row.get("userId") == user["id"]
                    ),
                    None,
                )
                if report is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "举报不存在")
                    return

                target_type = str(report.get("targetType", "other"))
                target_id = str(report.get("targetId", "unknown"))
                target_title = ""
                if target_type == "post":
                    post = next(
                        (
                            p
                            for p in db["posts"]
                            if p.get("id") == target_id and not p.get("deleted")
                        ),
                        None,
                    )
                    if post is not None:
                        target_title = str(post.get("title", "")).strip()
                elif target_type == "comment":
                    comment = next(
                        (
                            c
                            for c in db["comments"]
                            if c.get("id") == target_id and not c.get("deleted")
                        ),
                        None,
                    )
                    if comment is not None:
                        target_title = str(comment.get("content", "")).strip()[:80]

                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": {
                            "id": report.get("id"),
                            "targetType": target_type,
                            "targetId": target_id,
                            "targetTitle": target_title,
                            "reason": report.get("reason", "-"),
                            "description": report.get("description", ""),
                            "status": report.get("status", "pending"),
                            "result": report.get("result", ""),
                            "createdAt": report.get("createdAt", ""),
                            "handledAt": report.get("handledAt", ""),
                        }
                    },
                )
                return

            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_post(self, path: str) -> None:
        body = read_json_body(self)

        with DB_LOCK:
            db = load_db()

            if path == "/api/admin/auth/login":
                username = normalize_admin_username(str(body.get("username", "")))
                password = str(body.get("password", "")).strip()
                if not username or not password:
                    json_error(self, HTTPStatus.BAD_REQUEST, "管理员账号和密码不能为空")
                    return

                account = find_admin_account_by_username(
                    db,
                    username,
                    include_inactive=True,
                )
                if account is None or not verify_password(
                    str(account.get("passwordHash", "")),
                    password,
                ):
                    json_error(self, HTTPStatus.UNAUTHORIZED, "管理员账号或密码错误")
                    return
                if not bool(account.get("active", True)):
                    json_error(self, HTTPStatus.FORBIDDEN, "该管理员账号已注销，请联系一级管理员")
                    return

                token = secrets.token_urlsafe(24)
                with ADMIN_SESSION_LOCK:
                    ADMIN_SESSIONS[token] = str(account.get("id", "")).strip()
                admin_payload = build_authenticated_admin(account)
                add_audit_log(
                    db,
                    "",
                    "admin_login",
                    f"管理员登录:{account.get('username', '')}:{admin_payload.get('role', '')}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": {
                            "token": token,
                            **serialize_admin_auth_payload(admin_payload),
                        }
                    },
                )
                return

            if path == "/api/admin/auth/logout":
                admin, token = require_admin_user(self, db)
                if admin is None:
                    return
                if token:
                    with ADMIN_SESSION_LOCK:
                        ADMIN_SESSIONS.pop(token, None)
                add_audit_log(db, "", "admin_logout", f"管理员退出: {admin.get('username', '')}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "管理员已退出", "data": {"ok": True}})
                return

            if path == "/api/admin/admin-accounts":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                username = normalize_admin_username(str(body.get("username", "")))
                password = str(body.get("password", "")).strip()
                if not is_valid_admin_username(username):
                    json_error(
                        self,
                        HTTPStatus.BAD_REQUEST,
                        "管理员账号仅支持 3-32 位字母、数字、下划线、点和中划线",
                    )
                    return
                if len(password) < 6:
                    json_error(self, HTTPStatus.BAD_REQUEST, "管理员密码长度至少 6 位")
                    return
                if find_admin_account_by_username(db, username, include_inactive=True) is not None:
                    json_error(self, HTTPStatus.BAD_REQUEST, "该管理员账号已存在")
                    return

                created_at = now_iso()
                account = build_admin_account(
                    admin_id=next_id(db, "adminAccount", "adm"),
                    username=username,
                    password_hash=hash_password(password),
                    role=ADMIN_ROLE_SECONDARY,
                    active=True,
                    created_at=created_at,
                    updated_at=created_at,
                    created_by=str(admin.get("username", "")).strip(),
                )
                db.setdefault("adminAccounts", []).append(account)
                add_audit_log(
                    db,
                    "",
                    "admin_create_secondary_account",
                    f"{admin.get('username', '')}:{username}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.CREATED,
                    {"message": "二级管理员已创建", "data": serialize_admin_account(account)},
                )
                return

            if path in {"/api/auth/send-code", "/api/auth/resend-code"}:
                email = str(body.get("email", "")).strip().lower()
                if not is_campus_email(email):
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
                    return
                smtp_enabled = smtp_configured()
                code = random_code() if smtp_enabled else "123456"
                if smtp_enabled:
                    try:
                        send_verification_email(to_email=email, code=code, expires_in_minutes=10)
                    except Exception as error:
                        json_error(
                            self,
                            HTTPStatus.SERVICE_UNAVAILABLE,
                            verification_send_error_message(error),
                        )
                        return
                db["emailCodes"][email] = {
                    "code": code,
                    "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
                }
                save_db(db)
                data: dict[str, Any] = {
                    "email": email,
                    "expiresInSeconds": 600,
                }
                if INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled:
                    data["debugCode"] = code
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "验证码已发送" if smtp_enabled else "邮件服务未配置，已启用内测验证码",
                        "data": data,
                    },
                )
                return

            if path == "/api/auth/password/send-code":
                email = str(body.get("email", "")).strip().lower()
                if not is_campus_email(email):
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
                    return
                user = find_user_by_email(db, email, include_deleted=True)
                if user is not None and user.get("deleted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
                    return
                if user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
                    return
                smtp_enabled = smtp_configured()
                code = random_code() if smtp_enabled else "123456"
                if smtp_enabled:
                    try:
                        send_password_reset_email(to_email=email, code=code, expires_in_minutes=10)
                    except Exception as error:
                        json_error(
                            self,
                            HTTPStatus.SERVICE_UNAVAILABLE,
                            verification_send_error_message(error),
                        )
                        return
                db["emailCodes"][password_reset_code_key(email)] = {
                    "code": code,
                    "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
                }
                save_db(db)
                data: dict[str, Any] = {
                    "email": email,
                    "expiresInSeconds": 600,
                }
                if INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled:
                    data["debugCode"] = code
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "重置密码验证码已发送"
                        if smtp_enabled
                        else "邮件服务未配置，已启用内测验证码",
                        "data": data,
                    },
                )
                return

            if path == "/api/auth/password/reset":
                email = str(body.get("email", "")).strip().lower()
                code = str(body.get("code", "")).strip()
                new_password = str(body.get("newPassword", "")).strip()
                if not is_campus_email(email):
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
                    return
                if len(code) != 6:
                    json_error(self, HTTPStatus.BAD_REQUEST, "验证码格式错误")
                    return
                if len(new_password) < 6:
                    json_error(self, HTTPStatus.BAD_REQUEST, "新密码长度至少 6 位")
                    return

                user = find_user_by_email(db, email, include_deleted=True)
                if user is not None and user.get("deleted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
                    return
                if user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
                    return

                code_row = db["emailCodes"].get(password_reset_code_key(email))
                if not code_row:
                    json_error(self, HTTPStatus.BAD_REQUEST, "请先发送重置验证码")
                    return
                if code_row.get("code") != code and not (verify_code_debug_enabled() and code == "123456"):
                    json_error(self, HTTPStatus.BAD_REQUEST, "验证码错误")
                    return

                expires_at = parse_iso(code_row.get("expiresAt", ""))
                if expires_at is None or now_utc() > expires_at:
                    json_error(self, HTTPStatus.BAD_REQUEST, "验证码已过期")
                    return

                user["password"] = hash_password(new_password)
                db["emailCodes"].pop(password_reset_code_key(email), None)
                add_audit_log(db, user["id"], "reset_password_by_email", f"邮箱重置密码 {email}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "密码重置成功", "data": {"ok": True}})
                return

            if path == "/api/auth/login":
                identifier = (
                    str(
                        body.get(
                            "identifier",
                            body.get("studentId", body.get("email", "")),
                        )
                    )
                    .strip()
                )
                password = str(body.get("password", "")).strip()
                login_email = ""
                login_student_id = ""
                user: dict[str, Any] | None = None

                if "@" in identifier:
                    login_email = identifier.lower()
                    if not is_campus_email(login_email):
                        json_error(self, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
                        return
                    user = find_user_by_email(db, login_email, include_deleted=True)
                else:
                    login_student_id = identifier
                    if not is_valid_student_id(login_student_id):
                        json_error(self, HTTPStatus.BAD_REQUEST, "请输入有效学号")
                        return
                    user = find_user_by_student_id(db, login_student_id, include_deleted=True)
                    if user is not None:
                        login_email = str(user.get("email", "")).strip().lower()
                if not password:
                    json_error(self, HTTPStatus.BAD_REQUEST, "密码不能为空")
                    return

                if user is not None and user.get("deleted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
                    return
                if user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
                    return
                if not login_email:
                    login_email = str(user.get("email", "")).strip().lower()
                if not login_student_id:
                    login_student_id = str(user.get("studentId", "")).strip() or student_id_from_email(login_email)

                stored_password = str(user.get("password", ""))
                if not stored_password:
                    json_error(self, HTTPStatus.UNAUTHORIZED, "账号未设置密码，请先注册")
                    return
                if not verify_password(stored_password, password):
                    json_error(self, HTTPStatus.UNAUTHORIZED, "账号或密码错误")
                    return
                if not is_password_hashed(stored_password):
                    user["password"] = hash_password(password)

                if user.get("banned"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已被封禁")
                    return

                if not user.get("verified", False):
                    if login_email not in db["emailCodes"]:
                        smtp_enabled = smtp_configured()
                        code = random_code() if smtp_enabled else "123456"
                        if smtp_enabled:
                            try:
                                send_verification_email(to_email=login_email, code=code, expires_in_minutes=10)
                            except Exception as error:
                                json_error(
                                    self,
                                    HTTPStatus.SERVICE_UNAVAILABLE,
                                    verification_send_error_message(error),
                                )
                                return
                        db["emailCodes"][login_email] = {
                            "code": code,
                            "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
                        }
                    save_db(db)
                    response_data: dict[str, Any] = {
                        "verified": False,
                        "needVerify": True,
                        "email": login_email,
                        "studentId": login_student_id,
                    }
                    if not smtp_configured() or INCLUDE_DEBUG_CODE_IN_RESPONSE:
                        current_code = (
                            str(db["emailCodes"].get(login_email, {}).get("code", "")).strip()
                            or "123456"
                        )
                        response_data["debugCode"] = current_code
                    send_json(self, HTTPStatus.OK, {"data": response_data})
                    return

                token = secrets.token_urlsafe(24)
                db["sessions"][token] = user["id"]
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": {
                            "token": token,
                            "verified": True,
                            "isAdmin": bool(user.get("isAdmin", False)),
                            "email": login_email,
                            "studentId": login_student_id,
                        }
                    },
                )
                return

            if path == "/api/auth/register":
                email = str(body.get("email", "")).strip().lower()
                password = str(body.get("password", "")).strip()
                nickname = sanitize_alias(str(body.get("nickname", "")), fallback="")
                student_id = student_id_from_email(email)
                avatar_url = normalize_avatar_url(str(body.get("avatarUrl", "")))
                avatar_data_base64 = str(body.get("avatarDataBase64", "")).strip()
                avatar_file_name = str(body.get("avatarFileName", "avatar.png")).strip() or "avatar.png"
                avatar_content_type = str(body.get("avatarContentType", "")).strip().lower()

                if not is_campus_email(email):
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
                    return
                if len(password) < 6:
                    json_error(self, HTTPStatus.BAD_REQUEST, "密码长度至少 6 位")
                    return
                if not nickname:
                    json_error(self, HTTPStatus.BAD_REQUEST, "昵称不能为空")
                    return
                if not is_valid_student_id(student_id):
                    json_error(self, HTTPStatus.BAD_REQUEST, "邮箱前缀不符合学号格式（需为 6-20 位字母或数字）")
                    return

                user = find_user_by_email(db, email, include_deleted=True)
                if user is not None and user.get("deleted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
                    return
                if user is not None and user.get("verified"):
                    json_error(self, HTTPStatus.CONFLICT, "账号已存在，请直接登录")
                    return
                existing_student = find_user_by_student_id(db, student_id, include_deleted=False)
                if existing_student is not None and str(existing_student.get("email", "")).strip().lower() != email:
                    json_error(self, HTTPStatus.CONFLICT, "该学号已绑定其他账号")
                    return

                uploaded_avatar_key = ""
                if avatar_data_base64:
                    try:
                        avatar_bytes = decode_base64_payload(avatar_data_base64)
                    except Exception:
                        json_error(self, HTTPStatus.BAD_REQUEST, "头像图片数据格式错误")
                        return
                    if not avatar_bytes:
                        json_error(self, HTTPStatus.BAD_REQUEST, "头像图片不能为空")
                        return
                    detected_content_type = detect_image_type(avatar_bytes)
                    if detected_content_type is None:
                        json_error(self, HTTPStatus.BAD_REQUEST, "仅支持 jpg/png/webp/gif 图片")
                        return
                    avatar_ct = detected_content_type
                    if avatar_content_type and avatar_content_type in ALLOWED_IMAGE_TYPES:
                        avatar_ct = avatar_content_type

                    max_bytes = get_image_max_bytes(db)
                    if len(avatar_bytes) > max_bytes:
                        json_error(
                            self,
                            HTTPStatus.BAD_REQUEST,
                            f"头像图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）",
                        )
                        return
                    try:
                        stored_avatar = OBJECT_STORAGE.put_bytes(
                            data=avatar_bytes,
                            file_name=avatar_file_name,
                            content_type=avatar_ct,
                        )
                    except Exception:
                        json_error(self, HTTPStatus.INTERNAL_SERVER_ERROR, "头像上传失败，请稍后重试")
                        return
                    avatar_url = stored_avatar.url
                    uploaded_avatar_key = stored_avatar.key

                old_avatar_key = ""
                if user is not None:
                    old_avatar_key = extract_local_object_key_from_url(normalize_avatar_url(str(user.get("avatarUrl", ""))))

                if user is None:
                    user = {
                        "id": next_id(db, "user", "u"),
                        "email": email,
                        "password": hash_password(password),
                        "alias": nickname,
                        "nickname": nickname,
                        "studentId": student_id,
                        "avatarUrl": avatar_url,
                        "userLevel": USER_LEVEL_TWO,
                        "verified": False,
                        "verifiedAt": "",
                        "allowStrangerDm": True,
                        "showContactable": True,
                        "createdAt": now_iso(),
                        "deleted": False,
                        "isAdmin": False,
                        "banned": False,
                        "muted": False,
                    }
                    db["users"].append(user)
                else:
                    user["password"] = hash_password(password)
                    user["alias"] = nickname
                    user["nickname"] = nickname
                    user["studentId"] = student_id
                    user["avatarUrl"] = avatar_url

                smtp_enabled = smtp_configured()
                code = random_code() if smtp_enabled else "123456"
                if smtp_enabled:
                    try:
                        send_verification_email(to_email=email, code=code, expires_in_minutes=10)
                    except Exception as error:
                        json_error(
                            self,
                            HTTPStatus.SERVICE_UNAVAILABLE,
                            verification_send_error_message(error),
                        )
                        return
                db["emailCodes"][email] = {
                    "code": code,
                    "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
                }

                save_db(db)
                if old_avatar_key and uploaded_avatar_key and old_avatar_key != uploaded_avatar_key:
                    try:
                        OBJECT_STORAGE.delete(old_avatar_key)
                    except Exception:
                        pass
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "注册成功，请完成邮箱验证"
                        if smtp_enabled
                        else "注册成功，邮件服务未配置，内测验证码为 123456",
                        "data": {
                            "needVerify": True,
                            "verified": False,
                            "email": email,
                            "studentId": student_id,
                            **(
                                {"debugCode": code}
                                if (INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled)
                                else {}
                            ),
                        },
                    },
                )
                return

            if path == "/api/auth/verify":
                email = str(body.get("email", "")).strip().lower()
                code = str(body.get("code", "")).strip()
                password = str(body.get("password", "")).strip()

                if not is_campus_email(email):
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
                    return
                if len(code) != 6:
                    json_error(self, HTTPStatus.BAD_REQUEST, "验证码格式错误")
                    return

                code_row = db["emailCodes"].get(email)
                if not code_row:
                    json_error(self, HTTPStatus.BAD_REQUEST, "请先发送验证码")
                    return
                if code_row.get("code") != code and not (verify_code_debug_enabled() and code == "123456"):
                    json_error(self, HTTPStatus.BAD_REQUEST, "验证码错误")
                    return

                expires_at = parse_iso(code_row.get("expiresAt", ""))
                if expires_at is None or now_utc() > expires_at:
                    json_error(self, HTTPStatus.BAD_REQUEST, "验证码已过期")
                    return

                user = find_user_by_email(db, email, include_deleted=True)
                if user is not None and user.get("deleted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
                    return
                if user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
                    return

                if password:
                    user["password"] = hash_password(password)
                user["verified"] = True
                user["verifiedAt"] = now_iso()
                user["nickname"] = user_nickname(user)
                user["alias"] = user_nickname(user)
                user["studentId"] = str(user.get("studentId", "")).strip() or student_id_from_email(email)
                user["avatarUrl"] = normalize_avatar_url(str(user.get("avatarUrl", "")))

                db["emailCodes"].pop(email, None)
                token = secrets.token_urlsafe(24)
                db["sessions"][token] = user["id"]
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": {
                            "token": token,
                            "verified": True,
                            "isAdmin": bool(user.get("isAdmin", False)),
                        }
                    },
                )
                return

            if path == "/api/auth/logout":
                user, token = auth_user(self, db)
                if token:
                    db["sessions"].pop(token, None)
                if user:
                    add_audit_log(db, user.get("id", "-"), "logout", "用户退出登录")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "已退出登录", "data": {"ok": True}})
                return

            if path == "/api/notifications/read-all":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                read_at = now_iso()
                changed = False
                for row in db.get("notifications", []):
                    if str(row.get("userId", "")).strip() != str(user.get("id", "")).strip():
                        continue
                    if row.get("deleted"):
                        continue
                    if str(row.get("readAt", "")).strip():
                        continue
                    row["readAt"] = read_at
                    changed = True
                if changed:
                    save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "已全部标记为已读", "data": {"ok": True}})
                return

            match_notification_read = re.fullmatch(r"/api/notifications/([^/]+)/read", path)
            if match_notification_read:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                notification_id = match_notification_read.group(1)
                row = next(
                    (
                        item
                        for item in db.get("notifications", [])
                        if item.get("id") == notification_id
                        and str(item.get("userId", "")).strip() == str(user.get("id", "")).strip()
                        and not item.get("deleted")
                    ),
                    None,
                )
                if row is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "通知不存在")
                    return
                if not str(row.get("readAt", "")).strip():
                    row["readAt"] = now_iso()
                    save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "已标记为已读", "data": serialize_notification(row)})
                return

            if path == "/api/messages/requests":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                if user.get("muted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法发起私信")
                    return
                allowed, retry_after = consume_rate_limit(
                    db,
                    user_id=user["id"],
                    action="dm_request",
                    setting_key="dmRequestRateLimit",
                    default_limit=DEFAULT_SETTINGS["dmRequestRateLimit"],
                )
                if not allowed:
                    send_rate_limit_error(
                        self,
                        action_text="发起私信",
                        retry_after_seconds=retry_after,
                    )
                    return

                post_id = str(body.get("postId", "")).strip()
                target_user_id = str(body.get("targetUserId", "")).strip()
                reason = str(body.get("reason", "")).strip()
                if len(reason) > 120:
                    json_error(self, HTTPStatus.BAD_REQUEST, "私信申请理由不能超过 120 个字符")
                    return

                post = None
                if post_id:
                    post = next(
                        (
                            row
                            for row in db.get("posts", [])
                            if row.get("id") == post_id and not row.get("deleted")
                        ),
                        None,
                    )
                    if post is None or str(post.get("reviewStatus", "approved")).lower() == "rejected":
                        json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                        return
                    if is_post_anonymous(db, post):
                        json_error(self, HTTPStatus.BAD_REQUEST, "匿名帖子不支持通过帖子发起私信")
                        return
                    if not effective_post_allow_dm(db, post):
                        json_error(self, HTTPStatus.BAD_REQUEST, "该帖子未开启私信")
                        return
                    target_user_id = str(post.get("authorId", "")).strip()

                if not target_user_id:
                    json_error(self, HTTPStatus.BAD_REQUEST, "缺少联系对象")
                    return
                if target_user_id == user["id"]:
                    json_error(self, HTTPStatus.BAD_REQUEST, "不能给自己发送私信申请")
                    return

                target_user = find_user_by_id(db, target_user_id)
                if target_user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "联系对象不存在")
                    return
                if not can_request_dm_to_user(
                    db,
                    viewer_user_id=str(user.get("id", "")),
                    target_user_id=target_user_id,
                ):
                    if not bool(target_user.get("showContactable", True)):
                        json_error(self, HTTPStatus.FORBIDDEN, "对方当前未开放联系入口")
                        return
                    if not bool(target_user.get("allowStrangerDm", True)):
                        json_error(self, HTTPStatus.FORBIDDEN, "对方暂不接受私信")
                        return
                    if is_user_blocked(db, user["id"], target_user_id):
                        json_error(self, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发起私信")
                        return
                    if is_user_blocked(db, target_user_id, user["id"]):
                        json_error(self, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发起私信")
                        return
                    json_error(self, HTTPStatus.FORBIDDEN, "当前无法发起私信")
                    return

                existing_conversation = next(
                    (
                        row
                        for row in db.get("conversations", [])
                        if row.get("userId") == user["id"]
                        and row.get("peerUserId") == target_user_id
                    ),
                    None,
                )
                if existing_conversation is not None:
                    existing_conversation["deleted"] = False
                    existing_conversation["updatedAt"] = now_iso()
                    save_db(db)
                    send_json(
                        self,
                        HTTPStatus.OK,
                        {
                            "message": "你们已经可以直接私信了",
                            "data": {
                                "conversationId": existing_conversation.get("id", ""),
                                "alreadyAvailable": True,
                            },
                        },
                    )
                    return

                existing_pending = next(
                    (
                        row
                        for row in db.get("dmRequests", [])
                        if row.get("toUserId") == target_user_id
                        and row.get("fromUserId") == user["id"]
                        and str(row.get("status", "pending")).lower() == "pending"
                    ),
                    None,
                )
                if existing_pending is not None:
                    send_json(
                        self,
                        HTTPStatus.OK,
                        {
                            "message": "私信申请已发送，请等待对方处理",
                            "data": existing_pending,
                        },
                    )
                    return

                created_at = now_iso()
                request = {
                    "id": next_id(db, "request", "req"),
                    "toUserId": target_user_id,
                    "fromAlias": user_nickname(user),
                    "fromUserId": user["id"],
                    "fromAvatarUrl": user_avatar_url(user),
                    "reason": reason or "想和你继续交流这个话题",
                    "createdAt": created_at,
                    "updatedAt": created_at,
                    "status": "pending",
                }
                db["dmRequests"].append(request)
                add_audit_log(
                    db,
                    user["id"],
                    "create_dm_request",
                    f"to={target_user_id} post={post_id or '-'}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "私信申请已发送",
                        "data": request,
                    },
                )
                return

            if path == "/api/uploads/images":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                if user.get("banned"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已被封禁")
                    return
                allowed, retry_after = consume_rate_limit(
                    db,
                    user_id=user["id"],
                    action="upload",
                    setting_key="uploadRateLimit",
                    default_limit=DEFAULT_SETTINGS["uploadRateLimit"],
                )
                if not allowed:
                    send_rate_limit_error(
                        self,
                        action_text="图片上传",
                        retry_after_seconds=retry_after,
                    )
                    return

                ip_allowed, ip_retry_after = check_ip_rate_limit(self, "upload")
                if not ip_allowed:
                    send_rate_limit_error(
                        self,
                        action_text="图片上传",
                        retry_after_seconds=ip_retry_after,
                    )
                    return

                file_name = str(body.get("fileName", "upload.bin")).strip() or "upload.bin"
                data_base64 = str(body.get("dataBase64", "")).strip()
                client_content_type = str(body.get("contentType", "")).strip().lower()
                if not data_base64:
                    json_error(self, HTTPStatus.BAD_REQUEST, "缺少图片数据")
                    return

                try:
                    image_bytes = decode_base64_payload(data_base64)
                except Exception:
                    json_error(self, HTTPStatus.BAD_REQUEST, "图片数据格式错误")
                    return

                if not image_bytes:
                    json_error(self, HTTPStatus.BAD_REQUEST, "图片不能为空")
                    return

                detected_content_type = detect_image_type(image_bytes)
                if detected_content_type is None:
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持 jpg/png/webp/gif 图片")
                    return
                content_type = detected_content_type
                if client_content_type and client_content_type in ALLOWED_IMAGE_TYPES:
                    content_type = client_content_type

                sha256_hex = calc_sha256_hex(image_bytes)
                status, moderation_reason = moderate_image_upload(
                    file_name=file_name,
                    content_type=content_type,
                    size_bytes=len(image_bytes),
                    db=db,
                )
                same_hash_count = sum(
                    1
                    for row in db.get("mediaUploads", [])
                    if not row.get("deleted")
                    and row.get("uploaderId") == user["id"]
                    and row.get("sha256") == sha256_hex
                )
                if status == "rejected":
                    json_error(self, HTTPStatus.BAD_REQUEST, moderation_reason)
                    return

                try:
                    stored = OBJECT_STORAGE.put_bytes(
                        data=image_bytes,
                        file_name=file_name,
                        content_type=content_type,
                    )
                except Exception:
                    json_error(self, HTTPStatus.INTERNAL_SERVER_ERROR, "对象存储写入失败")
                    return

                upload = {
                    "id": next_id(db, "upload", "img"),
                    "objectKey": stored.key,
                    "url": stored.url,
                    "uploaderId": user["id"],
                    "fileName": file_name,
                    "contentType": content_type,
                    "sizeBytes": stored.size_bytes,
                    "sha256": sha256_hex,
                    "status": status,
                    "moderationReason": moderation_reason,
                    "reviewNote": "",
                    "reviewedBy": "",
                    "reviewedAt": "",
                    "createdAt": now_iso(),
                    "postId": "",
                    "deleted": False,
                }
                db["mediaUploads"].append(upload)
                if status == "risk":
                    add_audit_log(db, user["id"], "risk_mark_upload", f"{upload['id']}:{moderation_reason}")
                add_audit_log(db, user["id"], "upload_image", f"{upload['id']}:{upload['status']}")
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {"message": "图片上传成功，可直接发帖", "data": serialize_upload(db, upload)},
                )
                return

            if path == "/api/users/avatar":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return

                file_name = str(body.get("fileName", "avatar.png")).strip() or "avatar.png"
                data_base64 = str(body.get("dataBase64", "")).strip()
                client_content_type = str(body.get("contentType", "")).strip().lower()
                if not data_base64:
                    json_error(self, HTTPStatus.BAD_REQUEST, "缺少头像图片数据")
                    return

                try:
                    image_bytes = decode_base64_payload(data_base64)
                except Exception:
                    json_error(self, HTTPStatus.BAD_REQUEST, "头像图片数据格式错误")
                    return

                if not image_bytes:
                    json_error(self, HTTPStatus.BAD_REQUEST, "头像图片不能为空")
                    return

                detected_content_type = detect_image_type(image_bytes)
                if detected_content_type is None:
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持 jpg/png/webp/gif 图片")
                    return
                content_type = detected_content_type
                if client_content_type and client_content_type in ALLOWED_IMAGE_TYPES:
                    content_type = client_content_type

                max_bytes = get_image_max_bytes(db)
                if len(image_bytes) > max_bytes:
                    json_error(
                        self,
                        HTTPStatus.BAD_REQUEST,
                        f"头像图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）",
                    )
                    return

                old_avatar_url = normalize_avatar_url(str(user.get("avatarUrl", "")))
                old_object_key = extract_local_object_key_from_url(old_avatar_url)

                try:
                    stored = OBJECT_STORAGE.put_bytes(
                        data=image_bytes,
                        file_name=file_name,
                        content_type=content_type,
                    )
                except Exception:
                    json_error(self, HTTPStatus.INTERNAL_SERVER_ERROR, "头像上传失败，请稍后重试")
                    return

                user["avatarUrl"] = stored.url
                user["alias"] = user_nickname(user)
                add_audit_log(db, user["id"], "upload_avatar", "上传头像")
                save_db(db)

                if old_object_key and old_object_key != stored.key:
                    try:
                        OBJECT_STORAGE.delete(old_object_key)
                    except Exception:
                        pass

                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "头像上传成功",
                        "data": {
                            "avatarUrl": stored.url,
                        },
                    },
                )
                return

            if path == "/api/users/me/cancellation-request":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                if str(user.get("email", "")).strip().lower() == DEMO_USER_EMAIL:
                    json_error(self, HTTPStatus.BAD_REQUEST, "演示账号不可注销")
                    return

                pending_request = latest_account_cancellation_request_for_user(
                    db,
                    str(user.get("id", "")),
                    status="pending",
                )
                if pending_request is not None:
                    json_error(self, HTTPStatus.CONFLICT, "你已提交过注销申请，请等待管理员审核")
                    return

                reason = str(body.get("reason", "")).strip()
                request = {
                    "id": next_id(db, "cancellation", "acr"),
                    "userId": user["id"],
                    "userEmail": str(user.get("email", "")).strip().lower(),
                    "userNickname": user_nickname(user),
                    "studentId": str(user.get("studentId", "")).strip(),
                    "avatarUrl": user_avatar_url(user),
                    "reason": reason,
                    "status": "pending",
                    "reviewNote": "",
                    "createdAt": now_iso(),
                    "handledAt": "",
                    "handledBy": "",
                }
                db.setdefault("accountCancellationRequests", []).append(request)
                add_audit_log(db, user["id"], "submit_account_cancellation", request["id"])
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "注销申请已提交，等待管理员审核",
                        "data": serialize_account_cancellation_request(request),
                    },
                )
                return

            if path == "/api/users/me/level-upgrade-request":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                if is_level_one_user(user):
                    json_error(self, HTTPStatus.BAD_REQUEST, "你当前已经是一级用户")
                    return
                pending_request = latest_user_level_request_for_user(
                    db,
                    str(user.get("id", "")),
                    status="pending",
                )
                if pending_request is not None:
                    json_error(self, HTTPStatus.CONFLICT, "你已提交过升级申请，请等待一级管理员审核")
                    return
                reason = str(body.get("reason", "")).strip()
                request = {
                    "id": next_id(db, "levelRequest", "lvl"),
                    "userId": str(user.get("id", "")).strip(),
                    "currentLevel": current_user_level(user),
                    "targetLevel": USER_LEVEL_ONE,
                    "reason": reason,
                    "status": "pending",
                    "adminNote": "",
                    "createdAt": now_iso(),
                    "handledAt": "",
                    "handledBy": "",
                }
                db.setdefault("userLevelRequests", []).append(request)
                add_audit_log(db, user["id"], "submit_user_level_upgrade_request", request["id"])
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.CREATED,
                    {
                        "message": "一级用户申请已提交，请等待一级管理员审核",
                        "data": serialize_user_level_request_summary(request),
                    },
                )
                return

            match_follow_user = re.fullmatch(r"/api/users/([^/]+)/(follow|unfollow)", path)
            if match_follow_user:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                target_user_id = match_follow_user.group(1)
                action = match_follow_user.group(2)
                if target_user_id == user["id"]:
                    json_error(self, HTTPStatus.BAD_REQUEST, "不能关注自己")
                    return
                target_user = find_user_by_id(db, target_user_id)
                if target_user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "用户不存在")
                    return

                if action == "follow":
                    if not is_user_following(db, user["id"], target_user_id):
                        db.setdefault("userFollows", []).append(
                            {
                                "followerUserId": user["id"],
                                "followeeUserId": target_user_id,
                                "createdAt": now_iso(),
                            }
                        )
                        add_audit_log(db, user["id"], "follow_user", target_user_id)
                        save_db(db)
                    send_json(
                        self,
                        HTTPStatus.OK,
                        {
                            "message": "关注成功",
                            "data": {
                                "userId": target_user_id,
                                "following": True,
                            },
                        },
                    )
                    return

                before_len = len(db.get("userFollows", []))
                db["userFollows"] = [
                    row
                    for row in db.get("userFollows", [])
                    if not (
                        str(row.get("followerUserId", "")).strip() == str(user.get("id", "")).strip()
                        and str(row.get("followeeUserId", "")).strip() == target_user_id
                    )
                ]
                if len(db["userFollows"]) != before_len:
                    add_audit_log(db, user["id"], "unfollow_user", target_user_id)
                    save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "已取消关注",
                        "data": {
                            "userId": target_user_id,
                            "following": False,
                        },
                    },
                )
                return

            if path == "/api/appeals":
                email = str(body.get("email", "")).strip().lower()
                student_id = str(body.get("studentId", "")).strip()
                title = str(body.get("title", "")).strip()
                content = str(body.get("content", "")).strip()
                appeal_type = str(body.get("appealType", "account_restore")).strip().lower() or "other"
                target_type = str(body.get("targetType", "user")).strip().lower()
                target_id = str(body.get("targetId", "")).strip()

                if not is_campus_email(email):
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
                    return
                if student_id and not is_valid_student_id(student_id):
                    json_error(self, HTTPStatus.BAD_REQUEST, "学号格式不合法")
                    return
                if not title:
                    json_error(self, HTTPStatus.BAD_REQUEST, "申诉标题不能为空")
                    return
                if not content:
                    json_error(self, HTTPStatus.BAD_REQUEST, "申诉内容不能为空")
                    return
                if len(title) > 80:
                    json_error(self, HTTPStatus.BAD_REQUEST, "申诉标题不能超过 80 个字符")
                    return
                if len(content) > 4000:
                    json_error(self, HTTPStatus.BAD_REQUEST, "申诉内容不能超过 4000 个字符")
                    return

                user = find_user_by_email(db, email, include_deleted=True)
                if user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "账号不存在")
                    return
                resolved_student_id = str(user.get("studentId", "")).strip()
                if student_id and resolved_student_id and student_id != resolved_student_id:
                    json_error(self, HTTPStatus.BAD_REQUEST, "学号与账号信息不匹配")
                    return

                existing = latest_pending_appeal_for_user(
                    db,
                    str(user.get("id", "")),
                    appeal_type=appeal_type,
                )
                if existing is not None:
                    json_error(self, HTTPStatus.CONFLICT, "你已有同类型待处理申诉，请等待管理员处理")
                    return

                appeal = {
                    "id": next_id(db, "appeal", "apl"),
                    "userId": str(user.get("id", "")),
                    "userEmail": email,
                    "studentId": resolved_student_id or student_id,
                    "userNickname": user_nickname(user),
                    "appealType": appeal_type,
                    "targetType": target_type,
                    "targetId": target_id,
                    "title": title,
                    "content": content,
                    "status": "pending",
                    "adminNote": "",
                    "createdAt": now_iso(),
                    "handledAt": "",
                    "handledBy": "",
                }
                db.setdefault("appeals", []).append(appeal)
                add_audit_log(
                    db,
                    str(user.get("id", "")),
                    "submit_appeal",
                    f"{appeal['id']}:{appeal_type}:{target_type}:{target_id}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "申诉已提交，等待管理员处理",
                        "data": serialize_appeal(db, appeal),
                    },
                )
                return

            if path == "/api/admin/announcements":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                title = str(body.get("title", "")).strip()
                content = str(body.get("content", "")).strip()
                if not title:
                    json_error(self, HTTPStatus.BAD_REQUEST, "公告标题不能为空")
                    return
                if not content:
                    json_error(self, HTTPStatus.BAD_REQUEST, "公告内容不能为空")
                    return
                if len(title) > 80:
                    json_error(self, HTTPStatus.BAD_REQUEST, "公告标题不能超过 80 个字符")
                    return
                if len(content) > 2000:
                    json_error(self, HTTPStatus.BAD_REQUEST, "公告内容不能超过 2000 个字符")
                    return
                announcement = publish_system_announcement(
                    db,
                    admin=admin,
                    title=title,
                    content=content,
                )
                add_audit_log(db, admin["id"], "admin_publish_announcement", announcement["id"])
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "系统公告已发布",
                        "data": serialize_system_announcement(announcement),
                    },
                )
                return

            match_conversation_send = re.fullmatch(
                r"/api/messages/conversations/([^/]+)/messages",
                path,
            )
            if match_conversation_send:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                if user.get("muted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法发送私信")
                    return
                allowed, retry_after = consume_rate_limit(
                    db,
                    user_id=user["id"],
                    action="message",
                    setting_key="messageRateLimit",
                    default_limit=DEFAULT_SETTINGS["messageRateLimit"],
                )
                if not allowed:
                    send_rate_limit_error(
                        self,
                        action_text="发送私信",
                        retry_after_seconds=retry_after,
                    )
                    return

                ip_allowed, ip_retry_after = check_ip_rate_limit(self, "message")
                if not ip_allowed:
                    send_rate_limit_error(
                        self,
                        action_text="发送私信",
                        retry_after_seconds=ip_retry_after,
                    )
                    return

                conversation_id = match_conversation_send.group(1)
                conversation = next(
                    (
                        row
                        for row in db.get("conversations", [])
                        if row.get("id") == conversation_id and row.get("userId") == user["id"]
                    ),
                    None,
                )
                if conversation is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "会话不存在")
                    return

                peer_user_id = str(conversation.get("peerUserId", "")).strip()
                if not peer_user_id:
                    json_error(self, HTTPStatus.BAD_REQUEST, "该会话暂不支持发送消息")
                    return
                peer_user = find_user_by_id(db, peer_user_id)
                if peer_user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "对方账号不存在或已注销")
                    return
                if is_user_blocked(db, user["id"], peer_user_id):
                    json_error(self, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发送消息")
                    return
                if is_user_blocked(db, peer_user_id, user["id"]):
                    json_error(self, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发送消息")
                    return

                content = str(body.get("content", "")).strip()
                if not content:
                    json_error(self, HTTPStatus.BAD_REQUEST, "消息内容不能为空")
                    return
                if len(content) > 1000:
                    json_error(self, HTTPStatus.BAD_REQUEST, "单条消息不能超过 1000 个字符")
                    return

                risk_marked, high_risk, risk_reasons = assess_text_risk(db, content)
                if high_risk:
                    json_error(
                        self,
                        HTTPStatus.BAD_REQUEST,
                        f"消息触发高风险风控：{'; '.join(risk_reasons)}",
                    )
                    add_audit_log(db, user["id"], "risk_block_message", ";".join(risk_reasons))
                    save_db(db)
                    return

                created_at = now_iso()
                message = {
                    "id": next_id(db, "message", "m"),
                    "conversationKey": conversation_key_for_users(user["id"], peer_user_id),
                    "senderUserId": user["id"],
                    "receiverUserId": peer_user_id,
                    "content": content,
                    "createdAt": created_at,
                    "readAt": "",
                    "deleted": False,
                }
                db.setdefault("directMessages", []).append(message)
                deliver_message_to_conversation_pair(
                    db,
                    sender_user_id=user["id"],
                    receiver_user_id=peer_user_id,
                    last_message=content,
                    updated_at=created_at,
                )
                if risk_marked:
                    add_audit_log(db, user["id"], "risk_mark_message", message["id"])
                add_audit_log(db, user["id"], "send_message", f"{conversation_id}->{peer_user_id}")
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "发送成功",
                        "data": serialize_direct_message(
                            db,
                            message,
                            viewer_user_id=user["id"],
                        ),
                    },
                )
                return

            match_conversation_block = re.fullmatch(
                r"/api/messages/conversations/([^/]+)/(block|unblock)",
                path,
            )
            if match_conversation_block:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                conversation_id = match_conversation_block.group(1)
                action = match_conversation_block.group(2)
                conversation = next(
                    (
                        row
                        for row in db.get("conversations", [])
                        if row.get("id") == conversation_id
                        and row.get("userId") == user["id"]
                        and not row.get("deleted")
                    ),
                    None,
                )
                if conversation is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "会话不存在")
                    return
                peer_user_id = str(conversation.get("peerUserId", "")).strip()
                if not peer_user_id:
                    json_error(self, HTTPStatus.BAD_REQUEST, "该会话暂不支持此操作")
                    return
                changed = False
                updated_at = now_iso()
                if action == "block":
                    if not is_user_blocked(db, user["id"], peer_user_id):
                        db.setdefault("userBlocks", []).append(
                            {
                                "blockerUserId": user["id"],
                                "blockedUserId": peer_user_id,
                                "createdAt": updated_at,
                            }
                        )
                        changed = True
                    if reject_pending_dm_requests_between(
                        db,
                        left_user_id=user["id"],
                        right_user_id=peer_user_id,
                        updated_at=updated_at,
                    ):
                        changed = True
                    conversation["unreadCount"] = 0
                    conversation["lastReadAt"] = updated_at
                    add_audit_log(db, user["id"], "block_conversation_peer", peer_user_id)
                else:
                    before_len = len(db.get("userBlocks", []))
                    db["userBlocks"] = [
                        row
                        for row in db.get("userBlocks", [])
                        if not (
                            str(row.get("blockerUserId", "")).strip() == user["id"]
                            and str(row.get("blockedUserId", "")).strip() == peer_user_id
                        )
                    ]
                    changed = len(db["userBlocks"]) != before_len
                    add_audit_log(db, user["id"], "unblock_conversation_peer", peer_user_id)
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "操作成功",
                        "data": {
                            "blockedByMe": is_user_blocked(db, user["id"], peer_user_id),
                            "blockedByPeer": is_user_blocked(db, peer_user_id, user["id"]),
                        },
                    },
                )
                return

            if path == "/api/posts":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                if user.get("muted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法发帖")
                    return
                allowed, retry_after = consume_rate_limit(
                    db,
                    user_id=user["id"],
                    action="post",
                    setting_key="postRateLimit",
                    default_limit=DEFAULT_SETTINGS["postRateLimit"],
                )
                if not allowed:
                    send_rate_limit_error(
                        self,
                        action_text="发帖",
                        retry_after_seconds=retry_after,
                    )
                    return

                ip_allowed, ip_retry_after = check_ip_rate_limit(self, "post")
                if not ip_allowed:
                    send_rate_limit_error(
                        self,
                        action_text="发帖",
                        retry_after_seconds=ip_retry_after,
                    )
                    return

                title = str(body.get("title", "")).strip()
                content = str(body.get("content", "")).strip()
                channel = str(body.get("channel", "")).strip()
                tags = parse_list(body.get("tags", []))
                status = str(body.get("status", "ongoing")).strip().lower() or "ongoing"
                pin_duration_minutes = parse_pin_duration_minutes(body.get("pinDurationMinutes"))
                image_upload_ids = parse_list(body.get("imageUploadIds", []))
                use_anonymous_alias = bool(body.get("useAnonymousAlias", False))
                anonymous_alias = sanitize_alias(str(body.get("anonymousAlias", "")), fallback="")

                if not title:
                    json_error(self, HTTPStatus.BAD_REQUEST, "标题不能为空")
                    return
                if not content:
                    json_error(self, HTTPStatus.BAD_REQUEST, "正文不能为空")
                    return
                if channel not in db.get("channels", DEFAULT_CHANNELS):
                    json_error(self, HTTPStatus.BAD_REQUEST, "频道不合法")
                    return
                if pin_duration_minutes is not None and not is_level_one_user(user):
                    json_error(self, HTTPStatus.FORBIDDEN, "仅一级用户可在发帖时直接置顶")
                    return

                risk_marked, high_risk, risk_reasons = assess_text_risk(
                    db,
                    " ".join([title, content, " ".join(tags)]),
                )
                if high_risk:
                    json_error(
                        self,
                        HTTPStatus.BAD_REQUEST,
                        f"内容触发高风险风控：{'; '.join(risk_reasons)}",
                    )
                    add_audit_log(db, user["id"], "risk_block_post", ";".join(risk_reasons))
                    save_db(db)
                    return

                picked_uploads: list[dict[str, Any]] = []
                for upload_id in image_upload_ids:
                    upload = get_upload_by_id(db, upload_id)
                    if upload is None or upload.get("deleted"):
                        json_error(self, HTTPStatus.BAD_REQUEST, f"图片不存在: {upload_id}")
                        return
                    if upload.get("uploaderId") != user["id"]:
                        json_error(self, HTTPStatus.FORBIDDEN, f"图片无权限绑定: {upload_id}")
                        return
                    if upload.get("postId"):
                        json_error(self, HTTPStatus.BAD_REQUEST, f"图片已绑定帖子: {upload_id}")
                        return
                    picked_uploads.append(upload)

                author_alias = user_nickname(user)
                if use_anonymous_alias:
                    author_alias = anonymous_alias or f"匿名同学-{secrets.token_hex(2)}"

                effective_allow_dm = bool(body.get("allowDm", False)) and not use_anonymous_alias
                post = {
                    "id": next_id(db, "post", "p"),
                    "title": title,
                    "content": content,
                    "channel": channel,
                    "tags": tags,
                    "hasImage": bool(body.get("hasImage", False)) or bool(picked_uploads),
                    "status": status if status in {"ongoing", "resolved", "closed"} else "ongoing",
                    "allowComment": bool(body.get("allowComment", True)),
                    "allowDm": effective_allow_dm,
                    "isAnonymous": use_anonymous_alias,
                    "authorAlias": author_alias,
                    "authorId": user["id"],
                    "pinStartedAt": "",
                    "pinExpiresAt": "",
                    "pinDurationMinutes": 0,
                    "createdAt": now_iso(),
                    "updatedAt": now_iso(),
                    "deleted": False,
                    "reviewStatus": "approved",
                    "riskMarked": risk_marked,
                }
                if pin_duration_minutes is not None:
                    apply_post_pin(
                        post,
                        duration_minutes=pin_duration_minutes,
                        started_at=post["createdAt"],
                    )
                db["posts"].append(post)
                for upload in picked_uploads:
                    upload["postId"] = post["id"]
                    upload_status = str(upload.get("status", "approved")).strip().lower()
                    if upload_status != "rejected":
                        upload["status"] = "approved"
                        upload["moderationReason"] = ""
                        if not str(upload.get("reviewNote", "")).strip():
                            upload["reviewNote"] = "发帖时自动通过"
                        upload["reviewedAt"] = post["createdAt"]
                recalc_post_has_image(db, post["id"])
                if risk_marked:
                    add_audit_log(db, user["id"], "risk_mark_post", f"{post['id']}:{';'.join(risk_reasons)}")
                if pin_duration_minutes is not None:
                    add_audit_log(
                        db,
                        user["id"],
                        "direct_pin_post_on_create",
                        f"{post['id']}:{pin_duration_minutes}",
                    )
                add_audit_log(db, user["id"], "create_post", f"创建帖子 {post['id']}")
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "data": serialize_post(
                            db,
                            post,
                            include_unapproved_images=True,
                            viewer_user_id=str(user.get("id", "")),
                        )
                    },
                )
                return

            match_post_pin_request = re.fullmatch(r"/api/posts/([^/]+)/pin-request", path)
            if match_post_pin_request:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                post_id = match_post_pin_request.group(1)
                duration_minutes = parse_pin_duration_minutes(body.get("durationMinutes"))
                reason = str(body.get("reason", "")).strip()
                if duration_minutes is None:
                    json_error(self, HTTPStatus.BAD_REQUEST, "置顶时长不合法")
                    return
                post = next(
                    (
                        row
                        for row in db.get("posts", [])
                        if str(row.get("id", "")).strip() == post_id
                        and not row.get("deleted")
                    ),
                    None,
                )
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                if str(post.get("authorId", "")).strip() != str(user.get("id", "")).strip():
                    json_error(self, HTTPStatus.FORBIDDEN, "只能申请置顶自己的帖子")
                    return
                if is_level_one_user(user):
                    apply_post_pin(post, duration_minutes=duration_minutes)
                    add_audit_log(
                        db,
                        user["id"],
                        "direct_pin_post",
                        f"{post_id}:{duration_minutes}",
                    )
                    save_db(db)
                    send_json(
                        self,
                        HTTPStatus.OK,
                        {
                            "message": "帖子已置顶",
                            "data": {
                                "mode": "direct",
                                "post": serialize_post(
                                    db,
                                    post,
                                    viewer_user_id=str(user.get("id", "")),
                                ),
                            },
                        },
                    )
                    return

                if is_post_pin_active(post):
                    json_error(self, HTTPStatus.BAD_REQUEST, "该帖子当前已在置顶中")
                    return
                existing_request = latest_pending_post_pin_request_for_post(db, post_id)
                if existing_request is not None:
                    json_error(self, HTTPStatus.CONFLICT, "该帖子已有待处理置顶申请")
                    return
                request = {
                    "id": next_id(db, "pinRequest", "pin"),
                    "postId": post_id,
                    "userId": str(user.get("id", "")).strip(),
                    "durationMinutes": duration_minutes,
                    "reason": reason,
                    "status": "pending",
                    "adminNote": "",
                    "createdAt": now_iso(),
                    "handledAt": "",
                    "handledBy": "",
                }
                db.setdefault("postPinRequests", []).append(request)
                add_audit_log(
                    db,
                    user["id"],
                    "submit_post_pin_request",
                    f"{request['id']}:{post_id}:{duration_minutes}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.CREATED,
                    {
                        "message": "置顶申请已提交，请等待管理员审核",
                        "data": {
                            "mode": "pending",
                            "request": serialize_admin_post_pin_request(db, request),
                        },
                    },
                )
                return

            if path == "/api/reports":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                allowed, retry_after = consume_rate_limit(
                    db,
                    user_id=user["id"],
                    action="report",
                    setting_key="reportRateLimit",
                    default_limit=DEFAULT_SETTINGS["reportRateLimit"],
                )
                if not allowed:
                    send_rate_limit_error(
                        self,
                        action_text="举报",
                        retry_after_seconds=retry_after,
                    )
                    return
                target_type = str(body.get("targetType", "")).strip().lower() or "other"
                target_id = str(body.get("targetId", "")).strip() or "unknown"
                reason = str(body.get("reason", "")).strip() or "其他"
                description = str(body.get("description", "")).strip()

                report = {
                    "id": next_id(db, "report", "r"),
                    "userId": user["id"],
                    "reporterAlias": user_nickname(user),
                    "targetType": target_type,
                    "targetId": target_id,
                    "reason": reason,
                    "description": description,
                    "status": "pending",
                    "result": "",
                    "createdAt": now_iso(),
                    "handledAt": "",
                    "handledBy": "",
                }
                db["reports"].append(report)
                add_audit_log(db, user["id"], "create_report", f"举报 {target_type}:{target_id}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "举报提交成功", "data": report})
                return

            match_action = re.fullmatch(r"/api/messages/requests/([^/]+)/(accept|reject)", path)
            if match_action:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                request_id = match_action.group(1)
                action = match_action.group(2)

                row = next(
                    (
                        x
                        for x in db["dmRequests"]
                        if x.get("id") == request_id
                        and x.get("toUserId") == user["id"]
                        and x.get("status") == "pending"
                    ),
                    None,
                )
                if row is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "私信申请不存在")
                    return

                if action == "accept":
                    from_user = find_user_by_id(db, str(row.get("fromUserId", "")))
                    if from_user:
                        if is_user_blocked(db, user["id"], from_user["id"]):
                            json_error(self, HTTPStatus.FORBIDDEN, "你已屏蔽对方，无法同意私信申请")
                            return
                        if is_user_blocked(db, from_user["id"], user["id"]):
                            json_error(self, HTTPStatus.FORBIDDEN, "对方已屏蔽你，无法建立会话")
                            return
                row["status"] = "accepted" if action == "accept" else "rejected"
                row["updatedAt"] = now_iso()

                if action == "accept":
                    from_user = find_user_by_id(db, str(row.get("fromUserId", "")))
                    if from_user:
                        sync_conversation_pair(
                            db,
                            left_user_id=user["id"],
                            right_user_id=from_user["id"],
                            last_message="已同意私信申请，开始聊天吧。",
                            updated_at=row["updatedAt"],
                        )

                add_audit_log(db, user["id"], "handle_dm_request", f"{request_id}:{action}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "操作成功", "data": {"ok": True}})
                return

            match_comment = re.fullmatch(r"/api/posts/([^/]+)/comments", path)
            if match_comment:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                if user.get("muted"):
                    json_error(self, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法评论")
                    return
                allowed, retry_after = consume_rate_limit(
                    db,
                    user_id=user["id"],
                    action="comment",
                    setting_key="commentRateLimit",
                    default_limit=DEFAULT_SETTINGS["commentRateLimit"],
                )
                if not allowed:
                    send_rate_limit_error(
                        self,
                        action_text="评论",
                        retry_after_seconds=retry_after,
                    )
                    return

                ip_allowed, ip_retry_after = check_ip_rate_limit(self, "comment")
                if not ip_allowed:
                    send_rate_limit_error(
                        self,
                        action_text="评论",
                        retry_after_seconds=ip_retry_after,
                    )
                    return

                post_id = match_comment.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                if not post.get("allowComment", True):
                    json_error(self, HTTPStatus.BAD_REQUEST, "该帖子不允许评论")
                    return

                content = str(body.get("content", "")).strip()
                if not content:
                    json_error(self, HTTPStatus.BAD_REQUEST, "评论不能为空")
                    return
                risk_marked, high_risk, risk_reasons = assess_text_risk(db, content)
                if high_risk:
                    json_error(
                        self,
                        HTTPStatus.BAD_REQUEST,
                        f"评论触发高风险风控：{'; '.join(risk_reasons)}",
                    )
                    add_audit_log(db, user["id"], "risk_block_comment", ";".join(risk_reasons))
                    save_db(db)
                    return

                comment = {
                    "id": next_id(db, "comment", "cm"),
                    "postId": post_id,
                    "userId": user["id"],
                    "authorAlias": user_nickname(user),
                    "content": content,
                    "createdAt": now_iso(),
                    "deleted": False,
                    "likeCount": 0,
                    "reviewStatus": "pending",
                    "riskMarked": risk_marked,
                    "parentId": str(body.get("parentId", "")).strip() or "",
                }
                db["comments"].append(comment)
                post_author_id = str(post.get("authorId", "")).strip()
                if post_author_id and post_author_id != user["id"]:
                    create_notification(
                        db,
                        user_id=post_author_id,
                        notification_type="comment",
                        title="有人评论了你的帖子",
                        content=f"{user_nickname(user)}：{content[:80]}",
                        related_type="post",
                        related_id=post_id,
                        post_id=post_id,
                        actor_id=str(user.get("id", "")),
                        actor_alias=user_nickname(user),
                    )
                parent_id = str(comment.get("parentId", "")).strip()
                if parent_id:
                    parent_comment = next(
                        (
                            row
                            for row in db.get("comments", [])
                            if row.get("id") == parent_id and not row.get("deleted")
                        ),
                        None,
                    )
                    parent_user_id = (
                        str(parent_comment.get("userId", "")).strip()
                        if parent_comment is not None
                        else ""
                    )
                    if (
                        parent_user_id
                        and parent_user_id != user["id"]
                        and parent_user_id != post_author_id
                    ):
                        create_notification(
                            db,
                            user_id=parent_user_id,
                            notification_type="reply",
                            title="有人回复了你的评论",
                            content=f"{user_nickname(user)}：{content[:80]}",
                            related_type="post",
                            related_id=post_id,
                            post_id=post_id,
                            actor_id=str(user.get("id", "")),
                            actor_alias=user_nickname(user),
                        )
                if risk_marked:
                    add_audit_log(
                        db,
                        user["id"],
                        "risk_mark_comment",
                        f"{comment['id']}:{';'.join(risk_reasons)}",
                    )
                add_audit_log(db, user["id"], "create_comment", f"{comment['id']}@{post_id}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "评论成功", "data": comment})
                return

            match_like = re.fullmatch(r"/api/posts/([^/]+)/like", path)
            if match_like:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                post_id = match_like.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                exists = any(x for x in db["likes"] if x.get("userId") == user["id"] and x.get("postId") == post_id)
                if not exists:
                    db["likes"].append({"userId": user["id"], "postId": post_id})
                    post_author_id = str(post.get("authorId", "")).strip()
                    if post_author_id and post_author_id != user["id"]:
                        create_notification(
                            db,
                            user_id=post_author_id,
                            notification_type="like",
                            title="你的帖子收到一个赞",
                            content=f"{user_nickname(user)} 赞了你的帖子《{str(post.get('title', '你的帖子'))[:32]}》",
                            related_type="post",
                            related_id=post_id,
                            post_id=post_id,
                            actor_id=str(user.get("id", "")),
                            actor_alias=user_nickname(user),
                        )
                    save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "已点赞", "data": {"ok": True}})
                return

            match_fav = re.fullmatch(r"/api/posts/([^/]+)/favorite", path)
            if match_fav:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                post_id = match_fav.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                exists = any(
                    x for x in db["favorites"] if x.get("userId") == user["id"] and x.get("postId") == post_id
                )
                if not exists:
                    db["favorites"].append({"userId": user["id"], "postId": post_id})
                    post_author_id = str(post.get("authorId", "")).strip()
                    if post_author_id and post_author_id != user["id"]:
                        create_notification(
                            db,
                            user_id=post_author_id,
                            notification_type="favorite",
                            title="你的帖子被收藏了",
                            content=f"{user_nickname(user)} 收藏了你的帖子《{str(post.get('title', '你的帖子'))[:32]}》",
                            related_type="post",
                            related_id=post_id,
                            post_id=post_id,
                            actor_id=str(user.get("id", "")),
                            actor_alias=user_nickname(user),
                        )
                    save_db(db)
                _, _, favorite_count = post_counts(db, post_id)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {"message": "已收藏", "data": {"ok": True, "favorited": True, "favoriteCount": favorite_count}},
                )
                return

            if path == "/api/admin/reviews/batch":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                target_type = str(body.get("targetType", "post")).strip().lower()
                action = str(body.get("action", "")).strip().lower()
                target_ids = [
                    str(item).strip()
                    for item in body.get("targetIds", [])
                    if str(item).strip()
                ]
                unique_target_ids = list(dict.fromkeys(target_ids))
                if not unique_target_ids:
                    json_error(self, HTTPStatus.BAD_REQUEST, "请选择至少一条内容")
                    return
                if len(unique_target_ids) > 200:
                    json_error(self, HTTPStatus.BAD_REQUEST, "单次最多处理 200 条内容")
                    return

                processed_ids: list[str] = []
                skipped_ids: list[str] = []
                for target_id in unique_target_ids:
                    try:
                        apply_admin_review_action(
                            db,
                            target_type=target_type,
                            target_id=target_id,
                            action=action,
                        )
                        processed_ids.append(target_id)
                    except LookupError:
                        skipped_ids.append(target_id)
                    except ValueError as error:
                        json_error(self, HTTPStatus.BAD_REQUEST, str(error))
                        return

                if not processed_ids:
                    json_error(self, HTTPStatus.BAD_REQUEST, "没有可处理的内容")
                    return

                add_audit_log(
                    db,
                    admin["id"],
                    "admin_review_batch",
                    f"{target_type}:{action}:{','.join(processed_ids)}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": f"批量审核完成，共处理 {len(processed_ids)} 条",
                        "data": {
                            "processedCount": len(processed_ids),
                            "processedIds": processed_ids,
                            "skippedIds": skipped_ids,
                        },
                    },
                )
                return

            match_review = re.fullmatch(r"/api/admin/reviews/(post|comment)/([^/]+)/(approve|reject|delete|risk)", path)
            if match_review:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                target_type = match_review.group(1)
                target_id = match_review.group(2)
                action = match_review.group(3)

                try:
                    apply_admin_review_action(
                        db,
                        target_type=target_type,
                        target_id=target_id,
                        action=action,
                    )
                except LookupError:
                    json_error(self, HTTPStatus.NOT_FOUND, "内容不存在")
                    return
                except ValueError as error:
                    json_error(self, HTTPStatus.BAD_REQUEST, str(error))
                    return

                add_audit_log(db, admin["id"], "admin_review", f"{target_type}:{target_id}:{action}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "处理成功", "data": {"ok": True}})
                return

            match_report_handle = re.fullmatch(r"/api/admin/reports/([^/]+)/handle", path)
            if match_report_handle:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                report_id = match_report_handle.group(1)
                action = str(body.get("action", "resolve")).strip().lower()
                result = str(body.get("result", "")).strip()

                report = next((r for r in db["reports"] if r.get("id") == report_id), None)
                if report is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "举报不存在")
                    return

                target_type = str(report.get("targetType", ""))
                target_id = str(report.get("targetId", ""))

                if action == "delete_content":
                    if target_type == "post":
                        row = next((p for p in db["posts"] if p.get("id") == target_id), None)
                        if row:
                            row["deleted"] = True
                            for upload in db.get("mediaUploads", []):
                                if upload.get("postId") == target_id and not upload.get("deleted"):
                                    upload["deleted"] = True
                    elif target_type == "comment":
                        row = next((c for c in db["comments"] if c.get("id") == target_id), None)
                        if row:
                            row["deleted"] = True
                    report["status"] = "resolved"
                    report["result"] = result or "内容已删除"
                elif action == "warn_user":
                    report["status"] = "resolved"
                    report["result"] = result or "已警告用户"
                elif action == "ban_user":
                    owner_id = target_owner(db, target_type, target_id)
                    owner = find_user_by_id(db, owner_id or "")
                    if owner:
                        owner["banned"] = True
                    report["status"] = "resolved"
                    report["result"] = result or "已封禁用户"
                elif action == "mark_misreport":
                    report["status"] = "closed"
                    report["result"] = result or "标记为误报"
                else:
                    report["status"] = "resolved"
                    report["result"] = result or "已处理"

                report["handledAt"] = now_iso()
                report["handledBy"] = admin.get("id")
                reporter_user_id = str(report.get("userId", "")).strip()
                if reporter_user_id:
                    create_notification(
                        db,
                        user_id=reporter_user_id,
                        notification_type="report_result",
                        title="你的举报已有处理结果",
                        content=report["result"],
                        related_type="report",
                        related_id=report_id,
                        actor_id=str(admin.get("id", "")),
                        actor_alias="管理员",
                    )
                add_audit_log(db, admin["id"], "admin_handle_report", f"{report_id}:{action}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "举报处理完成", "data": {"ok": True}})
                return

            match_post_pin_request_handle = re.fullmatch(
                r"/api/admin/post-pin-requests/([^/]+)/handle",
                path,
            )
            if match_post_pin_request_handle:
                admin, _ = require_admin_user(self, db)
                if admin is None:
                    return
                request_id = match_post_pin_request_handle.group(1)
                action = str(body.get("action", "")).strip().lower()
                admin_note = str(body.get("note", "")).strip()
                request = next(
                    (
                        row
                        for row in db.get("postPinRequests", [])
                        if str(row.get("id", "")).strip() == request_id
                    ),
                    None,
                )
                if request is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "置顶申请不存在")
                    return
                if str(request.get("status", "pending")).strip().lower() != "pending":
                    json_error(self, HTTPStatus.BAD_REQUEST, "该置顶申请已处理")
                    return
                post = next(
                    (
                        row
                        for row in db.get("posts", [])
                        if str(row.get("id", "")).strip() == str(request.get("postId", "")).strip()
                    ),
                    None,
                )
                user = find_user_by_id(
                    db,
                    str(request.get("userId", "")).strip(),
                    include_deleted=True,
                )
                if post is None or post.get("deleted") or user is None or user.get("deleted"):
                    json_error(self, HTTPStatus.BAD_REQUEST, "申请对应的帖子或用户当前不可处理")
                    return

                request["handledAt"] = now_iso()
                request["handledBy"] = str(admin.get("username", "")).strip() or "admin"
                request["adminNote"] = admin_note

                if action == "approve":
                    apply_post_pin(
                        post,
                        duration_minutes=parse_pin_duration_minutes(request.get("durationMinutes")) or 30,
                    )
                    request["status"] = "approved"
                    create_notification(
                        db,
                        user_id=str(user.get("id", "")),
                        notification_type="system_announcement",
                        title="你的帖子置顶申请已通过",
                        content=admin_note or f"帖子《{str(post.get('title', '你的帖子'))[:32]}》已置顶展示",
                        related_type="post",
                        related_id=str(post.get("id", "")),
                        post_id=str(post.get("id", "")),
                        actor_id=str(admin.get("id", "")),
                        actor_alias="管理员",
                    )
                elif action == "reject":
                    request["status"] = "rejected"
                    create_notification(
                        db,
                        user_id=str(user.get("id", "")),
                        notification_type="system_announcement",
                        title="你的帖子置顶申请未通过",
                        content=admin_note or "当前未通过置顶申请，你可以调整内容后再次申请",
                        related_type="post",
                        related_id=str(post.get("id", "")),
                        post_id=str(post.get("id", "")),
                        actor_id=str(admin.get("id", "")),
                        actor_alias="管理员",
                    )
                else:
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持 approve/reject")
                    return

                add_audit_log(db, admin["id"], "admin_handle_post_pin_request", f"{request_id}:{action}")
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "置顶申请处理完成",
                        "data": serialize_admin_post_pin_request(db, request),
                    },
                )
                return

            match_user_level_request_handle = re.fullmatch(
                r"/api/admin/user-level-requests/([^/]+)/handle",
                path,
            )
            if match_user_level_request_handle:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                request_id = match_user_level_request_handle.group(1)
                action = str(body.get("action", "")).strip().lower()
                admin_note = str(body.get("note", "")).strip()
                request = next(
                    (
                        row
                        for row in db.get("userLevelRequests", [])
                        if str(row.get("id", "")).strip() == request_id
                    ),
                    None,
                )
                if request is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "一级用户申请不存在")
                    return
                if str(request.get("status", "pending")).strip().lower() != "pending":
                    json_error(self, HTTPStatus.BAD_REQUEST, "该一级用户申请已处理")
                    return
                user = find_user_by_id(
                    db,
                    str(request.get("userId", "")).strip(),
                    include_deleted=True,
                )
                if user is None or user.get("deleted"):
                    json_error(self, HTTPStatus.BAD_REQUEST, "申请对应用户当前不可处理")
                    return

                request["handledAt"] = now_iso()
                request["handledBy"] = str(admin.get("username", "")).strip() or "admin"
                request["adminNote"] = admin_note

                if action == "approve":
                    user["userLevel"] = USER_LEVEL_ONE
                    request["status"] = "approved"
                    create_notification(
                        db,
                        user_id=str(user.get("id", "")),
                        notification_type="system_announcement",
                        title="你的一级用户申请已通过",
                        content=admin_note or "你现在可以直接为帖子设置置顶时长",
                        related_type="user_level_request",
                        related_id=request_id,
                        actor_id=str(admin.get("id", "")),
                        actor_alias="管理员",
                    )
                elif action == "reject":
                    request["status"] = "rejected"
                    create_notification(
                        db,
                        user_id=str(user.get("id", "")),
                        notification_type="system_announcement",
                        title="你的一级用户申请未通过",
                        content=admin_note or "当前未通过升级申请，你可以补充说明后重新提交",
                        related_type="user_level_request",
                        related_id=request_id,
                        actor_id=str(admin.get("id", "")),
                        actor_alias="管理员",
                    )
                else:
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持 approve/reject")
                    return

                add_audit_log(db, admin["id"], "admin_handle_user_level_request", f"{request_id}:{action}")
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "一级用户申请处理完成",
                        "data": serialize_admin_user_level_request(db, request),
                    },
                )
                return

            match_admin_account_action = re.fullmatch(
                r"/api/admin/admin-accounts/([^/]+)/action",
                path,
            )
            if match_admin_account_action:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                account_id = match_admin_account_action.group(1)
                action = str(body.get("action", "")).strip().lower()
                account = find_admin_account_by_id(db, account_id, include_inactive=True)
                if account is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "管理员账号不存在")
                    return
                if normalize_admin_role(account.get("role")) != ADMIN_ROLE_SECONDARY:
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持管理二级管理员账号")
                    return
                if action == "deactivate":
                    if not bool(account.get("active", True)):
                        json_error(self, HTTPStatus.BAD_REQUEST, "该管理员账号已注销")
                        return
                    account["active"] = False
                    account["updatedAt"] = now_iso()
                    clear_admin_sessions_for_account(str(account.get("id", "")))
                    message = "二级管理员已注销"
                elif action == "activate":
                    if bool(account.get("active", True)):
                        json_error(self, HTTPStatus.BAD_REQUEST, "该管理员账号当前已启用")
                        return
                    account["active"] = True
                    account["updatedAt"] = now_iso()
                    message = "二级管理员已恢复"
                else:
                    json_error(self, HTTPStatus.BAD_REQUEST, "不支持的操作")
                    return

                add_audit_log(
                    db,
                    "",
                    "admin_update_secondary_account",
                    f"{admin.get('username', '')}:{account.get('username', '')}:{action}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {"message": message, "data": serialize_admin_account(account)},
                )
                return

            match_user_action = re.fullmatch(r"/api/admin/users/([^/]+)/action", path)
            if match_user_action:
                admin, _ = require_admin_user(self, db)
                if admin is None:
                    return
                user_id = match_user_action.group(1)
                action = str(body.get("action", "")).strip().lower()
                note = str(body.get("note", "")).strip()

                user = find_user_by_id(db, user_id, include_deleted=True)
                if user is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "用户不存在")
                    return
                if user.get("id") == admin.get("id") and action in {"ban", "mute", "cancel"}:
                    json_error(self, HTTPStatus.BAD_REQUEST, "不能对当前管理员执行该操作")
                    return

                if action != "restore" and user.get("deleted"):
                    json_error(self, HTTPStatus.BAD_REQUEST, "该账号已注销，请改用恢复操作")
                    return

                if action == "mute":
                    user["muted"] = True
                elif action == "unmute":
                    user["muted"] = False
                elif action == "ban":
                    user["banned"] = True
                elif action == "unban":
                    user["banned"] = False
                elif action == "cancel":
                    if str(user.get("email", "")).strip().lower() == DEMO_USER_EMAIL:
                        json_error(self, HTTPStatus.BAD_REQUEST, "演示账号不可注销")
                        return
                    sync_cancellation_requests_after_admin_cancel(
                        db,
                        user_id=user_id,
                        handled_by=str(admin.get("username", "")).strip() or "admin",
                        review_note=note,
                    )
                    cancel_user_account(
                        db,
                        user,
                        actor_id=admin["id"],
                        detail=f"{user_id}:admin_cancel:{note}",
                    )
                elif action == "restore":
                    if not user.get("deleted"):
                        json_error(self, HTTPStatus.BAD_REQUEST, "该账号当前未注销")
                        return
                    restore_user_account(
                        db,
                        user,
                        actor_id=admin["id"],
                        detail=f"{user_id}:admin_restore:{note}",
                    )
                else:
                    json_error(self, HTTPStatus.BAD_REQUEST, "不支持的操作")
                    return

                add_audit_log(db, admin["id"], "admin_user_action", f"{user_id}:{action}")
                save_db(db)
                success_message = {
                    "cancel": "账号已注销",
                    "restore": "账号已恢复",
                }.get(action, "用户状态已更新")
                send_json(self, HTTPStatus.OK, {"message": success_message, "data": {"ok": True}})
                return

            match_appeal_handle = re.fullmatch(r"/api/admin/appeals/([^/]+)/handle", path)
            if match_appeal_handle:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                appeal_id = match_appeal_handle.group(1)
                action = str(body.get("action", "")).strip().lower()
                admin_note = str(body.get("note", "")).strip()

                appeal = next(
                    (
                        row
                        for row in db.get("appeals", [])
                        if str(row.get("id", "")) == appeal_id
                    ),
                    None,
                )
                if appeal is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "申诉不存在")
                    return
                if str(appeal.get("status", "pending")).strip().lower() != "pending":
                    json_error(self, HTTPStatus.BAD_REQUEST, "该申诉已处理")
                    return

                appeal["handledAt"] = now_iso()
                appeal["handledBy"] = str(admin.get("username", "")).strip() or "admin"
                appeal["adminNote"] = admin_note

                if action == "approve":
                    appeal["status"] = "approved"
                elif action == "reject":
                    appeal["status"] = "rejected"
                elif action == "close":
                    appeal["status"] = "closed"
                elif action == "approve_restore":
                    user = find_user_by_id(
                        db,
                        str(appeal.get("userId", "")),
                        include_deleted=True,
                    )
                    if user is None or not user.get("deleted"):
                        json_error(self, HTTPStatus.BAD_REQUEST, "该申诉对应账号当前不可恢复")
                        return
                    restore_user_account(
                        db,
                        user,
                        actor_id=admin["id"],
                        detail=f"{appeal_id}:approve_restore",
                    )
                    appeal["status"] = "approved"
                else:
                    json_error(self, HTTPStatus.BAD_REQUEST, "仅支持 approve/reject/close/approve_restore")
                    return

                user = find_user_by_id(
                    db,
                    str(appeal.get("userId", "")),
                    include_deleted=True,
                )
                if user is not None and not user.get("deleted"):
                    message = {
                        "approved": "你的申诉已通过",
                        "rejected": "你的申诉已被驳回",
                        "closed": "你的申诉已关闭",
                    }.get(str(appeal.get("status", "")), "你的申诉已有处理结果")
                    create_notification(
                        db,
                        user_id=str(user.get("id", "")),
                        notification_type="system_announcement",
                        title=message,
                        content=admin_note or str(appeal.get("title", "")),
                        related_type="appeal",
                        related_id=appeal_id,
                        actor_id=str(admin.get("id", "")),
                        actor_alias="管理员",
                    )

                add_audit_log(
                    db,
                    admin["id"],
                    "admin_handle_appeal",
                    f"{appeal_id}:{action}",
                )
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "申诉处理完成",
                        "data": serialize_appeal(db, appeal),
                    },
                )
                return

            match_cancellation_handle = re.fullmatch(
                r"/api/admin/account-cancellation-requests/([^/]+)/handle",
                path,
            )
            if match_cancellation_handle:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                request_id = match_cancellation_handle.group(1)
                action = str(body.get("action", "")).strip().lower()
                review_note = str(body.get("note", "")).strip()

                request = next(
                    (
                        row
                        for row in db.get("accountCancellationRequests", [])
                        if str(row.get("id", "")) == request_id
                    ),
                    None,
                )
                if request is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "注销申请不存在")
                    return
                if str(request.get("status", "pending")).lower() != "pending":
                    json_error(self, HTTPStatus.BAD_REQUEST, "该申请已处理")
                    return

                request["handledAt"] = now_iso()
                request["handledBy"] = str(admin.get("username", "")).strip() or "admin"
                request["reviewNote"] = review_note

                if action == "approve":
                    user = find_user_by_id(
                        db,
                        str(request.get("userId", "")),
                        include_deleted=True,
                    )
                    if user is None:
                        json_error(self, HTTPStatus.NOT_FOUND, "申请对应用户不存在")
                        return
                    if str(user.get("email", "")).strip().lower() == DEMO_USER_EMAIL:
                        json_error(self, HTTPStatus.BAD_REQUEST, "演示账号不可注销")
                        return
                    request["status"] = "approved"
                    cancel_user_account(
                        db,
                        user,
                        actor_id="",
                        detail=(
                            f"{user.get('id', '')}:approve_account_cancellation:"
                            f"{request['handledBy']}"
                        ),
                    )
                    add_audit_log(
                        db,
                        "",
                        "admin_handle_account_cancellation",
                        f"{request_id}:approve:{request['handledBy']}",
                    )
                    save_db(db)
                    send_json(
                        self,
                        HTTPStatus.OK,
                        {
                            "message": "已通过注销申请并停用账号",
                            "data": serialize_account_cancellation_request(request),
                        },
                    )
                    return

                if action == "reject":
                    request["status"] = "rejected"
                    add_audit_log(
                        db,
                        "",
                        "admin_handle_account_cancellation",
                        f"{request_id}:reject:{request['handledBy']}",
                    )
                    save_db(db)
                    send_json(
                        self,
                        HTTPStatus.OK,
                        {
                            "message": "已驳回注销申请",
                            "data": serialize_account_cancellation_request(request),
                        },
                    )
                    return

                json_error(self, HTTPStatus.BAD_REQUEST, "仅支持 approve/reject")
                return

            match_image_review = re.fullmatch(r"/api/admin/images/([^/]+)/review", path)
            if match_image_review:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                upload_id = match_image_review.group(1)
                action = str(body.get("action", "approve")).strip().lower()
                review_note = str(body.get("note", "")).strip()

                upload = get_upload_by_id(db, upload_id)
                if upload is None or upload.get("deleted"):
                    json_error(self, HTTPStatus.NOT_FOUND, "图片不存在")
                    return

                if action == "approve":
                    upload["status"] = "approved"
                    upload["reviewNote"] = review_note or "已通过"
                elif action == "reject":
                    upload["status"] = "rejected"
                    upload["reviewNote"] = review_note or "已拒绝"
                elif action == "risk":
                    upload["status"] = "risk"
                    upload["reviewNote"] = review_note or "已标记风险"
                elif action == "delete":
                    upload["deleted"] = True
                    upload["status"] = "rejected"
                    upload["reviewNote"] = review_note or "已删除图片"
                    try:
                        OBJECT_STORAGE.delete(str(upload.get("objectKey", "")))
                    except Exception:
                        pass
                else:
                    json_error(self, HTTPStatus.BAD_REQUEST, "不支持的审核动作")
                    return

                upload["reviewedBy"] = admin["id"]
                upload["reviewedAt"] = now_iso()
                post_id = str(upload.get("postId", ""))
                if post_id:
                    recalc_post_has_image(db, post_id)

                add_audit_log(db, admin["id"], "admin_review_image", f"{upload_id}:{action}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "图片审核完成", "data": serialize_upload(db, upload, include_admin_fields=True)})
                return

            if path == "/api/admin/channels":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                name = str(body.get("name", "")).strip()
                if not name:
                    json_error(self, HTTPStatus.BAD_REQUEST, "频道名不能为空")
                    return
                channels = db.get("channels", [])
                if name in channels:
                    json_error(self, HTTPStatus.BAD_REQUEST, "频道已存在")
                    return
                channels.append(name)
                add_audit_log(db, admin["id"], "admin_add_channel", name)
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "频道创建成功", "data": {"channels": channels}})
                return

            if path == "/api/admin/tags":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                name = str(body.get("name", "")).strip()
                if not name:
                    json_error(self, HTTPStatus.BAD_REQUEST, "标签名不能为空")
                    return
                tags = db.get("tags", [])
                if name in tags:
                    json_error(self, HTTPStatus.BAD_REQUEST, "标签已存在")
                    return
                tags.append(name)
                add_audit_log(db, admin["id"], "admin_add_tag", name)
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "标签创建成功", "data": {"tags": tags}})
                return

            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_patch(self, path: str) -> None:
        body = read_json_body(self)

        with DB_LOCK:
            db = load_db()

            if path == "/api/admin/auth/password":
                admin, token = require_admin_user(self, db)
                if admin is None:
                    return
                old_password = str(body.get("oldPassword", "")).strip()
                new_password = str(body.get("newPassword", "")).strip()
                if not old_password or not new_password:
                    json_error(self, HTTPStatus.BAD_REQUEST, "旧密码和新密码不能为空")
                    return
                if len(new_password) < 6:
                    json_error(self, HTTPStatus.BAD_REQUEST, "新密码长度至少 6 位")
                    return

                account = find_admin_account_by_id(
                    db,
                    str(admin.get("adminId", "")),
                    include_inactive=True,
                )
                if account is None:
                    json_error(self, HTTPStatus.UNAUTHORIZED, "管理员未登录或登录已过期")
                    return
                if not verify_password(str(account.get("passwordHash", "")), old_password):
                    json_error(self, HTTPStatus.UNAUTHORIZED, "旧密码错误")
                    return

                account["passwordHash"] = hash_password(new_password)
                account["updatedAt"] = now_iso()
                clear_admin_sessions_for_account(str(account.get("id", "")))
                if token:
                    with ADMIN_SESSION_LOCK:
                        ADMIN_SESSIONS.pop(token, None)
                add_audit_log(
                    db,
                    "",
                    "admin_update_password",
                    f"管理员更新密码:{account.get('username', '')}",
                )
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "管理员密码更新成功", "data": {"ok": True}})
                return

            if path == "/api/users/privacy":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return

                allow_stranger_dm = body.get("allowStrangerDm")
                show_contactable = body.get("showContactable")
                if allow_stranger_dm is not None:
                    user["allowStrangerDm"] = bool(allow_stranger_dm)
                if show_contactable is not None:
                    user["showContactable"] = bool(show_contactable)
                add_audit_log(db, user["id"], "update_privacy", "更新隐私设置")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "隐私设置更新成功", "data": {"ok": True}})
                return

            if path == "/api/users/me":
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return

                nickname = body.get("nickname")
                avatar_url = body.get("avatarUrl")
                student_id = body.get("studentId")

                if nickname is not None:
                    cleaned_nickname = sanitize_alias(str(nickname), fallback="")
                    if not cleaned_nickname:
                        json_error(self, HTTPStatus.BAD_REQUEST, "昵称不能为空")
                        return
                    user["nickname"] = cleaned_nickname
                    user["alias"] = cleaned_nickname

                if avatar_url is not None:
                    user["avatarUrl"] = normalize_avatar_url(str(avatar_url))

                if student_id is not None:
                    cleaned_student_id = str(student_id).strip()
                    if cleaned_student_id and not is_valid_student_id(cleaned_student_id):
                        json_error(self, HTTPStatus.BAD_REQUEST, "学号格式不合法（6-20 位字母或数字）")
                        return
                    if cleaned_student_id:
                        user["studentId"] = cleaned_student_id

                add_audit_log(db, user["id"], "update_profile", "更新个人资料")
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "个人资料更新成功",
                        "data": {
                            "nickname": user_nickname(user),
                            "avatarUrl": user_avatar_url(user),
                            "studentId": str(user.get("studentId", "")),
                        },
                    },
                )
                return

            match_post = re.fullmatch(r"/api/posts/([^/]+)", path)
            if match_post:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                post_id = match_post.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                if post.get("authorId") != user["id"]:
                    json_error(self, HTTPStatus.FORBIDDEN, "无权修改该帖子")
                    return

                status = str(body.get("status", "")).strip().lower()
                if status:
                    if status not in {"ongoing", "resolved", "closed"}:
                        json_error(self, HTTPStatus.BAD_REQUEST, "状态不合法")
                        return
                    post["status"] = status
                    post["updatedAt"] = now_iso()
                    add_audit_log(db, user["id"], "update_post_status", f"{post_id}:{status}")
                    save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "帖子更新成功", "data": serialize_post(db, post)})
                return

            match_channel = re.fullmatch(r"/api/admin/channels/(.+)", path)
            if match_channel:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                old_name = unquote(match_channel.group(1)).strip()
                new_name = str(body.get("newName", "")).strip()
                if not old_name or not new_name:
                    json_error(self, HTTPStatus.BAD_REQUEST, "频道名不能为空")
                    return
                channels = db.get("channels", [])
                if old_name not in channels:
                    json_error(self, HTTPStatus.NOT_FOUND, "频道不存在")
                    return
                if new_name in channels and new_name != old_name:
                    json_error(self, HTTPStatus.BAD_REQUEST, "新频道名已存在")
                    return
                channels[channels.index(old_name)] = new_name
                for post in db["posts"]:
                    if post.get("channel") == old_name:
                        post["channel"] = new_name
                        post["updatedAt"] = now_iso()
                add_audit_log(db, admin["id"], "admin_rename_channel", f"{old_name}->{new_name}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "频道更新成功", "data": {"channels": channels}})
                return

            match_tag = re.fullmatch(r"/api/admin/tags/(.+)", path)
            if match_tag:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                old_name = unquote(match_tag.group(1)).strip()
                new_name = str(body.get("newName", "")).strip()
                if not old_name or not new_name:
                    json_error(self, HTTPStatus.BAD_REQUEST, "标签名不能为空")
                    return
                tags = db.get("tags", [])
                if old_name not in tags:
                    json_error(self, HTTPStatus.NOT_FOUND, "标签不存在")
                    return
                if new_name in tags and new_name != old_name:
                    json_error(self, HTTPStatus.BAD_REQUEST, "新标签名已存在")
                    return
                tags[tags.index(old_name)] = new_name
                for post in db["posts"]:
                    post_tags = [new_name if t == old_name else t for t in post.get("tags", [])]
                    post["tags"] = post_tags
                add_audit_log(db, admin["id"], "admin_rename_tag", f"{old_name}->{new_name}")
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "标签更新成功", "data": {"tags": tags}})
                return

            if path == "/api/admin/config":
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return

                if "sensitiveWords" in body:
                    db["sensitiveWords"] = parse_list(body.get("sensitiveWords"))

                settings = db.get("settings", {})
                new_settings = body.get("settings")
                if isinstance(new_settings, dict):
                    for key in ["postRateLimit", "commentRateLimit", "messageRateLimit", "imageMaxMB"]:
                        if key in new_settings:
                            try:
                                settings[key] = int(new_settings[key])
                            except (TypeError, ValueError):
                                pass
                else:
                    for key in ["postRateLimit", "commentRateLimit", "messageRateLimit", "imageMaxMB"]:
                        if key in body:
                            try:
                                settings[key] = int(body[key])
                            except (TypeError, ValueError):
                                pass

                db["settings"] = settings
                add_audit_log(db, admin["id"], "admin_update_config", "更新系统配置")
                save_db(db)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {
                        "message": "配置更新成功",
                        "data": {
                            "sensitiveWords": db.get("sensitiveWords", []),
                            "settings": public_system_settings(db),
                        },
                    },
                )
                return

            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_delete(self, path: str) -> None:
        with DB_LOCK:
            db = load_db()

            if path == "/api/users/me":
                json_error(self, HTTPStatus.METHOD_NOT_ALLOWED, "请改用注销申请接口")
                return

            match_comment = re.fullmatch(r"/api/comments/([^/]+)", path)
            if match_comment:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                comment_id = match_comment.group(1)
                comment = next((c for c in db["comments"] if c.get("id") == comment_id and not c.get("deleted")), None)
                if comment is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "评论不存在")
                    return
                if comment.get("userId") != user["id"]:
                    json_error(self, HTTPStatus.FORBIDDEN, "无权删除该评论")
                    return
                comment["deleted"] = True
                add_audit_log(db, user["id"], "delete_comment", comment_id)
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "评论已删除", "data": {"ok": True}})
                return

            match_post = re.fullmatch(r"/api/posts/([^/]+)", path)
            if match_post:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                post_id = match_post.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                if post.get("authorId") != user["id"]:
                    json_error(self, HTTPStatus.FORBIDDEN, "无权删除该帖子")
                    return
                post["deleted"] = True
                for upload in db.get("mediaUploads", []):
                    if upload.get("postId") == post_id and not upload.get("deleted"):
                        upload["deleted"] = True
                add_audit_log(db, user["id"], "delete_post", post_id)
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "帖子已删除", "data": {"ok": True}})
                return

            match_conversation = re.fullmatch(r"/api/messages/conversations/([^/]+)", path)
            if match_conversation:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                conversation_id = match_conversation.group(1)
                conversation = next(
                    (
                        row
                        for row in db.get("conversations", [])
                        if row.get("id") == conversation_id
                        and row.get("userId") == user["id"]
                        and not row.get("deleted")
                    ),
                    None,
                )
                if conversation is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "会话不存在")
                    return
                conversation["deleted"] = True
                conversation["unreadCount"] = 0
                conversation["lastReadAt"] = now_iso()
                add_audit_log(db, user["id"], "delete_conversation", conversation_id)
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "会话已删除", "data": {"ok": True}})
                return

            match_favorite = re.fullmatch(r"/api/posts/([^/]+)/favorite", path)
            if match_favorite:
                user, _ = require_authorized_user(self, db)
                if user is None:
                    return
                post_id = match_favorite.group(1)
                post = next((p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")), None)
                if post is None:
                    json_error(self, HTTPStatus.NOT_FOUND, "帖子不存在")
                    return
                before_len = len(db["favorites"])
                db["favorites"] = [
                    x
                    for x in db["favorites"]
                    if not (x.get("userId") == user["id"] and x.get("postId") == post_id)
                ]
                if len(db["favorites"]) != before_len:
                    save_db(db)
                _, _, favorite_count = post_counts(db, post_id)
                send_json(
                    self,
                    HTTPStatus.OK,
                    {"message": "已取消收藏", "data": {"ok": True, "favorited": False, "favoriteCount": favorite_count}},
                )
                return

            match_del_channel = re.fullmatch(r"/api/admin/channels/(.+)", path)
            if match_del_channel:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                name = unquote(match_del_channel.group(1)).strip()
                channels = db.get("channels", [])
                if name not in channels:
                    json_error(self, HTTPStatus.NOT_FOUND, "频道不存在")
                    return
                used = any(not p.get("deleted") and p.get("channel") == name for p in db["posts"])
                if used:
                    json_error(self, HTTPStatus.BAD_REQUEST, "频道仍被帖子使用，无法删除")
                    return
                channels.remove(name)
                add_audit_log(db, admin["id"], "admin_delete_channel", name)
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "频道已删除", "data": {"channels": channels}})
                return

            match_del_tag = re.fullmatch(r"/api/admin/tags/(.+)", path)
            if match_del_tag:
                admin, _ = require_primary_admin_user(self, db)
                if admin is None:
                    return
                name = unquote(match_del_tag.group(1)).strip()
                tags = db.get("tags", [])
                if name not in tags:
                    json_error(self, HTTPStatus.NOT_FOUND, "标签不存在")
                    return
                tags.remove(name)
                for post in db["posts"]:
                    if name in post.get("tags", []):
                        post["tags"] = [t for t in post.get("tags", []) if t != name]
                add_audit_log(db, admin["id"], "admin_delete_tag", name)
                save_db(db)
                send_json(self, HTTPStatus.OK, {"message": "标签已删除", "data": {"tags": tags}})
                return

            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")


def main() -> None:
    ensure_db()
    host = os.environ.get("BACKEND_HOST", "0.0.0.0")
    port = int(os.environ.get("BACKEND_PORT", "8080"))

    server = ThreadingHTTPServer((host, port), TreeholeHandler)
    print(f"[backend] XDU Treehole API is running at http://{host}:{port}/api")
    print(f"[backend] Web root: {WEB_ROOT_DIR}")
    if not WEB_ROOT_DIR.exists() or not (WEB_ROOT_DIR / "index.html").exists():
        print("[backend] Web bundle missing. Run `flutter build web --dart-define=API_BASE_URL=/api`")
    print(f"[backend] SQL storage: {SQL_DB_FILE}")
    print(f"[backend] Object storage: {OBJECT_STORAGE.describe()}")
    if smtp_configured():
        smtp_mode = "SMTP_SSL" if SMTP_USE_SSL else ("SMTP+STARTTLS" if SMTP_USE_STARTTLS else "SMTP")
        print(
            f"[backend] SMTP: {smtp_mode} {SMTP_HOST}:{SMTP_PORT} from={SMTP_FROM_EMAIL}"
        )
    else:
        print("[backend] SMTP: not configured (set BACKEND_SMTP_* to enable email verification)")
    print("[backend] demo user account: demo@stu.xidian.edu.cn / 123456")
    print(f"[backend] admin account: {DEFAULT_ADMIN_USERNAME} / {DEFAULT_ADMIN_PASSWORD}")
    if verify_code_debug_enabled():
        print("[backend] debug verify code enabled: 123456")
    server.serve_forever()


if __name__ == "__main__":
    main()
