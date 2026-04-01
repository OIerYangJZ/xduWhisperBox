"""
handlers/_auth_handler.py

Authentication & user session endpoints:
  POST /api/auth/login                           (legacy disabled)
  POST /api/auth/xidian/session                  — create browser auth attempt
  GET  /api/auth/xidian/session/<attemptId>      — poll/consume auth result
  GET  /api/auth/xidian/start?attempt=<id>       — redirect to IDS login page
  GET  /api/auth/xidian/callback?...             — IDS callback, issue treehole token
  POST /api/auth/logout
  POST /api/auth/register
  POST /api/auth/verify
  POST /api/auth/password/send-code
  POST /api/auth/password/reset
  POST /api/auth/send-code  (alias for resend)
  POST /api/auth/resend-code (alias)
"""
from __future__ import annotations

import html
import secrets
import threading
import time
from typing import Any
from urllib.parse import urlencode, urlsplit, urlunsplit, parse_qsl

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    is_campus_email,
    normalize_avatar_url,
    now_iso,
    sanitize_alias,
    json_error,
    read_json_body,
    send_json,
)
from helpers._xidian_auth import (
    XidianAuthDependencyError,
    XidianAuthPasswordError,
    XidianAuthUnavailableError,
    IDS_LOGIN_URL,
    validate_xidian_service_ticket,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    find_user_by_student_id,
    save_db,
)

_ATTEMPT_LOCK = threading.Lock()
_XIDIAN_AUTH_ATTEMPTS: dict[str, dict[str, Any]] = {}
_ATTEMPT_TTL_SECONDS = 10 * 60
_WEB_RESULT_QUERY_KEY = "xidianAuthAttempt"
_WEB_ATTEMPT_COOKIE_NAME = "xdu_whisper_xidian_attempt"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _next_id(db: dict[str, Any], key: str, prefix: str) -> str:
    db["seq"][key] += 1
    return f"{prefix}{db['seq'][key]}"


def _default_user_nickname(student_id: str) -> str:
    suffix = student_id.strip()[-4:]
    return sanitize_alias(f"西电同学{suffix}", fallback="西电同学")


def _unified_auth_only(handler: BaseHTTPRequestHandler, *, action: str) -> None:
    json_error(
        handler,
        HTTPStatus.BAD_REQUEST,
        f"普通用户已改为西电统一认证浏览器登录，暂不支持{action}，请使用新版统一认证登录入口",
    )


def _query_value(query: dict[str, list[str]], key: str) -> str:
    values = query.get(key) or []
    if not values:
        return ""
    return str(values[0]).strip()


def _sanitize_next_path(value: str) -> str:
    normalized = value.strip() or "/"
    if not normalized.startswith("/") or normalized.startswith("//"):
        return "/"
    return normalized


def _configured_public_origin() -> str:
    configured = str(getattr(_globals, "BACKEND_XIDIAN_PUBLIC_ORIGIN", "") or "").strip()
    if not configured:
        return ""
    if not (configured.startswith("http://") or configured.startswith("https://")):
        return ""
    return configured.rstrip("/")


def _client_origin(handler: BaseHTTPRequestHandler) -> str:
    configured = _configured_public_origin()
    if configured:
        return configured
    forwarded_proto = (handler.headers.get("X-Forwarded-Proto", "") or "").split(",", 1)[0].strip()
    forwarded_host = (handler.headers.get("X-Forwarded-Host", "") or "").split(",", 1)[0].strip()
    host = forwarded_host or (handler.headers.get("Host", "") or "").strip()
    if not host:
        host = f"{handler.server.server_name}:{handler.server.server_port}"
    proto = forwarded_proto
    if not proto:
        for candidate in (
            handler.headers.get("Origin", "") or "",
            handler.headers.get("Referer", "") or "",
        ):
            if candidate.startswith("http://") or candidate.startswith("https://"):
                proto = urlsplit(candidate).scheme
                break
    if not proto:
        proto = "http"
    return f"{proto}://{host}"


