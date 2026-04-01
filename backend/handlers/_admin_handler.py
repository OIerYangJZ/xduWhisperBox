"""
handlers/_admin_handler.py

Admin & moderation endpoints:
  POST /api/admin/auth/login                        — admin login
  POST /api/admin/auth/logout                       — admin logout
  GET  /api/admin/auth/me                          — current admin session info
  GET  /api/admin/overview                          — system overview stats
  GET  /api/admin/reviews                           — content review list (post/comment)
  GET  /api/admin/reports                           — user reports list
  GET  /api/admin/images/reviews                   — image moderation list
  GET  /api/admin/users                             — user management list
  GET  /api/admin/post-pin-requests                — pin-top request list
  GET  /api/admin/user-level-requests              — level-upgrade request list
  GET  /api/admin/admin-accounts                    — secondary admin account list
  GET  /api/admin/account-cancellation-requests    — account cancellation list
  GET  /api/admin/appeals                          — appeal list
  GET  /api/admin/export                           — data export
  GET  /api/admin/channels-tags                   — channel and tag lists
  GET  /api/admin/config                          — sensitive words & system settings
  GET  /api/admin/announcements                   — published announcements
  POST /api/admin/auth/password                   — change own admin password
  POST /api/admin/announcements                   — publish system announcement
  POST /api/admin/reviews/batch                   — batch approve/reject/delete/risk
  POST /api/admin/reviews/(post|comment)/<id>/(approve|reject|delete|risk) — single review
  POST /api/admin/reports/<id>/handle             — handle a user report
  POST /api/admin/post-pin-requests/<id>/handle   — handle pin-top request
  POST /api/admin/user-level-requests/<id>/handle — handle level-upgrade request
  POST /api/admin/admin-accounts                  — create secondary admin account
  POST /api/admin/admin-accounts/<id>/action       — deactivate/activate admin account
  POST /api/admin/users/<id>/action              — mute/unmute/ban/unban/cancel/restore user
  POST /api/admin/appeals/<id>/handle            — handle appeal
  POST /api/admin/account-cancellation-requests/<id>/handle — handle cancellation
  POST /api/admin/images/<id>/review             — approve/reject/delete/risk image
  POST /api/admin/channels                       — add channel
  POST /api/admin/tags                           — add tag
  PATCH /api/admin/channels/<name>               — rename channel
  PATCH /api/admin/tags/<name>                  — rename tag
  PATCH /api/admin/config                        — update config (sensitive words, rate limits)
  DELETE /api/admin/channels/<name>              — delete channel
  DELETE /api/admin/tags/<name>                  — delete tag
"""
from __future__ import annotations

import os
import re
import secrets
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    calc_sha256_hex,
    hash_password,
    is_password_hashed,
    json_error,
    now_iso,
    parse_bool,
    read_json_body,
    sanitize_alias,
    send_json,
    verify_password,
)
from services import (
    add_audit_log,
    auth_admin,
    auth_user as auth_user_helper,
    build_admin_account_rows,
    build_admin_appeal_rows,
    build_admin_post_pin_request_rows,
    build_admin_report_rows,
    build_admin_review_rows,
    build_admin_user_level_request_rows,
    build_admin_user_rows,
    build_export_payload,
    build_overview,
    cancel_user_account,
    clear_admin_sessions_for_account,
    create_notification,
    find_admin_account_by_id,
    find_admin_account_by_username,
    find_user_by_id,
    get_android_release,
    normalize_admin_role,
    next_id,
    normalize_user_level,
    post_counts,
    publish_system_announcement,
    recalc_post_has_image,
    restore_user_account,
    save_db,
    set_android_release,
    serialize_admin_account,
    serialize_admin_auth_payload,
    serialize_system_announcement,
    sync_cancellation_requests_after_admin_cancel,
    target_owner,
    user_level_label,
)


def _require_admin(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    admin, _ = auth_admin(handler, db)
    if admin is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "管理员未登录或登录已过期")
        return None
    return admin


