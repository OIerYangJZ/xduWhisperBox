"""
handlers/_auth_handler.py

Authentication & user session endpoints:
  POST /api/auth/login
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
from datetime import timedelta
from typing import Any
from urllib.parse import urlencode, urlsplit, urlunsplit, parse_qsl

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    decode_base64_payload,
    is_campus_email,
    is_password_hashed,
    is_valid_student_id,
    normalize_avatar_url,
    extract_local_object_key_from_url,
    now_iso,
    now_utc,
    parse_iso,
    random_code,
    sanitize_alias,
    detect_image_type,
    hash_password,
    json_error,
    read_json_body,
    send_json,
    send_verification_email,
    send_password_reset_email,
    verification_send_error_message,
    verify_password,
    student_id_from_email,
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
    find_user_by_email,
    find_user_by_student_id,
    save_db,
    user_nickname,
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


def _password_reset_code_key(email: str) -> str:
    return f"{_globals.PASSWORD_RESET_CODE_PREFIX}{email.lower().strip()}"


def _student_email_only_error() -> str:
    return "仅支持西电学生邮箱（@stu.xidian.edu.cn）"


def _verification_response_data(
    *,
    email: str,
    student_id: str,
    code_store: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "verified": False,
        "needVerify": True,
        "email": email,
        "studentId": student_id,
    }
    if _globals.INCLUDE_DEBUG_CODE_IN_RESPONSE or not _globals.smtp_configured():
        payload["debugCode"] = str((code_store or {}).get("code", "")).strip() or "123456"
    return payload


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
    body = read_json_body(handler)
    identifier = str(
        body.get("identifier", body.get("studentId", body.get("email", ""))),
    ).strip()
    password = str(body.get("password", "")).strip()

    login_email = ""
    login_student_id = ""
    user: dict[str, Any] | None = None

    if "@" in identifier:
        login_email = identifier.lower()
        if not is_campus_email(login_email):
            json_error(handler, HTTPStatus.BAD_REQUEST, _student_email_only_error())
            return
        user = find_user_by_email(db, login_email, include_deleted=True)
    else:
        login_student_id = identifier
        if not is_valid_student_id(login_student_id):
            json_error(handler, HTTPStatus.BAD_REQUEST, "请输入有效学号")
            return
        user = find_user_by_student_id(db, login_student_id, include_deleted=True)
        if user is not None:
            login_email = str(user.get("email", "")).strip().lower()

    if not password:
        json_error(handler, HTTPStatus.BAD_REQUEST, "密码不能为空")
        return
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
        return
    if not login_email:
        login_email = str(user.get("email", "")).strip().lower()
    if not is_campus_email(login_email):
        json_error(handler, HTTPStatus.FORBIDDEN, _student_email_only_error())
        return
    if not login_student_id:
        login_student_id = str(user.get("studentId", "")).strip() or student_id_from_email(login_email)

    stored_password = str(user.get("password", "")).strip()
    if not stored_password:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "账号未设置密码，请先重置密码")
        return
    if not verify_password(stored_password, password):
        json_error(handler, HTTPStatus.UNAUTHORIZED, "账号或密码错误")
        return
    if not is_password_hashed(stored_password):
        user["password"] = hash_password(password)
    if user.get("banned"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被封禁")
        return

    if not bool(user.get("verified", False)):
        code_store = db.get("emailCodes", {}).get(login_email)
        if not code_store:
            smtp_enabled = _globals.smtp_configured()
            code = random_code() if smtp_enabled else "123456"
            if smtp_enabled:
                try:
                    send_verification_email(
                        to_email=login_email,
                        code=code,
                        expires_in_minutes=10,
                    )
                except Exception as error:
                    json_error(
                        handler,
                        HTTPStatus.SERVICE_UNAVAILABLE,
                        verification_send_error_message(error),
                    )
                    return
            code_store = {
                "code": code,
                "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
            }
            db["emailCodes"][login_email] = code_store
        save_db(db)
        send_json(
            handler,
            HTTPStatus.OK,
            {"data": _verification_response_data(
                email=login_email,
                student_id=login_student_id,
                code_store=code_store,
            )},
        )
        return

    token = secrets.token_urlsafe(24)
    db["sessions"][token] = user["id"]
    save_db(db)
    send_json(
        handler,
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
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    password = str(body.get("password", "")).strip()
    student_id = student_id_from_email(email)
    nickname = sanitize_alias(str(body.get("nickname", "")), fallback="") or _default_user_nickname(student_id)
    avatar_url = normalize_avatar_url(str(body.get("avatarUrl", "")))
    avatar_data_base64 = str(body.get("avatarDataBase64", "")).strip()
    avatar_file_name = str(body.get("avatarFileName", "avatar.png")).strip() or "avatar.png"
    avatar_content_type = str(body.get("avatarContentType", "")).strip().lower()

    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, _student_email_only_error())
        return
    if len(password) < 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "密码长度至少 6 位")
        return
    if not is_valid_student_id(student_id):
        json_error(handler, HTTPStatus.BAD_REQUEST, "邮箱前缀不符合学号格式（需为 6-20 位字母或数字）")
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is not None and user.get("verified"):
        json_error(handler, HTTPStatus.CONFLICT, "账号已存在，请直接登录")
        return
    existing_student = find_user_by_student_id(db, student_id, include_deleted=False)
    if existing_student is not None and str(existing_student.get("email", "")).strip().lower() != email:
        json_error(handler, HTTPStatus.CONFLICT, "该学号已绑定其他账号")
        return

    uploaded_avatar_key = ""
    if avatar_data_base64:
        try:
            avatar_bytes = decode_base64_payload(avatar_data_base64)
        except Exception:
            json_error(handler, HTTPStatus.BAD_REQUEST, "头像图片数据格式错误")
            return
        if not avatar_bytes:
            json_error(handler, HTTPStatus.BAD_REQUEST, "头像图片不能为空")
            return
        detected_content_type = detect_image_type(avatar_bytes)
        if detected_content_type is None:
            json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持 jpg/png/webp/gif 图片")
            return
        content_type = detected_content_type
        if avatar_content_type and avatar_content_type in _globals.ALLOWED_IMAGE_TYPES:
            content_type = avatar_content_type
        max_bytes = _globals.get_image_max_bytes(db)
        if len(avatar_bytes) > max_bytes:
            json_error(
                handler,
                HTTPStatus.BAD_REQUEST,
                f"头像图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）",
            )
            return
        try:
            stored_avatar = _globals.OBJECT_STORAGE.put_bytes(
                data=avatar_bytes,
                file_name=avatar_file_name,
                content_type=content_type,
            )
        except Exception:
            json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "头像上传失败，请稍后重试")
            return
        avatar_url = stored_avatar.url
        uploaded_avatar_key = stored_avatar.key

    old_avatar_key = ""
    if user is not None:
        old_avatar_key = extract_local_object_key_from_url(
            normalize_avatar_url(str(user.get("avatarUrl", ""))),
        )

    if user is None:
        created_at = now_iso()
        user = {
            "id": _next_id(db, "user", "u"),
            "email": email,
            "password": hash_password(password),
            "alias": nickname,
            "nickname": nickname,
            "studentId": student_id,
            "avatarUrl": avatar_url,
            "userLevel": _globals.USER_LEVEL_TWO,
            "verified": False,
            "verifiedAt": "",
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
    else:
        user["password"] = hash_password(password)
        user["alias"] = nickname
        user["nickname"] = nickname
        user["studentId"] = student_id
        user["avatarUrl"] = avatar_url

    smtp_enabled = _globals.smtp_configured()
    code = random_code() if smtp_enabled else "123456"
    if smtp_enabled:
        try:
            send_verification_email(to_email=email, code=code, expires_in_minutes=10)
        except Exception as error:
            json_error(
                handler,
                HTTPStatus.SERVICE_UNAVAILABLE,
                verification_send_error_message(error),
            )
            return

    code_store = {
        "code": code,
        "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
    }
    db["emailCodes"][email] = code_store
    save_db(db)

    if old_avatar_key and uploaded_avatar_key and old_avatar_key != uploaded_avatar_key:
        try:
            _globals.OBJECT_STORAGE.delete(old_avatar_key)
        except Exception:
            pass

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "注册成功，请完成邮箱验证"
            if smtp_enabled
            else "注册成功，邮件服务未配置，内测验证码为 123456",
            "data": _verification_response_data(
                email=email,
                student_id=student_id,
                code_store=code_store,
            ),
        },
    )


def handle_verify(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    code = str(body.get("code", "")).strip()
    password = str(body.get("password", "")).strip()
    student_id = student_id_from_email(email)

    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, _student_email_only_error())
        return
    if not is_valid_student_id(student_id):
        json_error(handler, HTTPStatus.BAD_REQUEST, "邮箱前缀不符合学号格式（需为 6-20 位字母或数字）")
        return
    if len(code) != 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码格式错误")
        return

    code_row = db.get("emailCodes", {}).get(email)
    if not code_row:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请先发送验证码")
        return
    if code_row.get("code") != code and not (_globals.verify_code_debug_enabled() and code == "123456"):
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码错误")
        return

    expires_at = parse_iso(str(code_row.get("expiresAt", "")))
    if expires_at is None or now_utc() > expires_at:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码已过期")
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        existing_student = find_user_by_student_id(db, student_id, include_deleted=False)
        if existing_student is not None:
            json_error(handler, HTTPStatus.CONFLICT, "该学号已绑定其他账号")
            return
        created_at = now_iso()
        nickname = _default_user_nickname(student_id)
        user = {
            "id": _next_id(db, "user", "u"),
            "email": email,
            "password": hash_password(password) if password else "",
            "alias": nickname,
            "nickname": nickname,
            "studentId": student_id,
            "avatarUrl": "",
            "userLevel": _globals.USER_LEVEL_TWO,
            "verified": False,
            "verifiedAt": "",
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
        add_audit_log(db, user["id"], "register_by_email_code", f"邮箱验证码首次登录 {email}")

    if password:
        user["password"] = hash_password(password)
    user["verified"] = True
    user["verifiedAt"] = now_iso()
    user["nickname"] = user_nickname(user)
    user["alias"] = user_nickname(user)
    user["studentId"] = str(user.get("studentId", "")).strip() or student_id
    user["avatarUrl"] = normalize_avatar_url(str(user.get("avatarUrl", "")))

    db["emailCodes"].pop(email, None)
    token = secrets.token_urlsafe(24)
    db["sessions"][token] = user["id"]
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "token": token,
                "verified": True,
                "isAdmin": bool(user.get("isAdmin", False)),
                "email": email,
                "studentId": user["studentId"],
            }
        },
    )


def handle_logout(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user, token = auth_user_helper(handler, db)
    if token:
        db["sessions"].pop(token, None)
    if user:
        add_audit_log(db, user.get("id", "-"), "logout", "用户退出登录")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "已退出登录", "data": {"ok": True}})


def handle_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, _student_email_only_error())
        return

    smtp_enabled = _globals.smtp_configured()
    code = random_code() if smtp_enabled else "123456"
    if smtp_enabled:
        try:
            send_verification_email(to_email=email, code=code, expires_in_minutes=10)
        except Exception as error:
            json_error(
                handler,
                HTTPStatus.SERVICE_UNAVAILABLE,
                verification_send_error_message(error),
            )
            return

    code_store = {
        "code": code,
        "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
    }
    db["emailCodes"][email] = code_store
    save_db(db)

    data: dict[str, Any] = {
        "email": email,
        "expiresInSeconds": 600,
    }
    if _globals.INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled:
        data["debugCode"] = code
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "验证码已发送" if smtp_enabled else "邮件服务未配置，已启用内测验证码",
            "data": data,
        },
    )


def handle_password_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, _student_email_only_error())
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
        return

    smtp_enabled = _globals.smtp_configured()
    code = random_code() if smtp_enabled else "123456"
    if smtp_enabled:
        try:
            send_password_reset_email(
                to_email=email,
                code=code,
                expires_in_minutes=10,
            )
        except Exception as error:
            json_error(
                handler,
                HTTPStatus.SERVICE_UNAVAILABLE,
                verification_send_error_message(error),
            )
            return

    db["emailCodes"][_password_reset_code_key(email)] = {
        "code": code,
        "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
    }
    save_db(db)

    data: dict[str, Any] = {
        "email": email,
        "expiresInSeconds": 600,
    }
    if _globals.INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled:
        data["debugCode"] = code
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "重置密码验证码已发送" if smtp_enabled else "邮件服务未配置，已启用内测验证码",
            "data": data,
        },
    )


def handle_password_reset(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    code = str(body.get("code", "")).strip()
    new_password = str(body.get("newPassword", "")).strip()

    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, _student_email_only_error())
        return
    if len(code) != 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码格式错误")
        return
    if len(new_password) < 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "新密码长度至少 6 位")
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
        return

    code_row = db.get("emailCodes", {}).get(_password_reset_code_key(email))
    if not code_row:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请先发送重置验证码")
        return
    if code_row.get("code") != code and not (_globals.verify_code_debug_enabled() and code == "123456"):
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码错误")
        return

    expires_at = parse_iso(str(code_row.get("expiresAt", "")))
    if expires_at is None or now_utc() > expires_at:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码已过期")
        return

    user["password"] = hash_password(new_password)
    db["emailCodes"].pop(_password_reset_code_key(email), None)
    add_audit_log(db, user["id"], "reset_password_by_email", f"邮箱重置密码 {email}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "密码重置成功", "data": {"ok": True}})
