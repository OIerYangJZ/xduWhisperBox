"""
backend/_globals.py

Module-level runtime state and configuration constants.
Imported by helpers, services, and server.py.
server.py must call _globals.configure() early to populate all constants.

Why: avoids circular import issues between helpers and services.
"""

from __future__ import annotations

import importlib
import os
import re
import threading
from collections import deque
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Runtime state (set by server.py at startup)
# ---------------------------------------------------------------------------

ADMIN_SESSIONS: dict[str, str] = {}
ADMIN_SESSION_LOCK = threading.Lock()

RATE_LIMIT_EVENTS: dict[tuple[str, str], deque[float]] = {}
RATE_LIMIT_LOCK = threading.Lock()

IP_RATE_LIMIT_EVENTS: dict[str, dict[str, deque[float]]] = {}
IP_RATE_LIMIT_LOCK = threading.Lock()

# Paths (set by configure())
ROOT_DIR: Path | None = None
DATA_DIR: Path | None = None
LEGACY_DB_FILE: Path | None = None
SQL_DB_FILE: Path | None = None
OBJECT_STORAGE_DIR: Path | None = None
WEB_ROOT_DIR: Path | None = None
DB_LOCK: threading.Lock | None = None
REPOSITORY: Any = None
OBJECT_STORAGE: Any = None

# SMTP state (set by configure_smtp())
_smtp_host: str = ""
_smtp_port: int = 0
_smtp_from_email: str = ""


def smtp_configured() -> bool:
    return bool(_smtp_host and _smtp_port > 0 and _smtp_from_email)


def verify_code_debug_enabled() -> bool:
    return ALLOW_DEBUG_VERIFY_CODE or not smtp_configured()


# ---------------------------------------------------------------------------
# Config constants (set by configure())
# ---------------------------------------------------------------------------

DEFAULT_CHANNELS: list[str] = []
DEFAULT_TAGS: list[str] = []
DEFAULT_SETTINGS: dict[str, Any] = {}
DEFAULT_SENSITIVE_WORDS: list[str] = []
SEED_POSTS: list[dict[str, Any]] = []

DEMO_USER_ID: str = "u1"
DEMO_USER_EMAIL: str = "demo@stu.xidian.edu.cn"
DEMO_USER_PASSWORD: str = "123456"

PASSWORD_HASH_SCHEME: str = "pbkdf2_sha256"
PASSWORD_HASH_ITERATIONS: int = 240000
PASSWORD_SALT_BYTES: int = 16

ADMIN_USERNAME_SETTING_KEY: str = "adminUsername"
ADMIN_PASSWORD_HASH_SETTING_KEY: str = "adminPasswordHash"
DEFAULT_ADMIN_USERNAME: str = "admin"
DEFAULT_ADMIN_PASSWORD: str = "admin123456"
ADMIN_ROLE_PRIMARY: str = "primary"
ADMIN_ROLE_SECONDARY: str = "secondary"
USER_LEVEL_ONE: int = 1
USER_LEVEL_TWO: int = 2

PIN_DURATION_OPTIONS: dict[int, str] = {}

SMTP_HOST: str = ""
SMTP_PORT: int = 465
SMTP_USERNAME: str = ""
SMTP_PASSWORD: str = ""
SMTP_FROM_EMAIL: str = ""
SMTP_FROM_NAME: str = "西电树洞"
SMTP_USE_SSL: bool = True
SMTP_USE_STARTTLS: bool = False
BACKEND_XIDIAN_PUBLIC_ORIGIN: str = ""

ALLOW_DEBUG_VERIFY_CODE: bool = False
INCLUDE_DEBUG_CODE_IN_RESPONSE: bool = False
PASSWORD_RESET_CODE_PREFIX: str = "reset::"

RATE_LIMIT_WINDOWS_SECONDS: dict[str, int] = {}
IP_RATE_LIMITS: dict[str, dict[str, Any]] = {}
ALLOWED_IMAGE_TYPES: set[str] = set()

RATE_LIMIT_EVENT_MAX = 300
SPAM_REPEAT_REGEX: re.Pattern | None = None