def _require_primary_admin(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    admin = _require_admin(handler, db)
    if admin is None:
        return None
    if normalize_admin_role(admin.get("role")) != _globals.ADMIN_ROLE_PRIMARY:
        json_error(handler, HTTPStatus.FORBIDDEN, "需要一级管理员权限")
        return None
    return admin


def _read_multipart_form(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    content_type = handler.headers.get("Content-Type", "")
    match = re.search(r'boundary=(?:"([^"]+)"|([^;]+))', content_type)
    if match is None:
        raise ValueError("missing multipart boundary")
    boundary = (match.group(1) or match.group(2) or "").encode("utf-8")
    if not boundary:
        raise ValueError("invalid multipart boundary")

    try:
        content_length = max(0, int(handler.headers.get("Content-Length", "0")))
    except ValueError as exc:
        raise ValueError("invalid content length") from exc

    raw_body = handler.rfile.read(content_length) if content_length > 0 else b""
    delimiter = b"--" + boundary
    result: dict[str, Any] = {}
    for chunk in raw_body.split(delimiter):
        if not chunk:
            continue
        if chunk.startswith(b"\r\n"):
            chunk = chunk[2:]
        if chunk == b"--" or chunk == b"--\r\n":
            continue
        if chunk.endswith(b"--\r\n"):
            chunk = chunk[:-4]
        elif chunk.endswith(b"--"):
            chunk = chunk[:-2]
        if chunk.endswith(b"\r\n"):
            chunk = chunk[:-2]
        if not chunk:
            continue

        header_blob, separator, body = chunk.partition(b"\r\n\r\n")
        if not separator:
            continue

        headers: dict[str, str] = {}
        for header_line in header_blob.decode("utf-8", errors="ignore").split("\r\n"):
            if ":" not in header_line:
                continue
            key, value = header_line.split(":", 1)
            headers[key.strip().lower()] = value.strip()

        disposition = headers.get("content-disposition", "")
        name_match = re.search(r'name="([^"]+)"', disposition)
        if name_match is None:
            continue
        field_name = name_match.group(1).strip()
        filename_match = re.search(r'filename="([^"]*)"', disposition)
        if filename_match is not None:
            result[field_name] = {
                "filename": filename_match.group(1),
                "contentType": headers.get("content-type", "application/octet-stream"),
                "data": body,
            }
        else:
            result[field_name] = body.decode("utf-8", errors="ignore").strip()
    return result


def _multipart_value(form: dict[str, Any], key: str) -> str:
    value = form.get(key)
    if isinstance(value, str):
        return value.strip()
    return ""


# ===========================================================================
# POST handlers (auth)
# ===========================================================================


def handle_admin_auth_login(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/auth/login"""
    from helpers import read_json_body
    body = read_json_body(handler)
    username = str(body.get("username", "")).strip()
    password = str(body.get("password", "")).strip()
    if not username or not password:
        json_error(handler, HTTPStatus.BAD_REQUEST, "管理员账号和密码不能为空")
        return

    account = find_admin_account_by_username(db, username, include_inactive=True)
    if account is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "管理员账号或密码错误")
        return
    if not verify_password(str(account.get("passwordHash", "")), password):
        json_error(handler, HTTPStatus.UNAUTHORIZED, "管理员账号或密码错误")
        return
    if not bool(account.get("active", True)):
        json_error(handler, HTTPStatus.FORBIDDEN, "该管理员账号已注销，请联系一级管理员")
        return

    token = secrets.token_urlsafe(24)
    with _globals.ADMIN_SESSION_LOCK:
        _globals.ADMIN_SESSIONS[token] = str(account.get("id", "")).strip()
    admin_payload = serialize_admin_auth_payload(account)
    add_audit_log(
        db,
        "",
        "admin_login",
        f"管理员登录:{account.get('username', '')}:{admin_payload.get('role', '')}",
    )
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {"token": token, **admin_payload}},
    )


def handle_admin_auth_logout(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/auth/logout"""
    admin, token = auth_admin(handler, db)
    if admin is None:
        return
    if token:
        with _globals.ADMIN_SESSION_LOCK:
            _globals.ADMIN_SESSIONS.pop(token, None)
    add_audit_log(db, "", "admin_logout", f"管理员退出: {admin.get('username', '')}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "管理员已退出", "data": {"ok": True}})


# ===========================================================================
# GET handlers
# ===========================================================================


def handle_admin_auth_me(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/auth/me"""
    admin = _require_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": serialize_admin_auth_payload(admin)})


def handle_admin_overview(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/overview"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": build_overview(db)})


def handle_admin_reviews(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/reviews"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    target_type = (query.get("type", [""])[0] or "").strip().lower()
    status = (query.get("status", [""])[0] or "").strip().lower()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_review_rows(db, target_type=target_type, status=status)})


def handle_admin_reports(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/reports"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", [""])[0] or "").strip().lower()
    reason = (query.get("reason", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_report_rows(db, status=status, reason=reason)})


def handle_admin_images_reviews(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/images/reviews"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    rows = []
    keyword = (query.get("keyword", [""])[0] or "").strip().lower()
    for upload in db.get("mediaUploads", []):
        if upload.get("deleted"):
            continue
        status = str(upload.get("status", "pending")).lower()
        if status not in {"pending", "risk"}:
            continue
        uploader = find_user_by_id(db, str(upload.get("uploaderId", "")))
        item = {
            "id": upload.get("id", ""),
            "url": upload.get("url", ""),
            "fileName": upload.get("fileName", ""),
            "contentType": upload.get("contentType", ""),
            "sizeBytes": int(upload.get("sizeBytes", 0)),
            "status": status,
            "moderationReason": upload.get("moderationReason", ""),
            "createdAt": upload.get("createdAt", ""),
            "postId": upload.get("postId", ""),
            "uploaderId": upload.get("uploaderId", ""),
            "uploaderAlias": uploader.get("nickname", "未知用户") if uploader else "未知用户",
        }
        if keyword:
            text = f"{item['uploaderAlias']} {item['fileName']}".lower()
            if keyword not in text:
                continue
        rows.append(item)
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_admin_users(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/users"""
    admin = _require_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": build_admin_user_rows(db, include_deleted=True)})


def handle_admin_post_pin_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/post-pin-requests"""
    admin = _require_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_post_pin_request_rows(db, status=status, keyword=keyword)})


def handle_admin_user_level_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/user-level-requests"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_user_level_request_rows(db, status=status, keyword=keyword)})


def handle_admin_admin_accounts(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/admin-accounts"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": build_admin_account_rows(db)})


def handle_admin_account_cancellation_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/account-cancellation-requests"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    from services import build_admin_account_cancellation_rows
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_account_cancellation_rows(db, status=status, keyword=keyword)})


def handle_admin_appeals(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/appeals"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_appeal_rows(db, status=status, keyword=keyword)})


def handle_admin_export(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/export"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    scope = (query.get("scope", ["users"])[0] or "users").strip().lower()
    export_format = (query.get("format", ["csv"])[0] or "csv").strip().lower()
    review_type = (query.get("reviewType", ["all"])[0] or "all").strip().lower()
    review_status = (query.get("reviewStatus", ["all"])[0] or "all").strip().lower()
    report_status = (query.get("reportStatus", ["all"])[0] or "all").strip().lower()
    appeal_status = (query.get("appealStatus", ["all"])[0] or "all").strip().lower()
    payload = build_export_payload(
        db,
        scope=scope,
        export_format=export_format,
        review_type=review_type,
        review_status=review_status,
        report_status=report_status,
        appeal_status=appeal_status,
    )
    send_json(handler, HTTPStatus.OK, {"data": payload})


def handle_admin_channels_tags(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/channels-tags"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "channels": db.get("channels", []),
                "tags": db.get("tags", []),
            }
        },
    )


def handle_admin_config(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/config"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "sensitiveWords": db.get("sensitiveWords", []),
                "rateLimitRules": _globals.public_system_settings().get("rateLimitRules", {}),
            }
        },
    )


def handle_admin_android_release(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/releases/android"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": get_android_release(db)})


def handle_public_android_release(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/releases/android/latest"""
    release = get_android_release(db)
    if release is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "当前暂无已发布的 Android 安装包")
        return
    send_json(handler, HTTPStatus.OK, {"data": release})


def handle_admin_announcements(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/announcements"""
    admin = _require_admin(handler, db)
    if admin is None:
        return
    rows = [serialize_system_announcement(row) for row in db.get("systemAnnouncements", [])]
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


# ===========================================================================
# POST handlers
# ===========================================================================


def handle_admin_change_password(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/auth/password"""
    admin = _require_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    old_password = str(body.get("oldPassword", "")).strip()
    new_password = str(body.get("newPassword", "")).strip()

    if len(new_password) < 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "新密码长度至少 6 位")
        return

    account = find_admin_account_by_id(db, str(admin.get("adminId", "")))
    if account is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "管理员账号不存在")
        return

    stored_hash = str(account.get("passwordHash", "")).strip()
    if stored_hash and not verify_password(stored_hash, old_password):
        json_error(handler, HTTPStatus.UNAUTHORIZED, "原密码错误")
        return

    account["passwordHash"] = hash_password(new_password)
    account["updatedAt"] = now_iso()
    clear_admin_sessions_for_account(str(admin.get("adminId", "")))
    add_audit_log(db, admin.get("adminId", "-"), "admin_change_password", "修改管理员密码")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "密码修改成功，请重新登录", "data": {"ok": True}})


def handle_admin_announcement(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/announcements"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    title = str(body.get("title", "")).strip()
    content = str(body.get("content", "")).strip()
    if not title or not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "标题和内容不能为空")
        return

    announcement = publish_system_announcement(db, admin=admin, title=title, content=content)
    add_audit_log(db, admin.get("adminId", "-"), "publish_announcement", f"发布系统公告: {title}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": serialize_system_announcement(announcement)})