def _attempt_service_url(handler: BaseHTTPRequestHandler, attempt_id: str) -> str:
    base = _client_origin(handler)
    return f"{base}/api/auth/xidian/callback?attempt={attempt_id}"


def _web_callback_service_url(handler: BaseHTTPRequestHandler) -> str:
    return f"{_client_origin(handler)}/api/auth/xidian/callback"


def _current_request_service_url(
    handler: BaseHTTPRequestHandler,
    *,
    exclude_keys: set[str] | None = None,
) -> str:
    exclude_keys = exclude_keys or set()
    request_uri = urlsplit(handler.path)
    query_pairs = [
        (key, value)
        for key, value in parse_qsl(request_uri.query, keep_blank_values=True)
        if key not in exclude_keys
    ]
    query_string = urlencode(query_pairs)
    return f"{_client_origin(handler)}{urlunsplit(('', '', request_uri.path, query_string, ''))}"


def _attempt_redirect_url(attempt: dict[str, Any]) -> str:
    next_path = _sanitize_next_path(str(attempt.get("nextPath", "/")))
    parts = urlsplit(next_path)
    query_pairs = [(key, value) for key, value in parse_qsl(parts.query, keep_blank_values=True) if key != _WEB_RESULT_QUERY_KEY]
    query_pairs.append((_WEB_RESULT_QUERY_KEY, str(attempt.get("id", "")).strip()))
    return urlunsplit(("", "", parts.path or "/", urlencode(query_pairs), parts.fragment))


def _send_redirect(handler: BaseHTTPRequestHandler, location: str) -> None:
    handler.send_response(HTTPStatus.FOUND)
    handler.send_header("Location", location)
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", "0")
    handler.end_headers()