BACKEND_VERSION: str = "0.2"


def configure() -> None:
    """Called by server.py at startup — populates all globals from environment."""
    global ROOT_DIR, DATA_DIR, LEGACY_DB_FILE, SQL_DB_FILE, \
        OBJECT_STORAGE_DIR, WEB_ROOT_DIR, DB_LOCK, REPOSITORY, OBJECT_STORAGE, \
        SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, \
        SMTP_FROM_EMAIL, SMTP_FROM_NAME, SMTP_USE_SSL, SMTP_USE_STARTTLS, \
        BACKEND_XIDIAN_PUBLIC_ORIGIN, \
        ALLOW_DEBUG_VERIFY_CODE, INCLUDE_DEBUG_CODE_IN_RESPONSE, \
        DEFAULT_CHANNELS, DEFAULT_TAGS, DEFAULT_SETTINGS, \
        DEFAULT_SENSITIVE_WORDS, SEED_POSTS, \
        PIN_DURATION_OPTIONS, RATE_LIMIT_WINDOWS_SECONDS, IP_RATE_LIMITS, \
        ALLOWED_IMAGE_TYPES, \
        _smtp_host, _smtp_port, _smtp_from_email

    ROOT_DIR = Path(__file__).resolve().parent
    DATA_DIR = ROOT_DIR / "data"
    LEGACY_DB_FILE = DATA_DIR / "db.json"
    SQL_DB_FILE = Path(os.environ.get("BACKEND_DB_FILE", str(DATA_DIR / "treehole.db")))
    OBJECT_STORAGE_DIR = Path(os.environ.get("BACKEND_STORAGE_DIR", str(ROOT_DIR / "storage" / "objects")))
    WEB_ROOT_DIR = Path(os.environ.get("BACKEND_WEB_ROOT", str(ROOT_DIR.parent / "build" / "web"))).resolve()
    DB_LOCK = threading.Lock()

    global REPOSITORY, OBJECT_STORAGE
    from sql_repository import SqliteTreeholeRepository
    from object_storage import build_object_storage_from_env
    global _repository, _object_storage
    REPOSITORY = SqliteTreeholeRepository(SQL_DB_FILE)
    OBJECT_STORAGE = build_object_storage_from_env(
        local_root_dir=OBJECT_STORAGE_DIR,
        local_public_prefix="/api/storage",
    )

    DEFAULT_CHANNELS[:] = [
        "综合", "找对象", "找搭子", "交友扩列", "吐槽日常",
        "八卦吃瓜", "求助问答", "失物招领", "二手交易",
        "学习交流", "活动拼车", "其他",
    ]
    DEFAULT_TAGS[:] = [
        "学习", "北校区", "南校区", "运动", "周末",
        "食堂", "日常", "数码", "毕业季",
    ]
    DEFAULT_SETTINGS.clear()
    DEFAULT_SETTINGS.update({
        "postRateLimit": 5,
        "commentRateLimit": 20,
        "messageRateLimit": 30,
        "uploadRateLimit": 30,
        "imageMaxMB": 5,
        "reportRateLimit": 10,
        "dmRequestRateLimit": 20,
    })
    DEFAULT_SENSITIVE_WORDS[:] = ["引流", "广告", "辱骂", "诈骗"]

    SEED_POSTS[:] = [
        {"title": "求助：图书馆哪里插座最多？", "content": "这周赶大作业，想找一个相对安静而且插座多的位置，北校区优先。",
         "channel": "求助问答", "tags": ["学习", "北校区"], "hasImage": False, "status": "ongoing",
         "allowComment": True, "allowDm": True, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "找周末羽毛球搭子", "content": "周六下午操场旁边羽毛球馆，水平一般，主打一起运动。",
         "channel": "找搭子", "tags": ["运动", "周末"], "hasImage": True, "status": "ongoing",
         "allowComment": True, "allowDm": True, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
        {"title": "二手显示器出一个 24 寸", "content": "毕业清东西，成色还不错，支持当面看货。",
         "channel": "二手交易", "tags": ["数码", "毕业季"], "hasImage": True, "status": "ongoing",
         "allowComment": True, "allowDm": True, "authorAlias": "洞主-小行星", "authorId": "seed-user-2"},
        {"title": "吐槽：食堂晚高峰排队太久", "content": "今天排了 25 分钟，想知道有没有错峰吃饭攻略。",
         "channel": "吐槽日常", "tags": ["食堂", "日常"], "hasImage": False, "status": "resolved",
         "allowComment": True, "allowDm": False, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
    ]

    PIN_DURATION_OPTIONS.clear()
    PIN_DURATION_OPTIONS.update({
        30: "30 分钟", 60: "1 小时", 120: "2 小时", 180: "3 小时",
        1440: "1 天", 4320: "3 天",
    })

    RATE_LIMIT_WINDOWS_SECONDS.clear()
    RATE_LIMIT_WINDOWS_SECONDS.update({
        "post": 3600, "comment": 3600, "message": 3600,
        "report": 3600, "dm_request": 3600, "upload": 3600,
    })
    IP_RATE_LIMITS.clear()
    IP_RATE_LIMITS.update({
        "post": {"limit": 20, "window": 3600},
        "comment": {"limit": 40, "window": 3600},
        "message": {"limit": 60, "window": 3600},
        "upload": {"limit": 30, "window": 3600},
    })

    ALLOWED_IMAGE_TYPES.clear()
    ALLOWED_IMAGE_TYPES.update({"image/jpeg", "image/png", "image/webp", "image/gif"})

    global SPAM_REPEAT_REGEX
    SPAM_REPEAT_REGEX = re.compile(r"(.)\1{8,}", re.DOTALL)

    SMTP_HOST = os.environ.get("BACKEND_SMTP_HOST", "").strip()
    SMTP_PORT = int(os.environ.get("BACKEND_SMTP_PORT", "465") or "465")
    SMTP_USERNAME = os.environ.get("BACKEND_SMTP_USERNAME", "").strip()
    SMTP_PASSWORD = os.environ.get("BACKEND_SMTP_PASSWORD", "").strip()
    SMTP_FROM_EMAIL = os.environ.get("BACKEND_SMTP_FROM_EMAIL", SMTP_USERNAME).strip()
    SMTP_FROM_NAME = os.environ.get("BACKEND_SMTP_FROM_NAME", "西电树洞").strip() or "西电树洞"
    SMTP_USE_SSL = os.environ.get("BACKEND_SMTP_USE_SSL", "true").strip().lower() in {"1", "true", "yes", "on"}
    SMTP_USE_STARTTLS = os.environ.get("BACKEND_SMTP_USE_STARTTLS", "false").strip().lower() in {"1", "true", "yes", "on"}
    BACKEND_XIDIAN_PUBLIC_ORIGIN = os.environ.get("BACKEND_XIDIAN_PUBLIC_ORIGIN", "").strip().rstrip("/")

    _smtp_host = SMTP_HOST
    _smtp_port = SMTP_PORT
    _smtp_from_email = SMTP_FROM_EMAIL

    ALLOW_DEBUG_VERIFY_CODE = os.environ.get("BACKEND_ALLOW_DEBUG_VERIFY_CODE", "").strip().lower() in {"1", "true", "yes", "on"}
    INCLUDE_DEBUG_CODE_IN_RESPONSE = os.environ.get("BACKEND_INCLUDE_DEBUG_CODE", "").strip().lower() in {"1", "true", "yes", "on"}

# Expose runtime state via module-level names for convenient access
# (these are set by configure())
#
# NOTE: Handlers call _globals.xxx() for helper functions that actually live
# in helpers/ or services/ sub-modules. We proxy them here to avoid having
# to update all handler import lines in one go.
def _lazy_proxy(name: str) -> Any:
    """Lazy-import proxy for helper functions that live in sub-modules."""
    import importlib
    if name in (
        "now_iso", "parse_iso", "now_utc",
        "sanitize_alias", "normalize_avatar_url", "hash_password", "verify_password",
        "is_campus_email", "is_valid_student_id", "random_code", "detect_image_type",
        "get_client_ip", "check_ip_rate_limit", "consume_rate_limit",
        "assess_text_risk", "check_duplicate_image_hash",
    ):
        mod = importlib.import_module("helpers")
    elif name in (
        "effective_post_allow_dm", "iso_to_time_text",
        "conversation_key_for_users",
    ):
        mod = importlib.import_module("services")
    else:
        raise AttributeError(f"module '_globals' has no attribute '{name}'")
    val = getattr(mod, name, None)
    if val is None:
        raise AttributeError(f"module '_globals' has no attribute '{name}'")
    return val


def __getattr__(name: str) -> Any:
    # Direct module-level attributes
    if name == "ADMIN_SESSIONS":
        return ADMIN_SESSIONS
    if name == "ADMIN_SESSION_LOCK":
        return ADMIN_SESSION_LOCK
    if name == "RATE_LIMIT_EVENTS":
        return RATE_LIMIT_EVENTS
    if name == "RATE_LIMIT_LOCK":
        return RATE_LIMIT_LOCK
    if name == "IP_RATE_LIMIT_EVENTS":
        return IP_RATE_LIMIT_EVENTS
    if name == "IP_RATE_LIMIT_LOCK":
        return IP_RATE_LIMIT_LOCK
    if name == "DB_LOCK":
        return DB_LOCK
    if name == "REPOSITORY":
        return REPOSITORY
    if name == "OBJECT_STORAGE":
        return OBJECT_STORAGE
    if name == "ROOT_DIR":
        return ROOT_DIR
    if name == "DATA_DIR":
        return DATA_DIR
    if name == "LEGACY_DB_FILE":
        return LEGACY_DB_FILE
    if name == "SQL_DB_FILE":
        return SQL_DB_FILE
    if name == "OBJECT_STORAGE_DIR":
        return OBJECT_STORAGE_DIR
    if name == "WEB_ROOT_DIR":
        return WEB_ROOT_DIR
    if name == "RATE_LIMIT_EVENT_MAX":
        return RATE_LIMIT_EVENT_MAX
    if name == "SPAM_REPEAT_REGEX":
        return SPAM_REPEAT_REGEX
    # Proxy helper functions called as _globals.xxx()
    return _lazy_proxy(name)


# ---------------------------------------------------------------------------
# Handler stubs — functions handlers call via _globals.xxx() but actually
# live in sub-modules or don't exist yet. Defined here for convenience.
# ---------------------------------------------------------------------------

def sort_posts_for_view(
    db: dict[str, Any],
    posts: list[dict[str, Any]],
    *,
    sort_by: str = "latest",
) -> list[dict[str, Any]]:
    """Sort posts for display. sort_by: latest | hot | oldest."""
    import math
    import time
    from helpers._datetime_helpers import parse_iso
    from services._user_service import is_post_pin_active

    def parse_time(value: Any) -> float:
        try:
            return parse_iso(str(value or "")).timestamp()
        except Exception:
            return 0.0

    def compare_latest_key(row: dict[str, Any]) -> tuple[str, str]:
        return (str(row.get("createdAt", "")), str(row.get("id", "")))

    def engagement_score(row: dict[str, Any]) -> int:
        likes = max(0, int(row.get("likeCount", 0) or 0))
        comments = max(0, int(row.get("commentCount", 0) or 0))
        favorites = max(0, int(row.get("favoriteCount", 0) or 0))
        views = min(500, max(0, int(row.get("viewCount", 0) or 0)))
        return (likes * 3) + (comments * 5) + (favorites * 2) + views

    def hot_score(row: dict[str, Any]) -> float:
        age_hours = max(1.0, abs(time.time() - parse_time(row.get("createdAt", ""))) / 3600.0)
        decay = math.pow(age_hours + 2.0, 0.85)
        created_tie_breaker = parse_time(row.get("createdAt", "")) / 1_000_000_000_000_000.0
        return (engagement_score(row) / decay) + created_tie_breaker

    active_pinned = [row for row in posts if is_post_pin_active(row)]
    normal_rows = [row for row in posts if not is_post_pin_active(row)]

    active_pinned.sort(
        key=lambda row: (
            str(row.get("pinStartedAt", "")),
            str(row.get("createdAt", "")),
            str(row.get("id", "")),
        ),
        reverse=True,
    )

    if sort_by == "hot":
        normal_rows.sort(
            key=lambda row: (
                hot_score(row),
                engagement_score(row),
                str(row.get("createdAt", "")),
                str(row.get("id", "")),
            ),
            reverse=True,
        )
    elif sort_by == "likes":
        normal_rows.sort(
            key=lambda row: (
                max(0, int(row.get("likeCount", 0) or 0)),
                str(row.get("createdAt", "")),
                str(row.get("id", "")),
            ),
            reverse=True,
        )
    elif sort_by == "oldest":
        normal_rows.sort(key=lambda row: compare_latest_key(row))
    else:  # latest
        normal_rows.sort(key=lambda row: compare_latest_key(row), reverse=True)

    return [*active_pinned, *normal_rows]


def get_image_max_bytes(db: dict[str, Any]) -> int:
    """Return max image upload size in bytes from settings."""
    settings = db.get("settings", {})
    if isinstance(settings, dict):
        mb = int(settings.get("imageMaxMB", 5))
    else:
        mb = 5
    return max(1024 * 1024, mb * 1024 * 1024)


def public_system_settings() -> dict[str, Any]:
    """Return public system settings. DEPRECATED: use services.public_system_settings(db)."""
    return {
        "channels": list(DEFAULT_CHANNELS),
        "tags": list(DEFAULT_TAGS),
        "settings": dict(DEFAULT_SETTINGS),
        "rateLimitRules": {
            "post": {"limit": 20, "window": 3600},
            "comment": {"limit": 40, "window": 3600},
            "message": {"limit": 60, "window": 3600},
            "upload": {"limit": 30, "window": 3600},
        },
    }

__all__ = [
    "ADMIN_SESSIONS", "ADMIN_SESSION_LOCK",
    "RATE_LIMIT_EVENTS", "RATE_LIMIT_LOCK",
    "IP_RATE_LIMIT_EVENTS", "IP_RATE_LIMIT_LOCK",
    "DB_LOCK", "REPOSITORY", "OBJECT_STORAGE",
    "ROOT_DIR", "DATA_DIR", "LEGACY_DB_FILE", "SQL_DB_FILE",
    "OBJECT_STORAGE_DIR", "WEB_ROOT_DIR",
    "configure", "smtp_configured", "verify_code_debug_enabled",
    "ALLOW_DEBUG_VERIFY_CODE", "INCLUDE_DEBUG_CODE_IN_RESPONSE",
    "DEFAULT_CHANNELS", "DEFAULT_TAGS", "DEFAULT_SETTINGS",
    "DEFAULT_SENSITIVE_WORDS", "SEED_POSTS",
    "DEMO_USER_ID", "DEMO_USER_EMAIL", "DEMO_USER_PASSWORD",
    "PASSWORD_HASH_SCHEME", "PASSWORD_HASH_ITERATIONS", "PASSWORD_SALT_BYTES",
    "ADMIN_USERNAME_SETTING_KEY", "ADMIN_PASSWORD_HASH_SETTING_KEY",
    "DEFAULT_ADMIN_USERNAME", "DEFAULT_ADMIN_PASSWORD",
    "ADMIN_ROLE_PRIMARY", "ADMIN_ROLE_SECONDARY",
    "USER_LEVEL_ONE", "USER_LEVEL_TWO",
    "PIN_DURATION_OPTIONS",
    "SMTP_HOST", "SMTP_PORT", "SMTP_USERNAME", "SMTP_PASSWORD",
    "SMTP_FROM_EMAIL", "SMTP_FROM_NAME", "SMTP_USE_SSL", "SMTP_USE_STARTTLS",
    "PASSWORD_RESET_CODE_PREFIX",
    "RATE_LIMIT_WINDOWS_SECONDS", "IP_RATE_LIMITS", "ALLOWED_IMAGE_TYPES",
    "RATE_LIMIT_EVENT_MAX", "SPAM_REPEAT_REGEX",
    "BACKEND_VERSION",
]