def handle_admin_upload_android_release(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/releases/android"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    content_type = handler.headers.get("Content-Type", "").lower()
    if "multipart/form-data" not in content_type:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请使用表单上传 APK 文件")
        return

    try:
        form = _read_multipart_form(handler)
    except Exception:
        json_error(handler, HTTPStatus.BAD_REQUEST, "安装包表单解析失败")
        return

    version_name = _multipart_value(form, "versionName")
    version_code_raw = _multipart_value(form, "versionCode")
    release_notes = _multipart_value(form, "releaseNotes")
    force_update_raw = _multipart_value(form, "forceUpdate")

    if not version_name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请输入版本名称")
        return
    try:
        version_code = int(version_code_raw)
    except ValueError:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请输入合法的版本号")
        return
    if version_code <= 0:
        json_error(handler, HTTPStatus.BAD_REQUEST, "版本号必须大于 0")
        return

    file_field = form.get("file")
    if not isinstance(file_field, dict) or not str(file_field.get("filename", "")).strip():
        json_error(handler, HTTPStatus.BAD_REQUEST, "请选择要上传的 APK 文件")
        return

    file_name = os.path.basename(str(file_field.get("filename", "")).strip()) or "app-release.apk"
    if not file_name.lower().endswith(".apk"):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持上传 .apk 安装包")
        return

    file_bytes = file_field.get("data", b"")
    if not isinstance(file_bytes, (bytes, bytearray)) or not file_bytes:
        json_error(handler, HTTPStatus.BAD_REQUEST, "安装包内容不能为空")
        return
    if len(file_bytes) > 300 * 1024 * 1024:
        json_error(handler, HTTPStatus.BAD_REQUEST, "安装包大小不能超过 300MB")
        return

    try:
        stored = _globals.OBJECT_STORAGE.put_bytes(
            data=bytes(file_bytes),
            file_name=file_name,
            content_type="application/vnd.android.package-archive",
        )
    except Exception:
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "安装包上传失败，请稍后重试")
        return

    release = set_android_release(
        db,
        {
            "versionName": version_name,
            "versionCode": version_code,
            "releaseNotes": release_notes,
            "forceUpdate": parse_bool(force_update_raw) is True,
            "fileName": file_name,
            "contentType": "application/vnd.android.package-archive",
            "sizeBytes": len(file_bytes),
            "sha256": calc_sha256_hex(bytes(file_bytes)),
            "downloadUrl": stored.url,
            "objectKey": stored.key,
            "uploadedAt": now_iso(),
            "uploadedBy": str(admin.get("adminId", "")).strip(),
            "uploadedByUsername": str(admin.get("username", "")).strip(),
        },
    )
    add_audit_log(
        db,
        "",
        "publish_android_release",
        f"发布 Android 安装包 {release['versionName']} ({release['versionCode']})",
    )
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": release})