def _send_html_page(
    handler: BaseHTTPRequestHandler,
    *,
    status: HTTPStatus,
    title: str,
    message: str,
    detail: str = "",
    redirect_label: str = "",
    redirect_url: str = "",
    cookies: list[str] | None = None,
) -> None:
    detail_html = f"<p>{html.escape(detail)}</p>" if detail else ""
    redirect_html = ""
    if redirect_label and redirect_url:
        redirect_html = (
            f'<p><a href="{html.escape(redirect_url, quote=True)}">{html.escape(redirect_label)}</a></p>'
        )
    body = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f5f7fb; color: #111827; margin: 0; }}
    .card {{ max-width: 560px; margin: 10vh auto; background: #fff; border-radius: 20px; box-shadow: 0 24px 60px rgba(15, 23, 42, .08); padding: 28px; }}
    h1 {{ margin: 0 0 12px; font-size: 24px; }}
    p {{ line-height: 1.7; margin: 8px 0; color: #4b5563; }}
    a {{ color: #0e7490; text-decoration: none; font-weight: 600; }}
  </style>
</head>
<body>
  <div class="card">
    <h1>{html.escape(title)}</h1>
    <p>{html.escape(message)}</p>
    {detail_html}
    {redirect_html}
  </div>
</body>
</html>"""
    data = body.encode("utf-8")
    handler.send_response(int(status))
    handler.send_header("Content-Type", "text/html; charset=utf-8")
    for cookie in cookies or []:
        handler.send_header("Set-Cookie", cookie)
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def _read_cookie(handler: BaseHTTPRequestHandler, key: str) -> str:
    raw_cookie = handler.headers.get("Cookie", "") or ""
    for chunk in raw_cookie.split(";"):
        name, sep, value = chunk.strip().partition("=")
        if sep and name == key:
            return value.strip()
    return ""


def _build_attempt_cookie(handler: BaseHTTPRequestHandler, attempt_id: str, *, max_age: int) -> str:
    parts = [
        f"{_WEB_ATTEMPT_COOKIE_NAME}={attempt_id}",
        f"Max-Age={max(0, max_age)}",
        "Path=/",
        "HttpOnly",
        "SameSite=Lax",
    ]
    if _client_origin(handler).startswith("https://"):
        parts.append("Secure")
    return "; ".join(parts)


def _clear_attempt_cookie(handler: BaseHTTPRequestHandler) -> str:
    return _build_attempt_cookie(handler, "", max_age=0)


def _cleanup_attempts_locked() -> None:
    now_ts = time.time()
    expired_keys = [
        attempt_id
        for attempt_id, attempt in _XIDIAN_AUTH_ATTEMPTS.items()
        if float(attempt.get("expiresAtTs", 0) or 0) <= now_ts
    ]
    for attempt_id in expired_keys:
        _XIDIAN_AUTH_ATTEMPTS.pop(attempt_id, None)


def _create_auth_attempt(*, platform: str, next_path: str = "/") -> dict[str, Any]:
    normalized_platform = platform if platform in {"web", "mobile"} else "web"
    attempt_id = secrets.token_urlsafe(24)
    attempt = {
        "id": attempt_id,
        "platform": normalized_platform,
        "status": "pending",
        "createdAt": now_iso(),
        "expiresAtTs": time.time() + _ATTEMPT_TTL_SECONDS,
        "nextPath": _sanitize_next_path(next_path),
        "message": "",
        "token": "",
        "email": "",
        "studentId": "",
        "consumed": False,
    }
    with _ATTEMPT_LOCK:
        _cleanup_attempts_locked()
        _XIDIAN_AUTH_ATTEMPTS[attempt_id] = attempt
    return attempt


def _load_attempt(attempt_id: str) -> dict[str, Any] | None:
    with _ATTEMPT_LOCK:
        _cleanup_attempts_locked()
        attempt = _XIDIAN_AUTH_ATTEMPTS.get(attempt_id)
        if attempt is None:
            return None
        return dict(attempt)


def _update_attempt(attempt_id: str, **values: Any) -> dict[str, Any] | None:
    with _ATTEMPT_LOCK:
        _cleanup_attempts_locked()
        attempt = _XIDIAN_AUTH_ATTEMPTS.get(attempt_id)
        if attempt is None:
            return None
        attempt.update(values)
        return dict(attempt)


def _upsert_user_from_xidian_identity(
    db: dict[str, Any],
    *,
    student_id: str,
    campus_email: str,
) -> dict[str, Any]:
    user = find_user_by_student_id(db, student_id, include_deleted=True)

    if user is not None and user.get("deleted"):
        raise PermissionError("账号已注销，请联系管理员恢复")
    if user is None:
        nickname = _default_user_nickname(student_id)
        created_at = now_iso()
        user = {
            "id": _next_id(db, "user", "u"),
            "email": campus_email,
            "password": "",
            "alias": nickname,
            "nickname": nickname,
            "studentId": student_id,
            "avatarUrl": "",
            "userLevel": _globals.USER_LEVEL_TWO,
            "verified": True,
            "verifiedAt": created_at,
            "allowStrangerDm": True,
            "showContactable": True,
            "notifyComment": True,
            "notifyReply": True,
            "notifyLike": True,
            "notifyFavorite": True,
            "notifyReportResult": True,
            "notifySystem": True,
            "createdAt": created_at,
            "deleted": False,
            "isAdmin": False,
            "banned": False,
            "muted": False,
        }
        db["users"].append(user)
        add_audit_log(db, user["id"], "register_by_xidian_ids", f"统一认证首次登录 {student_id}")
    else:
        existing_email = str(user.get("email", "")).strip().lower()
        if not existing_email or not is_campus_email(existing_email):
            user["email"] = campus_email
        user["studentId"] = student_id
        user["verified"] = True
        if not str(user.get("verifiedAt", "")).strip():
            user["verifiedAt"] = now_iso()
        nickname = sanitize_alias(
            str(user.get("nickname", "")).strip() or str(user.get("alias", "")).strip(),
            fallback=_default_user_nickname(student_id),
        )
        user["nickname"] = nickname
        user["alias"] = nickname
        user["avatarUrl"] = normalize_avatar_url(str(user.get("avatarUrl", "")))
        for key in (
            "notifyComment",
            "notifyReply",
            "notifyLike",
            "notifyFavorite",
            "notifyReportResult",
            "notifySystem",
        ):
            if key not in user:
                user[key] = True

    if user.get("banned"):
        raise PermissionError("账号已被封禁")
    return user


def _issue_auth_payload(
    db: dict[str, Any],
    *,
    student_id: str,
    campus_email: str,
) -> dict[str, Any]:
    user = _upsert_user_from_xidian_identity(
        db,
        student_id=student_id,
        campus_email=campus_email,
    )
    token = secrets.token_urlsafe(24)
    db["sessions"][token] = user["id"]
    add_audit_log(db, user.get("id", "-"), "login_by_xidian_ids_ticket", f"统一认证 ticket 登录 {student_id}")
    save_db(db)
    return {
        "token": token,
        "verified": True,
        "isAdmin": bool(user.get("isAdmin", False)),
        "email": campus_email,
        "studentId": student_id,
    }


# ---------------------------------------------------------------------------
# Public handler functions
# ---------------------------------------------------------------------------


def handle_login(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="账号密码直传登录")


def handle_xidian_auth_create_session(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    body = read_json_body(handler)
    platform = str(body.get("platform", "web")).strip().lower() or "web"
    next_path = _sanitize_next_path(str(body.get("nextPath", "/")).strip() or "/")
    attempt = _create_auth_attempt(platform=platform, next_path=next_path)
    base = _client_origin(handler)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "attemptId": attempt["id"],
                "status": attempt["status"],
                "platform": attempt["platform"],
                "authorizeUrl": f"{base}/api/auth/xidian/start?attempt={attempt['id']}",
            }
        },
        no_cache=True,
    )


def handle_xidian_auth_get_session(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    attempt_id: str,
) -> None:
    attempt = _load_attempt(attempt_id)
    if attempt is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "登录请求不存在或已过期")
        return

    payload: dict[str, Any] = {
        "attemptId": attempt["id"],
        "status": attempt.get("status", "pending"),
        "platform": attempt.get("platform", "web"),
    }
    if attempt.get("status") == "authenticated":
        if attempt.get("consumed"):
            payload["message"] = "登录结果已使用，请重新发起登录"
        else:
            payload.update(
                {
                    "token": attempt.get("token", ""),
                    "verified": True,
                    "email": attempt.get("email", ""),
                    "studentId": attempt.get("studentId", ""),
                }
            )
            _update_attempt(
                attempt_id,
                consumed=True,
                expiresAtTs=min(
                    float(attempt.get("expiresAtTs", time.time() + 30)),
                    time.time() + 30,
                ),
            )
    elif attempt.get("status") == "failed":
        payload["message"] = str(attempt.get("message", "")).strip() or "统一认证登录失败"

    send_json(handler, HTTPStatus.OK, {"data": payload}, no_cache=True)


def handle_xidian_auth_start(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    attempt_id = _query_value(query, "attempt")
    attempt = _load_attempt(attempt_id)
    if not attempt_id or attempt is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "登录请求不存在或已过期")
        return

    service_url = _web_callback_service_url(handler)
    location = f"{IDS_LOGIN_URL}?{urlencode({'service': service_url})}"
    handler.send_response(HTTPStatus.FOUND)
    handler.send_header("Location", location)
    handler.send_header(
        "Set-Cookie",
        _build_attempt_cookie(handler, attempt_id, max_age=_ATTEMPT_TTL_SECONDS),
    )
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", "0")
    handler.end_headers()


def handle_xidian_auth_callback(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    attempt_id = _query_value(query, "attempt")
    if not attempt_id:
        attempt_id = _read_cookie(handler, _WEB_ATTEMPT_COOKIE_NAME)
    ticket = _query_value(query, "ticket")
    attempt = _load_attempt(attempt_id)
    if not attempt_id or attempt is None:
        _send_html_page(
            handler,
            status=HTTPStatus.GONE,
            title="登录已过期",
            message="这次统一认证登录已失效，请返回西电树洞重新发起登录。",
            cookies=[_clear_attempt_cookie(handler)],
        )
        return
    if not ticket:
        _update_attempt(attempt_id, status="failed", message="统一认证未返回有效票据")
        _send_html_page(
            handler,
            status=HTTPStatus.BAD_REQUEST,
            title="登录失败",
            message="统一认证未返回有效票据，请重新发起登录。",
            cookies=[_clear_attempt_cookie(handler)],
        )
        return

    try:
        service_url = (
            _attempt_service_url(handler, attempt_id)
            if _query_value(query, "attempt")
            else _web_callback_service_url(handler)
        )
        result = validate_xidian_service_ticket(ticket, service_url)
        auth_payload = _issue_auth_payload(
            db,
            student_id=result.student_id,
            campus_email=result.campus_email,
        )
    except PermissionError as error:
        _update_attempt(attempt_id, status="failed", message=str(error))
        _send_html_page(
            handler,
            status=HTTPStatus.FORBIDDEN,
            title="登录失败",
            message=str(error),
            cookies=[_clear_attempt_cookie(handler)],
        )
        return
    except XidianAuthPasswordError as error:
        _update_attempt(attempt_id, status="failed", message=str(error))
        _send_html_page(
            handler,
            status=HTTPStatus.UNAUTHORIZED,
            title="登录失败",
            message=str(error),
            cookies=[_clear_attempt_cookie(handler)],
        )
        return
    except (XidianAuthUnavailableError, XidianAuthDependencyError) as error:
        _update_attempt(attempt_id, status="failed", message=str(error))
        _send_html_page(
            handler,
            status=HTTPStatus.SERVICE_UNAVAILABLE,
            title="统一认证暂时不可用",
            message=str(error),
            cookies=[_clear_attempt_cookie(handler)],
        )
        return

    updated = _update_attempt(
        attempt_id,
        status="authenticated",
        token=auth_payload["token"],
        email=auth_payload["email"],
        studentId=auth_payload["studentId"],
        consumed=False,
        message="",
        expiresAtTs=time.time() + _ATTEMPT_TTL_SECONDS,
    )
    if updated is None:
        _send_html_page(
            handler,
            status=HTTPStatus.GONE,
            title="登录已过期",
            message="登录结果已过期，请返回西电树洞重新发起登录。",
            cookies=[_clear_attempt_cookie(handler)],
        )
        return

    if str(updated.get("platform", "web")) == "web":
        handler.send_response(HTTPStatus.FOUND)
        handler.send_header("Location", _attempt_redirect_url(updated))
        handler.send_header("Set-Cookie", _clear_attempt_cookie(handler))
        handler.send_header("Cache-Control", "no-store")
        handler.send_header("Content-Length", "0")
        handler.end_headers()
        return

    _send_html_page(
        handler,
        status=HTTPStatus.OK,
        title="登录成功",
        message="统一认证已经完成，请返回西电树洞 App，登录状态会自动同步。",
    )


def handle_xidian_mobile_callback(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    ticket = _query_value(query, "ticket")
    if not ticket:
        json_error(handler, HTTPStatus.BAD_REQUEST, "统一认证未返回有效票据")
        return

    try:
        result = validate_xidian_service_ticket(
            ticket,
            _current_request_service_url(handler, exclude_keys={"ticket"}),
        )
        auth_payload = _issue_auth_payload(
            db,
            student_id=result.student_id,
            campus_email=result.campus_email,
        )
    except PermissionError as error:
        json_error(handler, HTTPStatus.FORBIDDEN, str(error))
        return
    except XidianAuthPasswordError as error:
        json_error(handler, HTTPStatus.UNAUTHORIZED, str(error))
        return
    except (XidianAuthUnavailableError, XidianAuthDependencyError) as error:
        json_error(handler, HTTPStatus.SERVICE_UNAVAILABLE, str(error))
        return

    send_json(handler, HTTPStatus.OK, {"data": auth_payload}, no_cache=True)


def handle_register(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="注册")


def handle_verify(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="邮箱验证码确认")


def handle_logout(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user, token = auth_user_helper(handler, db)
    if token:
        db["sessions"].pop(token, None)
    if user:
        add_audit_log(db, user.get("id", "-"), "logout", "用户退出登录")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "已退出登录", "data": {"ok": True}})


def handle_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="发送邮箱验证码")


def handle_password_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="发送密码重置验证码")


def handle_password_reset(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="本地密码重置")
