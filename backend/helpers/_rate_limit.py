from __future__ import annotations

import re
import time
from collections import deque
from http.server import BaseHTTPRequestHandler
from typing import Any

import _globals


def get_setting_int(db: dict[str, Any], key: str, default: int, *, minimum: int = 1) -> int:
    settings = db.get("settings", {})
    if isinstance(settings, dict):
        try:
            return max(minimum, int(settings.get(key, default)))
        except (TypeError, ValueError):
            return max(minimum, default)
    return max(minimum, default)


def consume_rate_limit(
    db: dict[str, Any],
    *,
    user_id: str,
    action: str,
    setting_key: str,
    default_limit: int,
) -> tuple[bool, int]:
    limit = get_setting_int(db, setting_key, default_limit, minimum=1)
    window_seconds = _globals.RATE_LIMIT_WINDOWS_SECONDS.get(action, 3600)
    now = time.time()
    key = (user_id, action)

    with _globals.RATE_LIMIT_LOCK:
        queue = _globals.RATE_LIMIT_EVENTS.setdefault(key, deque())
        while queue and now - queue[0] >= window_seconds:
            queue.popleft()

        if len(queue) >= limit:
            retry_after = max(1, int(window_seconds - (now - queue[0])))
            return False, retry_after

        queue.append(now)
        while len(queue) > 300:
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
    limits = _globals.IP_RATE_LIMITS.get(action)
    if not limits:
        return True, 0
    limit = limits["limit"]
    window_seconds = limits["window"]
    now = time.time()

    with _globals.IP_RATE_LIMIT_LOCK:
        ip_events = _globals.IP_RATE_LIMIT_EVENTS.setdefault(ip, {})
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


def assess_text_risk(db: dict[str, Any], text: str) -> tuple[bool, bool, list[str]]:
    normalized = text.strip()
    if not normalized:
        return False, False, []

    reasons: list[str] = []
    spam_re = re.compile(r"(.)\1{8,}", re.DOTALL)

    hit_words = [
        str(word).strip()
        for word in db.get("sensitiveWords", [])
        if str(word).strip() and str(word).strip() in normalized
    ]
    if hit_words:
        reasons.append(f"命中敏感词: {','.join(hit_words[:3])}")

    if spam_re.search(normalized):
        reasons.append("疑似重复刷屏文本")
    if len(normalized) > 5000:
        reasons.append("文本长度异常")

    risk_marked = bool(reasons)
    return risk_marked, False, reasons


def send_rate_limit_error(
    handler: BaseHTTPRequestHandler,
    *,
    action_text: str,
    retry_after_seconds: int,
) -> None:
    from helpers._http_helpers import send_json
    from http import HTTPStatus
    send_json(
        handler,
        HTTPStatus.TOO_MANY_REQUESTS,
        {
            "message": f"{action_text}过于频繁，请在 {retry_after_seconds} 秒后重试",
            "data": {"retryAfterSeconds": retry_after_seconds},
        },
    )