def handle_admin_review_batch(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/reviews/batch"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    items: list[dict[str, str]] = body.get("items", [])
    if not items:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少待处理项目")
        return

    from services import apply_admin_review_action
    results = []
    for item in items:
        target_type = str(item.get("type", "")).strip().lower()
        target_id = str(item.get("id", "")).strip()
        action = str(item.get("action", "")).strip().lower()
        try:
            apply_admin_review_action(db, target_type=target_type, target_id=target_id, action=action)
            results.append({"id": target_id, "ok": True})
        except (ValueError, LookupError) as e:
            results.append({"id": target_id, "ok": False, "error": str(e)})

    add_audit_log(db, admin.get("adminId", "-"), "batch_review", f"批量审核 {len(items)} 个项目")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"results": results}})


def handle_admin_single_review(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_type: str,
    target_id: str,
    action: str,
) -> None:
    """POST /api/admin/reviews/(post|comment)/<id>/(approve|reject|delete|risk)"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    try:
        from services import apply_admin_review_action
        apply_admin_review_action(db, target_type=target_type, target_id=target_id, action=action)
    except (ValueError, LookupError) as e:
        json_error(handler, HTTPStatus.BAD_REQUEST, str(e))
        return

    add_audit_log(db, admin.get("adminId", "-"), f"review_{action}", f"{target_type} {target_id} -> {action}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_report_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    report_id: str,
) -> None:
    """POST /api/admin/reports/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", "")).strip()

    report = next((r for r in db["reports"] if r.get("id") == report_id), None)
    if report is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "举报不存在")
        return

    handled_at = now_iso()
    report["handledAt"] = handled_at
    report["handledBy"] = str(admin.get("adminId", "")).strip()
    report["result"] = review_note

    action_map = {
        "resolve": "已处理",
        "delete": "已删除内容",
        "warn": "已警告",
        "ban": "已封禁",
        "misreport": "恶意举报",
    }
    if action in action_map:
        report["status"] = "resolved"
    elif action == "misreport":
        report["status"] = "misreport"
    else:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的处理动作")
        return

    target_type = str(report.get("targetType", "")).strip()
    target_id = str(report.get("targetId", "")).strip()
    owner = target_owner(db, target_id)
    owner_id = str(owner.get("authorId", "")).strip() if owner else ""

    if owner_id and action in {"delete", "warn", "ban"}:
        notif_title = "内容处理通知"
        notif_content = f"您发布的内容因「{review_note}」被处理，请注意社区规范。"
        if action == "ban":
            target_user = find_user_by_id(db, owner_id)
            if target_user:
                target_user["banned"] = True
                target_user["verified"] = False
                cancel_user_account(db, target_user, actor_id=admin.get("adminId", "-"), detail=f"因举报封禁 {owner_id}")
        create_notification(
            db,
            user_id=owner_id,
            notification_type="report_result",
            title=notif_title,
            content=notif_content,
            related_type=target_type,
            related_id=target_id,
            actor_id=str(admin.get("adminId", "")),
            actor_alias="管理员",
        )

    add_audit_log(db, admin.get("adminId", "-"), f"handle_report_{action}", f"处理举报 {report_id}: {action}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_post_pin_request_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/admin/post-pin-requests/<id>/handle"""
    admin = _require_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", "")).strip()

    req = next((r for r in db.get("postPinRequests", []) if r.get("id") == request_id), None)
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申请不存在")
        return

    post_id = str(req.get("postId", "")).strip()
    post = next((p for p in db["posts"] if p.get("id") == post_id), None)
    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申请已被处理")
        return

    req["status"] = action == "approve" and "approved" or "rejected"
    req["handledAt"] = now_iso()
    req["handledBy"] = str(admin.get("adminId", "")).strip()
    req["reviewNote"] = review_note or ""

    if post and action == "approve":
        from services import apply_post_pin
        apply_post_pin(
            post,
            duration_minutes=int(req.get("durationMinutes", 1440)),
        )

    owner_id = str(post.get("authorId", "")) if post else ""
    if owner_id:
        title = "置顶申请已通过" if action == "approve" else "置顶申请已驳回"
        content = f"您对帖子「{post.get('title', '未知')}」的置顶申请已被{'通过' if action == 'approve' else '驳回'}。"
        create_notification(
            db,
            user_id=owner_id,
            notification_type="system",
            title=title,
            content=content,
            related_type="post",
            related_id=post_id,
            actor_id=str(admin.get("adminId", "")),
            actor_alias="管理员",
        )

    add_audit_log(db, admin.get("adminId", "-"), f"handle_pin_request_{action}", f"处理置顶申请 {request_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_user_level_request_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/admin/user-level-requests/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", "")).strip()

    req = next((r for r in db.get("userLevelRequests", []) if r.get("id") == request_id), None)
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申请不存在")
        return

    user_id = str(req.get("userId", "")).strip()
    target_user = find_user_by_id(db, user_id)

    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申请已被处理")
        return

    req["status"] = action == "approve" and "approved" or "rejected"
    req["handledAt"] = now_iso()
    req["handledBy"] = str(admin.get("adminId", "")).strip()
    req["reviewNote"] = review_note or ""

    if target_user and action == "approve":
        target_user["userLevel"] = _globals.USER_LEVEL_ONE

    if target_user:
        title = "升级申请已通过" if action == "approve" else "升级申请已驳回"
        content = f"您的一级用户升级申请已被{'通过' if action == 'approve' else '驳回'}。"
        create_notification(
            db,
            user_id=user_id,
            notification_type="system",
            title=title,
            content=content,
            actor_id=str(admin.get("adminId", "")),
            actor_alias="管理员",
        )

    add_audit_log(db, admin.get("adminId", "-"), f"handle_level_request_{action}", f"处理升级申请 {request_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_create_account(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/admin-accounts"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    username = str(body.get("username", "")).strip()
    password = str(body.get("password", "")).strip()

    if not re.fullmatch(r"[A-Za-z0-9_.-]{3,32}", username):
        json_error(handler, HTTPStatus.BAD_REQUEST, "用户名格式不正确（3-32位字母数字下划线）")
        return
    if len(password) < 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "密码长度至少 6 位")
        return

    if find_admin_account_by_username(db, username) is not None:
        json_error(handler, HTTPStatus.CONFLICT, "用户名已存在")
        return

    from services import build_admin_account, next_id as svc_next_id
    account = build_admin_account(
        admin_id=svc_next_id(db, "adminAccount", "adm"),
        username=username,
        password_hash=hash_password(password),
        role=_globals.ADMIN_ROLE_SECONDARY,
        active=True,
        created_at=now_iso(),
        updated_at=now_iso(),
        created_by=str(admin.get("adminId", "")),
    )
    db["adminAccounts"].append(account)
    add_audit_log(db, admin.get("adminId", "-"), "create_admin_account", f"创建管理员账号 {username}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": serialize_admin_account(account)})


def handle_admin_account_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    account_id: str,
) -> None:
    """POST /api/admin/admin-accounts/<id>/action"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()

    account = find_admin_account_by_id(db, account_id, include_inactive=True)
    if account is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "管理员账号不存在")
        return

    if action == "deactivate":
        account["active"] = False
        account["updatedAt"] = now_iso()
        clear_admin_sessions_for_account(account_id)
        add_audit_log(db, admin.get("adminId", "-"), "deactivate_admin", f"注销管理员账号 {account_id}")
    elif action == "activate":
        account["active"] = True
        account["updatedAt"] = now_iso()
        add_audit_log(db, admin.get("adminId", "-"), "activate_admin", f"激活管理员账号 {account_id}")
    else:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的动作")
        return

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": serialize_admin_account(account)})


def handle_admin_user_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    user_id: str,
) -> None:
    """POST /api/admin/users/<id>/action"""
    admin = _require_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", "")).strip()

    target_user = find_user_by_id(db, user_id, include_deleted=True)
    if target_user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "用户不存在")
        return

    if action == "mute":
        target_user["muted"] = True
        add_audit_log(db, admin.get("adminId", "-"), "mute_user", f"禁言用户 {user_id}: {review_note}")
    elif action == "unmute":
        target_user["muted"] = False
        add_audit_log(db, admin.get("adminId", "-"), "unmute_user", f"解除禁言用户 {user_id}")
    elif action == "ban":
        target_user["banned"] = True
        target_user["verified"] = False
        cancel_user_account(db, target_user, actor_id=admin.get("adminId", "-"), detail=f"管理员封禁 {review_note}")
        add_audit_log(db, admin.get("adminId", "-"), "ban_user", f"封禁用户 {user_id}: {review_note}")
    elif action == "unban":
        target_user["banned"] = False
        target_user["deleted"] = False
        restore_user_account(db, target_user)
        add_audit_log(db, admin.get("adminId", "-"), "unban_user", f"解封用户 {user_id}")
    elif action == "cancel":
        cancel_user_account(db, target_user, actor_id=admin.get("adminId", "-"), detail=f"管理员注销账号 {review_note}")
        add_audit_log(db, admin.get("adminId", "-"), "cancel_user_account", f"注销用户 {user_id}: {review_note}")
    else:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的动作")
        return

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_appeal_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    appeal_id: str,
) -> None:
    """POST /api/admin/appeals/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", "")).strip()

    appeal = next((a for a in db.get("appeals", []) if a.get("id") == appeal_id), None)
    if appeal is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申诉不存在")
        return

    user_id = str(appeal.get("userId", "")).strip()
    target_user = find_user_by_id(db, user_id, include_deleted=True)

    if appeal.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申诉已被处理")
        return

    appeal["status"] = action == "approve" and "approved" or "rejected"
    appeal["handledAt"] = now_iso()
    appeal["handledBy"] = str(admin.get("adminId", "")).strip()
    appeal["result"] = review_note

    if action == "approve_restore" or (action == "approve" and appeal.get("appealType") == "account_restore"):
        if target_user:
            restore_user_account(db, target_user)
            create_notification(
                db,
                user_id=user_id,
                notification_type="system",
                title="账号已恢复",
                content=f"您的账号申诉已通过，账号已恢复使用。",
                actor_id=str(admin.get("adminId", "")),
                actor_alias="管理员",
            )
        add_audit_log(db, admin.get("adminId", "-"), "appeal_approve_restore", f"申诉通过并恢复账号 {user_id}")

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_cancellation_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/admin/account-cancellation-requests/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()

    req = next((r for r in db.get("accountCancellationRequests", []) if r.get("id") == request_id), None)
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申请不存在")
        return

    user_id = str(req.get("userId", "")).strip()
    target_user = find_user_by_id(db, user_id, include_deleted=True)

    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申请已被处理")
        return

    req["status"] = action == "approve" and "approved" or "rejected"
    req["handledAt"] = now_iso()
    req["handledBy"] = str(admin.get("adminId", "")).strip()

    if action == "approve" and target_user:
        cancel_user_account(db, target_user, actor_id=admin.get("adminId", "-"), detail="账号注销申请通过")
        sync_cancellation_requests_after_admin_cancel(
            db,
            user_id=user_id,
            handled_by=str(admin.get("adminId", "")).strip(),
            review_note="账号注销申请通过",
        )
        add_audit_log(db, admin.get("adminId", "-"), "approve_cancellation", f"通过账号注销申请 {user_id}")

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_image_review(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    upload_id: str,
) -> None:
    """POST /api/admin/images/<id>/review"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", "")).strip()

    upload = next((u for u in db.get("mediaUploads", []) if u.get("id") == upload_id), None)
    if upload is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "图片不存在")
        return

    action_map = {
        "approve": "approved",
        "reject": "rejected",
        "delete": "deleted",
        "risk": "risk",
    }
    if action not in action_map:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的审核动作")
        return

    new_status = action_map[action]
    upload["status"] = new_status
    upload["reviewedBy"] = str(admin.get("adminId", "")).strip()
    upload["reviewedAt"] = now_iso()
    upload["reviewNote"] = review_note

    post_id = str(upload.get("postId", "")).strip()
    if action in {"reject", "delete"}:
        try:
            object_key = str(upload.get("objectKey", "")).strip()
            if object_key:
                _globals.OBJECT_STORAGE.delete(object_key)
        except Exception:
            pass
        if post_id:
            recalc_post_has_image(db, post_id)

    if post_id:
        recalc_post_has_image(db, post_id)

    add_audit_log(db, admin.get("adminId", "-"), f"image_review_{action}", f"审核图片 {upload_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_add_channel(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/channels"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    channel = str(body.get("channel", "")).strip()
    if not channel:
        json_error(handler, HTTPStatus.BAD_REQUEST, "频道名称不能为空")
        return
    if channel in db.get("channels", []):
        json_error(handler, HTTPStatus.CONFLICT, "频道已存在")
        return

    db["channels"].append(channel)
    add_audit_log(db, admin.get("adminId", "-"), "add_channel", f"添加频道 {channel}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_add_tag(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/tags"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    tag = str(body.get("tag", "")).strip()
    if not tag:
        json_error(handler, HTTPStatus.BAD_REQUEST, "标签不能为空")
        return
    if tag in db.get("tags", []):
        json_error(handler, HTTPStatus.CONFLICT, "标签已存在")
        return

    db["tags"].append(tag)
    add_audit_log(db, admin.get("adminId", "-"), "add_tag", f"添加标签 {tag}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


# ===========================================================================
# PATCH handlers
# ===========================================================================


def handle_admin_rename_channel(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    old_name: str,
) -> None:
    """PATCH /api/admin/channels/<name>"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    new_name = str(body.get("channel", "")).strip()
    if not new_name or new_name == old_name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "频道名称不能为空或与原名称相同")
        return
    if new_name in db.get("channels", []):
        json_error(handler, HTTPStatus.CONFLICT, "新频道名称已存在")
        return

    channels = db.get("channels", [])
    idx = next((i for i, c in enumerate(channels) if c == old_name), -1)
    if idx < 0:
        json_error(handler, HTTPStatus.NOT_FOUND, "频道不存在")
        return

    channels[idx] = new_name
    for post in db.get("posts", []):
        if str(post.get("channel", "")).strip() == old_name:
            post["channel"] = new_name

    add_audit_log(db, admin.get("adminId", "-"), "rename_channel", f"重命名频道 {old_name} -> {new_name}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_rename_tag(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    old_name: str,
) -> None:
    """PATCH /api/admin/tags/<name>"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    new_name = str(body.get("tag", "")).strip()
    if not new_name or new_name == old_name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "标签不能为空或与原名称相同")
        return
    if new_name in db.get("tags", []):
        json_error(handler, HTTPStatus.CONFLICT, "新标签已存在")
        return

    tags = db.get("tags", [])
    idx = next((i for i, t in enumerate(tags) if t == old_name), -1)
    if idx < 0:
        json_error(handler, HTTPStatus.NOT_FOUND, "标签不存在")
        return

    tags[idx] = new_name
    for post in db.get("posts", []):
        post_tags = post.get("tags", [])
        if old_name in post_tags:
            post_tags = [t if t != old_name else new_name for t in post_tags]
            post["tags"] = post_tags

    add_audit_log(db, admin.get("adminId", "-"), "rename_tag", f"重命名标签 {old_name} -> {new_name}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_update_config(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/admin/config"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    words = body.get("sensitiveWords", [])
    if isinstance(words, list):
        db["sensitiveWords"] = [str(w).strip() for w in words if str(w).strip()]

    rules = body.get("rateLimitRules")
    if isinstance(rules, dict):
        rate_rules = db.get("settings", {}).get("rateLimitRules", {})
        if isinstance(rate_rules, dict):
            rate_rules.update(rules)
        else:
            db["settings"]["rateLimitRules"] = rules

    add_audit_log(db, admin.get("adminId", "-"), "update_config", "更新系统配置")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


# ===========================================================================
# DELETE handlers
# ===========================================================================


def handle_admin_delete_channel(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    name: str,
) -> None:
    """DELETE /api/admin/channels/<name>"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    channels = db.get("channels", [])
    if name not in channels:
        json_error(handler, HTTPStatus.NOT_FOUND, "频道不存在")
        return

    post_with_channel = next((p for p in db.get("posts", []) if not p.get("deleted") and p.get("channel") == name), None)
    if post_with_channel is not None:
        json_error(handler, HTTPStatus.CONFLICT, "该频道下仍有帖子，无法删除")
        return

    channels.remove(name)
    add_audit_log(db, admin.get("adminId", "-"), "delete_channel", f"删除频道 {name}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_delete_tag(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    name: str,
) -> None:
    """DELETE /api/admin/tags/<name>"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    tags = db.get("tags", [])
    if name not in tags:
        json_error(handler, HTTPStatus.NOT_FOUND, "标签不存在")
        return

    tags.remove(name)
    for post in db.get("posts", []):
        post_tags = post.get("tags", [])
        if name in post_tags:
            post["tags"] = [t for t in post_tags if t != name]

    add_audit_log(db, admin.get("adminId", "-"), "delete_tag", f"删除标签 {name}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})
