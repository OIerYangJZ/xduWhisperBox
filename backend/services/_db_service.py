from __future__ import annotations

import json
import logging
import os
from typing import Any

import _globals
from helpers._auth_helpers import (
    hash_password,
    is_password_hashed,
    normalize_avatar_url,
    normalize_media_url,
    sanitize_alias,
    student_id_from_email,
)
from helpers._datetime_helpers import now_iso, now_utc, parse_iso

logger = logging.getLogger(__name__)


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


def _safe_int(value: Any, default: int = 0) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError:
            return default
    return default


def _safe_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"true", "1", "yes", "on"}:
            return True
        if normalized in {"false", "0", "no", "off"}:
            return False
    return default


# ---------------------------------------------------------------------------
# Admin account helpers
# ---------------------------------------------------------------------------


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
        "username": normalize_admin_username(username) or normalize_admin_username(_globals.DEFAULT_ADMIN_USERNAME),
        "passwordHash": password_hash,
        "role": normalize_admin_role(role),
        "active": bool(active),
        "createdAt": created_at,
        "updatedAt": updated_at,
        "createdBy": created_by.strip(),
    }


def normalize_admin_username(value: str) -> str:
    return value.strip().lower()


def is_valid_admin_username(value: str) -> bool:
    import re
    return bool(re.fullmatch(r"[A-Za-z0-9_.-]{3,32}", value.strip()))


def normalize_admin_role(value: Any) -> str:
    role = str(value).strip().lower()
    if role == _globals.ADMIN_ROLE_PRIMARY:
        return _globals.ADMIN_ROLE_PRIMARY
    return _globals.ADMIN_ROLE_SECONDARY


def admin_role_label(role: str) -> str:
    return "一级管理员" if normalize_admin_role(role) == _globals.ADMIN_ROLE_PRIMARY else "二级管理员"


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
    with _globals.ADMIN_SESSION_LOCK:
        expired_tokens = [
            token
            for token, session_admin_id in _globals.ADMIN_SESSIONS.items()
            if str(session_admin_id).strip() == target
        ]
        for token in expired_tokens:
            _globals.ADMIN_SESSIONS.pop(token, None)


def auth_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> tuple[dict[str, Any] | None, str | None]:
    """Extract Bearer token, validate session, return (user, token) or (None, None)."""
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None
    token = auth_header[7:].strip()
    if not token:
        return None, None
    user_id = db["sessions"].get(token)
    if not user_id:
        return None, token
    user = _find_user_by_id_unsafe(db, user_id)
    return user, token


def _find_user_by_id_unsafe(db: dict[str, Any], user_id: str) -> dict[str, Any] | None:
    """Internal: find user by id without deleted check (caller decides)."""
    for user in db.get("users", []):
        if str(user.get("id", "")) == str(user_id):
            return user
    return None


def auth_admin(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> tuple[dict[str, Any] | None, str | None]:
    """Extract Bearer token, validate admin session, return (admin, token) or (None, None)."""
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None
    token = auth_header[7:].strip()
    if not token:
        return None, None
    with _globals.ADMIN_SESSION_LOCK:
        admin_id = _globals.ADMIN_SESSIONS.get(token)
    if not admin_id:
        return None, token
    account = find_admin_account_by_id(db, str(admin_id), include_inactive=True)
    if account is None or not bool(account.get("active", True)):
        with _globals.ADMIN_SESSION_LOCK:
            _globals.ADMIN_SESSIONS.pop(token, None)
        return None, token
    return build_authenticated_admin(account), token


def build_authenticated_admin(account: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(account.get("role"))
    return {
        "id": "",
        "adminId": str(account.get("id", "")).strip(),
        "username": normalize_admin_username(str(account.get("username", ""))),
        "role": role,
        "roleLabel": admin_role_label(role),
        "isPrimary": role == _globals.ADMIN_ROLE_PRIMARY,
        "isAdmin": True,
    }


def serialize_admin_auth_payload(admin: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(admin.get("role"))
    return {
        "username": str(admin.get("username", "")).strip(),
        "role": role,
        "roleLabel": admin_role_label(role),
        "isPrimary": role == _globals.ADMIN_ROLE_PRIMARY,
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


def ensure_admin_auth_settings(db: dict[str, Any]) -> bool:
    settings = db.get("settings")
    if not isinstance(settings, dict):
        settings = {}
        db["settings"] = settings
    changed = False
    username = str(settings.get(_globals.ADMIN_USERNAME_SETTING_KEY, "")).strip()
    if not username:
        settings[_globals.ADMIN_USERNAME_SETTING_KEY] = _globals.DEFAULT_ADMIN_USERNAME
        changed = True
    stored_password = str(settings.get(_globals.ADMIN_PASSWORD_HASH_SETTING_KEY, "")).strip()
    if not stored_password:
        settings[_globals.ADMIN_PASSWORD_HASH_SETTING_KEY] = hash_password(_globals.DEFAULT_ADMIN_PASSWORD)
        changed = True
    elif not is_password_hashed(stored_password):
        settings[_globals.ADMIN_PASSWORD_HASH_SETTING_KEY] = hash_password(stored_password)
        changed = True
    return changed


def get_admin_auth_credentials(db: dict[str, Any]) -> tuple[str, str]:
    ensure_admin_auth_settings(db)
    settings = db.get("settings", {})
    username = str(settings.get(_globals.ADMIN_USERNAME_SETTING_KEY, _globals.DEFAULT_ADMIN_USERNAME)).strip() or _globals.DEFAULT_ADMIN_USERNAME
    password_hash = str(settings.get(_globals.ADMIN_PASSWORD_HASH_SETTING_KEY, "")).strip()
    if not password_hash:
        password_hash = hash_password(_globals.DEFAULT_ADMIN_PASSWORD)
        settings[_globals.ADMIN_PASSWORD_HASH_SETTING_KEY] = password_hash
    return username, password_hash


def build_admin_account_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    rows = [
        serialize_admin_account(account)
        for account in db.get("adminAccounts", [])
        if normalize_admin_role(account.get("role")) == _globals.ADMIN_ROLE_SECONDARY
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


# ---------------------------------------------------------------------------
# Admin list row builders (used by _admin_handler)
# ---------------------------------------------------------------------------

def build_admin_user_rows(
    db: dict[str, Any],
    *,
    include_deleted: bool = False,
) -> list[dict[str, Any]]:
    """Return serialised user rows for admin user management."""
    from services._user_service import (
        current_user_level,
        latest_account_cancellation_request_for_user,
        latest_pending_appeal_for_user,
        latest_user_level_request_for_user,
        user_avatar_url,
        user_level_label,
        user_nickname,
    )

    rows: list[dict[str, Any]] = []
    for user in db.get("users", []):
        if user.get("deleted") and not include_deleted:
            continue
        uid = str(user.get("id", "")).strip()
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
            for post in db.get("posts", [])
            if not post.get("deleted") and str(post.get("authorId", "")).strip() == uid
        )
        comment_count = sum(
            1
            for comment in db.get("comments", [])
            if not comment.get("deleted") and str(comment.get("userId", "")).strip() == uid
        )
        report_count = sum(
            1
            for report in db.get("reports", [])
            if str(report.get("userId", "")).strip() == uid
        )
        level = current_user_level(user)
        rows.append(
            {
                "id": uid,
                "email": user.get("email", ""),
                "studentId": str(user.get("studentId", "")),
                "alias": user_nickname(user),
                "avatarUrl": user_avatar_url(user),
                "verified": bool(user.get("verified", False)),
                "userLevel": level,
                "userLevelLabel": user_level_label(level),
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


def build_admin_report_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    reason: str = "",
) -> list[dict[str, Any]]:
    """Return serialised report rows for admin."""
    normalized_status = status.strip().lower() or "all"
    normalized_reason = reason.strip()
    rows: list[dict[str, Any]] = []
    for report in db.get("reports", []):
        row_status = str(report.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        if normalized_reason and str(report.get("reason", "")) != normalized_reason:
            continue
        rows.append(
            {
                "id": report.get("id", ""),
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
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


def build_admin_account_cancellation_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    from services._user_service import serialize_account_cancellation_request

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
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return serialised appeal rows for admin."""
    from services._user_service import serialize_appeal

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


def build_admin_review_rows(
    db: dict[str, Any],
    *,
    target_type: str = "",
    status: str = "",
) -> list[dict[str, Any]]:
    """Return combined review rows (posts + comments)."""
    from services._user_service import find_user_by_id, user_nickname

    normalized_type = target_type.strip().lower() or "post"
    normalized_status = status.strip().lower() or "pending"
    rows: list[dict[str, Any]] = []

    if normalized_type == "post":
        for post in db.get("posts", []):
            row_status = str(post.get("reviewStatus", "approved")).strip().lower() or "approved"
            if normalized_status != "all" and row_status != normalized_status:
                continue
            author_user = find_user_by_id(
                db,
                str(post.get("authorId", "")).strip(),
                include_deleted=True,
            )
            rows.append(
                {
                    "id": post.get("id", ""),
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
        return rows

    if normalized_type == "comment":
        for comment in db.get("comments", []):
            row_status = str(comment.get("reviewStatus", "approved")).strip().lower() or "approved"
            if normalized_status != "all" and row_status != normalized_status:
                continue
            author_user = find_user_by_id(
                db,
                str(comment.get("userId", "")).strip(),
                include_deleted=True,
            )
            rows.append(
                {
                    "id": comment.get("id", ""),
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
        return rows

    raise ValueError("type 仅支持 post/comment")


def build_admin_user_level_request_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return user level upgrade request rows."""
    from services._user_service import serialize_admin_user_level_request

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


def build_admin_post_pin_request_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return post pin request rows."""
    from services._user_service import serialize_admin_post_pin_request

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


# ---------------------------------------------------------------------------
# Admin overview / stats
# ---------------------------------------------------------------------------

def build_overview(db: dict[str, Any]) -> dict[str, Any]:
    """Return admin overview stats."""
    users = [u for u in db.get("users", []) if not u.get("deleted")]
    posts = [p for p in db.get("posts", []) if not p.get("deleted")]
    reports_pending = [r for r in db.get("reports", []) if r.get("status") == "pending"]
    return {
        "totalUsers": len(users),
        "totalPosts": len(posts),
        "totalReports": len(db.get("reports", [])),
        "pendingReports": len(reports_pending),
        "totalComments": len([c for c in db.get("comments", []) if not c.get("deleted")]),
        "channels": list(db.get("channels", [])),
        "tags": list(db.get("tags", [])),
    }


def post_counts(db: dict[str, Any]) -> dict[str, int]:
    """Return per-channel post counts."""
    counts: dict[str, int] = {}
    for post in db.get("posts", []):
        if post.get("deleted"):
            continue
        channel = str(post.get("channel", ""))
        counts[channel] = counts.get(channel, 0) + 1
    return counts


def target_owner(db: dict[str, Any], post_id: str) -> dict[str, Any] | None:
    """Return the owner (authorId, authorAlias) of a post or comment."""
    for post in db.get("posts", []):
        if post.get("id") == post_id:
            return {
                "authorId": post.get("authorId", ""),
                "authorAlias": post.get("authorAlias", ""),
            }
    for comment in db.get("comments", []):
        if comment.get("id") == post_id:
            return {
                "authorId": comment.get("userId", ""),
                "authorAlias": comment.get("authorAlias", ""),
            }
    return None


# ---------------------------------------------------------------------------
# List helpers used by post / comment handlers
# ---------------------------------------------------------------------------

def list_posts(
    db: dict[str, Any],
    *,
    keyword: str = "",
    channel: str = "",
    has_image: bool | None = None,
    author_id: str = "",
    viewer_user_id: str = "",
    sort_by: str = "latest",
    include_rejected: bool = False,
) -> list[dict[str, Any]]:
    """Return filtered post rows."""
    posts = []
    for post in db.get("posts", []):
        if post.get("deleted"):
            continue
        if not include_rejected and post.get("reviewStatus") not in ("approved", "resolved"):
            continue
        if channel and post.get("channel") != channel:
            continue
        if has_image is True and not post.get("hasImage"):
            continue
        if has_image is False and post.get("hasImage"):
            continue
        if author_id and post.get("authorId") != author_id:
            continue
        if keyword:
            title = str(post.get("title", "")).lower()
            content = str(post.get("content", "")).lower()
            if keyword not in title and keyword not in content:
                continue
        post_id = str(post.get("id", "")).strip()
        post["likeCount"] = sum(
            1
            for like in db.get("likes", [])
            if str(like.get("postId", "")).strip() == post_id
        )
        post["commentCount"] = sum(
            1
            for comment in db.get("comments", [])
            if not comment.get("deleted")
            and str(comment.get("postId", "")).strip() == post_id
        )
        post["favoriteCount"] = sum(
            1
            for favorite_row in db.get("favorites", [])
            if str(favorite_row.get("postId", "")).strip() == post_id
        )
        post["viewCount"] = max(0, int(post.get("viewCount", 0) or 0))
        posts.append(post)
    if sort_by != "hot":
        posts.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return posts


def list_comments(
    db: dict[str, Any],
    post_id: str,
    viewer_user_id: str = "",
) -> list[dict[str, Any]]:
    """Return comments for a post."""
    comments = []
    for comment in db.get("comments", []):
        if comment.get("postId") != post_id:
            continue
        if comment.get("deleted"):
            continue
        status = str(comment.get("reviewStatus", "")).strip().lower()
        if status == "rejected":
            continue
        comments.append(comment)
    comments.sort(key=lambda x: str(x.get("createdAt", "") or ""))
    return comments


def build_export_payload(
    db: dict[str, Any],
    *,
    scope: str = "users",
    export_format: str = "csv",
    review_type: str = "all",
    review_status: str = "all",
    report_status: str = "all",
    appeal_status: str = "all",
) -> dict[str, Any]:
    """Build export payload for admin data export."""
    import csv
    import io

    rows: list[list[str]] = []
    headers: list[str] = []
    if scope == "users":
        headers = ["id", "email", "nickname", "studentId", "userLevel", "verified", "banned", "createdAt"]
        for user in db.get("users", []):
            if user.get("deleted"):
                continue
            rows.append([
                str(user.get("id", "")),
                str(user.get("email", "")),
                str(user.get("nickname", "")),
                str(user.get("studentId", "")),
                str(user.get("userLevel", 2)),
                str(bool(user.get("verified"))),
                str(bool(user.get("banned"))),
                str(user.get("createdAt", "")),
            ])
    elif scope == "posts":
        headers = ["id", "title", "channel", "authorAlias", "createdAt", "reviewStatus"]
        for post in db.get("posts", []):
            if post.get("deleted"):
                continue
            rows.append([
                str(post.get("id", "")),
                str(post.get("title", "")),
                str(post.get("channel", "")),
                str(post.get("authorAlias", "")),
                str(post.get("createdAt", "")),
                str(post.get("reviewStatus", "")),
            ])
    elif scope == "reports":
        headers = ["id", "reason", "status", "createdAt"]
        for report in db.get("reports", []):
            rows.append([
                str(report.get("id", "")),
                str(report.get("reason", "")),
                str(report.get("status", "")),
                str(report.get("createdAt", "")),
            ])

    output = ""
    if export_format == "csv":
        si = io.StringIO()
        writer = csv.writer(si)
        writer.writerow(headers)
        writer.writerows(rows)
        output = si.getvalue()
    else:
        output = json.dumps({"headers": headers, "rows": rows}, ensure_ascii=False)

    return {"format": export_format, "data": output}


# ---------------------------------------------------------------------------
# Legacy stubs / aliases (handlers expect these at module level)
# ---------------------------------------------------------------------------

# Backward-compat constant
IS_SQL_DB = False


# Public system settings for unauthenticated endpoints
def public_system_settings(db: dict[str, Any]) -> dict[str, Any]:
    """Return public system settings (channels, tags, rate limits)."""
    return {
        "channels": list(db.get("channels", [])),
        "tags": list(db.get("tags", [])),
        "settings": dict(db.get("settings", {})),
    }


def serialize_android_release(raw: dict[str, Any]) -> dict[str, Any]:
    return {
        "platform": "android",
        "versionName": str(raw.get("versionName", "")).strip(),
        "versionCode": _safe_int(raw.get("versionCode"), 0),
        "releaseNotes": str(raw.get("releaseNotes", "")).strip(),
        "forceUpdate": _safe_bool(raw.get("forceUpdate"), False),
        "fileName": str(raw.get("fileName", "")).strip(),
        "contentType": str(
            raw.get("contentType", "application/vnd.android.package-archive"),
        ).strip()
        or "application/vnd.android.package-archive",
        "sizeBytes": max(0, _safe_int(raw.get("sizeBytes"), 0)),
        "sha256": str(raw.get("sha256", "")).strip().lower(),
        "downloadUrl": normalize_media_url(
            str(raw.get("downloadUrl", raw.get("url", ""))).strip(),
        ),
        "objectKey": str(raw.get("objectKey", "")).strip(),
        "uploadedAt": str(raw.get("uploadedAt", raw.get("createdAt", ""))).strip(),
        "uploadedBy": str(raw.get("uploadedBy", "")).strip(),
        "uploadedByUsername": str(raw.get("uploadedByUsername", "")).strip(),
    }


def get_android_release(db: dict[str, Any]) -> dict[str, Any] | None:
    settings = db.get("settings", {})
    if not isinstance(settings, dict):
        return None
    raw = settings.get("androidRelease")
    if not isinstance(raw, dict):
        return None
    release = serialize_android_release(raw)
    if not release.get("versionName") or not release.get("downloadUrl"):
        return None
    return release


def set_android_release(db: dict[str, Any], release: dict[str, Any]) -> dict[str, Any]:
    db.setdefault("settings", {})
    if not isinstance(db["settings"], dict):
        db["settings"] = {}
    serialized = serialize_android_release(release)
    db["settings"]["androidRelease"] = serialized
    return serialized


# Pagination metadata builder
def build_pagination_meta(
    total: int,
    page: int = 1,
    per_page: int = 20,
) -> dict[str, Any]:
    """Build pagination metadata dict."""
    total_pages = max(1, (total + per_page - 1) // per_page)
    return {
        "total": total,
        "page": page,
        "perPage": per_page,
        "totalPages": total_pages,
    }


# Admin report serialiser
def serialize_admin_report(report: dict[str, Any]) -> dict[str, Any]:
    """Serialize a report row for admin display."""
    return {
        "id": report.get("id", ""),
        "reporterAlias": str(report.get("reporterAlias", "匿名")),
        "reportedAlias": str(report.get("reportedAlias", "匿名")),
        "reason": str(report.get("reason", "")),
        "status": str(report.get("status", "pending")),
        "createdAt": str(report.get("createdAt", "")),
    }


# Admin image row builders
def build_admin_image_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    """Return serialised image upload rows for admin moderation."""
    rows = []
    for upload in db.get("mediaUploads", []):
        rows.append({
            "id": upload.get("id", ""),
            "url": normalize_media_url(str(upload.get("url", ""))),
            "fileName": upload.get("fileName", ""),
            "contentType": upload.get("contentType", ""),
            "status": upload.get("status", "pending"),
            "uploaderId": upload.get("uploaderId", ""),
            "postId": upload.get("postId", ""),
            "createdAt": upload.get("createdAt", ""),
        })
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


def build_image_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    """Return serialised image rows (public-facing)."""
    rows = []
    for upload in db.get("mediaUploads", []):
        status = str(upload.get("status", ""))
        if status not in ("approved", ""):
            continue
        rows.append({
            "id": upload.get("id", ""),
            "url": normalize_media_url(str(upload.get("url", ""))),
            "fileName": upload.get("fileName", ""),
            "contentType": upload.get("contentType", ""),
            "sizeBytes": int(upload.get("sizeBytes", 0)),
            "createdAt": upload.get("createdAt", ""),
        })
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


# Image upload serialiser
def serialize_image_upload(upload: dict[str, Any]) -> dict[str, Any]:
    """Serialize an image upload row."""
    return {
        "id": upload.get("id", ""),
        "url": normalize_media_url(str(upload.get("url", ""))),
        "fileName": upload.get("fileName", ""),
        "contentType": upload.get("contentType", ""),
        "sizeBytes": int(upload.get("sizeBytes", 0)),
        "status": upload.get("status", "pending"),
        "createdAt": upload.get("createdAt", ""),
        "postId": upload.get("postId", ""),
        "uploaderId": upload.get("uploaderId", ""),
    }


# Appeal row builder (lighter variant used by server.py handlers)
def build_appeal_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    """Return serialised appeal rows for admin."""
    rows = []
    for appeal in db.get("appeals", []):
        rows.append({
            "id": appeal.get("id", ""),
            "userId": appeal.get("userId", ""),
            "reason": appeal.get("reason", ""),
            "status": appeal.get("status", "pending"),
            "createdAt": appeal.get("createdAt", ""),
        })
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


# Handlers also reference get_setting_int from services
def get_setting_int(db: dict[str, Any], key: str, default: int, *, minimum: int = 1) -> int:
    settings = db.get("settings", {})
    if isinstance(settings, dict):
        try:
            return max(minimum, int(settings.get(key, default)))
        except (TypeError, ValueError):
            return max(minimum, default)
    return max(minimum, default)


# Serialize helpers for post/comment handlers
def serialize_post(
    db: dict[str, Any],
    post: dict[str, Any],
    viewer_user_id: str = "",
    *,
    include_unapproved_images: bool = False,
) -> dict[str, Any]:
    from services._user_service import (
        can_request_dm_from_post,
        can_request_dm_to_user,
        effective_post_allow_dm,
        is_post_anonymous,
        is_post_pin_active,
        is_post_private,
        is_user_following,
        parse_pin_duration_minutes,
        pin_duration_label,
        user_avatar_url,
    )

    post_id = str(post.get("id", "")).strip()
    author_id = str(post.get("authorId", "")).strip()
    is_anonymous = is_post_anonymous(db, post)
    is_private = is_post_private(post)
    author_user = None
    for user in db.get("users", []):
        if str(user.get("id", "")).strip() == author_id:
            author_user = user
            break

    comment_count = sum(
        1
        for comment in db.get("comments", [])
        if not comment.get("deleted") and str(comment.get("postId", "")).strip() == post_id
    )
    like_count = sum(
        1
        for like in db.get("likes", [])
        if str(like.get("postId", "")).strip() == post_id
    )
    favorite_count = sum(
        1
        for favorite_row in db.get("favorites", [])
        if str(favorite_row.get("postId", "")).strip() == post_id
    )
    liked = bool(
        viewer_user_id
        and any(
            x
            for x in db.get("likes", [])
            if x.get("userId") == viewer_user_id and x.get("postId") == post_id
        )
    )
    favorited = bool(
        viewer_user_id
        and any(
            x
            for x in db.get("favorites", [])
            if x.get("userId") == viewer_user_id and x.get("postId") == post_id
        )
    )

    image_urls: list[str] = []
    uploaded_image_ids: list[str] = []
    for upload in db.get("mediaUploads", []):
        if str(upload.get("postId", "")).strip() != post_id:
            continue
        status = str(upload.get("status", "")).strip().lower()
        if status not in {"", "approved"} and not include_unapproved_images:
            continue
        upload_id = str(upload.get("id", "")).strip()
        upload_url = normalize_media_url(str(upload.get("url", "")).strip())
        if upload_id:
            uploaded_image_ids.append(upload_id)
        if upload_url:
            image_urls.append(upload_url)

    can_view_author_profile = bool(
        viewer_user_id
        and not is_anonymous
        and not is_private
        and author_id
        and author_user is not None
    )
    can_follow_author = bool(
        can_view_author_profile and viewer_user_id != author_id
    )
    is_following_author = bool(
        can_follow_author and is_user_following(db, viewer_user_id, author_id)
    )
    can_message_author = bool(
        can_view_author_profile
        and viewer_user_id != author_id
        and can_request_dm_from_post(
            db,
            viewer_user_id=viewer_user_id,
            post=post,
        )
    )

    return {
        "id": post_id,
        "title": post.get("title", ""),
        "content": post.get("content", ""),
        "contentFormat": "markdown" if str(post.get("contentFormat", "")).strip().lower() == "markdown" else "plain",
        "markdownSource": str(post.get("markdownSource", "")),
        "channel": post.get("channel", ""),
        "tags": post.get("tags", []),
        "authorAlias": post.get("authorAlias", "匿名同学"),
        "isAnonymous": is_anonymous,
        "authorAvatarUrl": "" if is_anonymous else user_avatar_url(author_user),
        "authorUserId": author_id if can_view_author_profile else "",
        "createdAt": post.get("createdAt", ""),
        "updatedAt": post.get("updatedAt", ""),
        "hasImage": bool(post.get("hasImage", False)) or bool(image_urls),
        "imageUrls": image_urls,
        "uploadedImageIds": uploaded_image_ids,
        "commentCount": comment_count,
        "likeCount": like_count,
        "favoriteCount": favorite_count,
        "viewCount": max(0, int(post.get("viewCount", 0) or 0)),
        "liked": liked,
        "favorited": favorited,
        "status": post.get("status", "ongoing"),
        "allowComment": bool(post.get("allowComment", True)),
        "allowDm": effective_post_allow_dm(db, post),
        "visibility": str(post.get("visibility", "public")),
        "isPrivate": is_private,
        "isPinned": is_post_pin_active(post),
        "pinStartedAt": post.get("pinStartedAt", ""),
        "pinExpiresAt": post.get("pinExpiresAt", ""),
        "pinDurationMinutes": parse_pin_duration_minutes(post.get("pinDurationMinutes")) or 0,
        "pinDurationLabel": pin_duration_label(post.get("pinDurationMinutes")),
        "canViewAuthorProfile": can_view_author_profile,
        "canFollowAuthor": can_follow_author,
        "isFollowingAuthor": is_following_author,
        "canMessageAuthor": can_message_author,
        "isOwnPost": bool(viewer_user_id and viewer_user_id == author_id),
    }


def serialize_comment(db: dict[str, Any], comment: dict[str, Any], viewer_user_id: str = "") -> dict[str, Any]:
    from services._user_service import user_avatar_url

    author_id = str(comment.get("userId", "")).strip()
    author_user = None
    for u in db.get("users", []):
        if str(u.get("id", "")) == author_id:
            author_user = u
            break
    liked = bool(
        viewer_user_id
        and any(
            x for x in db.get("likes", [])
            if x.get("userId") == viewer_user_id and x.get("commentId") == comment.get("id")
        )
    )
    return {
        "id": comment.get("id", ""),
        "postId": comment.get("postId", ""),
        "content": comment.get("content", ""),
        "authorAlias": comment.get("authorAlias", "匿名同学"),
        "authorId": author_id,
        "authorAvatarUrl": user_avatar_url(author_user) if author_user else "",
        "likeCount": max(0, int(comment.get("likeCount", 0) or 0)),
        "liked": liked,
        "createdAt": comment.get("createdAt", ""),
        "isAnonymous": bool(comment.get("isAnonymous", True)),
        "reviewStatus": str(comment.get("reviewStatus", "approved")),
    }


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
    legacy_username = normalize_admin_username(legacy_username) or normalize_admin_username(_globals.DEFAULT_ADMIN_USERNAME)
    if not is_password_hashed(legacy_password_hash):
        legacy_password_hash = hash_password(legacy_password_hash)
        changed = True

    if not db["adminAccounts"]:
        db["adminAccounts"].append(
            build_admin_account(
                admin_id=next_id(db, "adminAccount", "adm"),
                username=legacy_username,
                password_hash=legacy_password_hash,
                role=_globals.ADMIN_ROLE_PRIMARY,
                active=True,
                created_at=timestamp,
                updated_at=timestamp,
                created_by="system",
            )
        )
        changed = True

    default_admin = find_admin_account_by_username(
        db,
        _globals.DEFAULT_ADMIN_USERNAME,
        include_inactive=True,
    )
    if default_admin is not None:
        if normalize_admin_role(default_admin.get("role")) != _globals.ADMIN_ROLE_PRIMARY:
            default_admin["role"] = _globals.ADMIN_ROLE_PRIMARY
            default_admin["updatedAt"] = timestamp
            changed = True
        if not bool(default_admin.get("active", True)):
            default_admin["active"] = True
            default_admin["updatedAt"] = timestamp
            changed = True

    if not any(
        normalize_admin_role(account.get("role")) == _globals.ADMIN_ROLE_PRIMARY
        for account in db.get("adminAccounts", [])
    ):
        first_account = db["adminAccounts"][0]
        first_account["role"] = _globals.ADMIN_ROLE_PRIMARY
        first_account["updatedAt"] = timestamp
        changed = True

    return changed


# ---------------------------------------------------------------------------
# Database service — schema migration, seeding, persistence
# ---------------------------------------------------------------------------


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
                "id": _globals.DEMO_USER_ID,
                "email": _globals.DEMO_USER_EMAIL,
                "password": hash_password(_globals.DEMO_USER_PASSWORD),
                "alias": "洞主-雾蓝",
                "nickname": "洞主-雾蓝",
                "studentId": "2023000001",
                "avatarUrl": "",
                "userLevel": _globals.USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": True,
                "showContactable": True,
                "notifyComment": True,
                "notifyReply": True,
                "notifyLike": True,
                "notifyFavorite": True,
                "notifyReportResult": True,
                "notifySystem": True,
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
                "userLevel": _globals.USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": False,
                "showContactable": False,
                "notifyComment": True,
                "notifyReply": True,
                "notifyLike": True,
                "notifyFavorite": True,
                "notifyReportResult": True,
                "notifySystem": True,
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
                "userLevel": _globals.USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": False,
                "showContactable": False,
                "notifyComment": True,
                "notifyReply": True,
                "notifyLike": True,
                "notifyFavorite": True,
                "notifyReportResult": True,
                "notifySystem": True,
                "createdAt": created,
                "deleted": False,
                "isAdmin": False,
                "banned": False,
                "muted": False,
            },
        ],
        "sessions": {},
        "emailCodes": {},
        "channels": list(_globals.DEFAULT_CHANNELS),
        "tags": list(_globals.DEFAULT_TAGS),
        "sensitiveWords": list(_globals.DEFAULT_SENSITIVE_WORDS),
        "settings": {
            **dict(_globals.DEFAULT_SETTINGS),
            _globals.ADMIN_USERNAME_SETTING_KEY: _globals.DEFAULT_ADMIN_USERNAME,
            _globals.ADMIN_PASSWORD_HASH_SETTING_KEY: hash_password(_globals.DEFAULT_ADMIN_PASSWORD),
        },
        "adminAccounts": [
            build_admin_account(
                admin_id="adm1",
                username=_globals.DEFAULT_ADMIN_USERNAME,
                password_hash=hash_password(_globals.DEFAULT_ADMIN_PASSWORD),
                role=_globals.ADMIN_ROLE_PRIMARY,
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
        "userFollows": [],
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
        "postViews": [],
    }

    for row in _globals.SEED_POSTS:
        db["seq"]["post"] += 1
        post_id = f"p{db['seq']['post']}"
        db["posts"].append(
            {
                "id": post_id,
                "title": row["title"],
                "content": row["content"],
                "contentFormat": str(row.get("contentFormat", "plain") or "plain"),
                "markdownSource": str(row.get("markdownSource", "") or ""),
                "channel": row["channel"],
                "tags": row["tags"],
                "hasImage": row["hasImage"],
                "status": row["status"],
                "allowComment": row["allowComment"],
                "allowDm": row["allowDm"],
                "visibility": str(row.get("visibility", "public") or "public"),
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
            "id": "req1", "toUserId": "u1", "fromAlias": "同学-海盐",
            "fromUserId": "seed-user-1", "fromAvatarUrl": "",
            "reason": "想咨询图书馆座位信息", "createdAt": created, "status": "pending",
        }
    )
    db["dmRequests"].append(
        {
            "id": "req2", "toUserId": "u1", "fromAlias": "同学-留白",
            "fromUserId": "seed-user-2", "fromAvatarUrl": "",
            "reason": "想问二手显示器细节", "createdAt": created, "status": "pending",
        }
    )
    db["seq"]["request"] = 2

    db["conversations"].append(
        {
            "id": "c1", "userId": "u1", "peerUserId": "seed-user-1",
            "name": "洞主-极光", "avatarUrl": "",
            "lastMessage": "谢谢，已经找到位置了。",
            "unreadCount": 0, "lastReadAt": created, "updatedAt": created, "deleted": False,
        }
    )
    db["seq"]["conversation"] = 1
    db["directMessages"].append(
        {
            "id": "m1", "conversationKey": "seed-user-1::u1",
            "senderUserId": "seed-user-1", "receiverUserId": "u1",
            "content": "谢谢，已经找到位置了。",
            "createdAt": created, "readAt": created, "deleted": False,
        }
    )
    db["seq"]["message"] = 1

    db["comments"].append(
        {
            "id": "cm1", "postId": "p1", "userId": "seed-user-2",
            "authorAlias": "匿名同学-1", "content": "教研楼三层东边插座比较多。",
            "createdAt": created, "deleted": False, "likeCount": 0,
            "reviewStatus": "approved", "riskMarked": False,
        }
    )
    db["comments"].append(
        {
            "id": "cm2", "postId": "p1", "userId": "seed-user-1",
            "authorAlias": "匿名同学-2", "content": "新图二层靠窗位置不错，但中午人多。",
            "createdAt": created, "deleted": False, "likeCount": 0,
            "reviewStatus": "approved", "riskMarked": False,
        }
    )
    db["seq"]["comment"] = 2

    db["reports"].append(
        {
            "id": "r1", "userId": "u1", "reporterAlias": "洞主-雾蓝",
            "targetType": "post", "targetId": "p2",
            "reason": "广告引流", "description": "疑似卖课引流",
            "status": "pending", "result": "", "createdAt": created,
            "handledAt": "", "handledBy": "",
        }
    )
    db["seq"]["report"] = 1

    return db


def ensure_db() -> None:
    _globals.SQL_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    first_boot = not _globals.SQL_DB_FILE.exists()
    _globals.REPOSITORY.initialize(default_db)

    default_sql_path = (_globals.DATA_DIR / "treehole.db").resolve()
    current_sql_path = _globals.SQL_DB_FILE.resolve()
    import_legacy_json = os.environ.get("BACKEND_IMPORT_LEGACY_JSON", "").strip() == "1"

    if (
        first_boot
        and _globals.LEGACY_DB_FILE.exists()
        and (current_sql_path == default_sql_path or import_legacy_json)
    ):
        try:
            with _globals.LEGACY_DB_FILE.open("r", encoding="utf-8") as f:
                legacy_db = json.load(f)
            if isinstance(legacy_db, dict):
                migrate_db(legacy_db)
                _globals.REPOSITORY.save_state(legacy_db)
        except Exception:
            pass


def save_db(db: dict[str, Any]) -> None:
    _globals.SQL_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    _globals.REPOSITORY.save_state(db)


def migrate_db(db: dict[str, Any]) -> bool:
    changed = False

    if "channels" not in db:
        db["channels"] = list(_globals.DEFAULT_CHANNELS)
        changed = True
    elif not isinstance(db.get("channels"), list):
        db["channels"] = list(_globals.DEFAULT_CHANNELS)
        changed = True
    else:
        for default_channel in _globals.DEFAULT_CHANNELS:
            if default_channel not in db["channels"]:
                db["channels"].append(default_channel)
                changed = True

    if "tags" not in db:
        db["tags"] = list(_globals.DEFAULT_TAGS)
        changed = True
    if "sensitiveWords" not in db:
        db["sensitiveWords"] = list(_globals.DEFAULT_SENSITIVE_WORDS)
        changed = True
    if "settings" not in db or not isinstance(db["settings"], dict):
        db["settings"] = dict(_globals.DEFAULT_SETTINGS)
        changed = True
    for key, value in _globals.DEFAULT_SETTINGS.items():
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
    else:
        normalized_follows: list[dict[str, Any]] = []
        seen_follows: set[tuple[str, str]] = set()
        for follow in db.get("userFollows", []):
            if not isinstance(follow, dict):
                changed = True
                continue
            follower_user_id = str(
                follow.get("followerUserId")
                or follow.get("followerId")
                or ""
            ).strip()
            followee_user_id = str(
                follow.get("followeeUserId")
                or follow.get("followeeId")
                or follow.get("followedId")
                or ""
            ).strip()
            if not follower_user_id or not followee_user_id or follower_user_id == followee_user_id:
                changed = True
                continue
            follow_key = (follower_user_id, followee_user_id)
            if follow_key in seen_follows:
                changed = True
                continue
            seen_follows.add(follow_key)
            normalized_follows.append(
                {
                    "followerUserId": follower_user_id,
                    "followeeUserId": followee_user_id,
                    "createdAt": str(follow.get("createdAt", "")).strip() or _globals.now_iso(),
                }
            )
        if normalized_follows != db.get("userFollows", []):
            db["userFollows"] = normalized_follows
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
        "user", "adminAccount", "post", "comment", "report",
        "cancellation", "request", "conversation", "message",
        "notification", "announcement", "appeal", "pinRequest",
        "levelRequest", "audit", "upload",
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
                changed = True

    for post in db.get("posts", []):
        for k, v in {
            "pinStartedAt": "", "pinExpiresAt": "", "pinDurationMinutes": 0,
            "updatedAt": str(post.get("createdAt", now_iso())),
            "reviewStatus": "approved", "riskMarked": False,
            "deleted": False, "allowComment": True, "allowDm": True, "visibility": "public",
            "contentFormat": "plain", "markdownSource": "", "viewCount": 0,
        }.items():
            if k not in post:
                post[k] = v
                changed = True
        normalized_content_format = "markdown" if str(post.get("contentFormat", "plain")).strip().lower() == "markdown" else "plain"
        if normalized_content_format != str(post.get("contentFormat", "plain")):
            post["contentFormat"] = normalized_content_format
            changed = True
        if normalized_content_format != "markdown" and str(post.get("markdownSource", "")).strip():
            post["markdownSource"] = ""
            changed = True
        if normalized_content_format == "markdown" and not str(post.get("markdownSource", "")).strip():
            post["markdownSource"] = str(post.get("content", ""))
            changed = True
        normalized_visibility = "private" if str(post.get("visibility", "public")).strip().lower() == "private" else "public"
        if normalized_visibility != str(post.get("visibility", "public")):
            post["visibility"] = normalized_visibility
            changed = True
        if "isAnonymous" not in post:
            author_alias = str(post.get("authorAlias", "")).strip()
            author_id = str(post.get("authorId", "")).strip()
            if author_alias and author_id:
                post["isAnonymous"] = author_alias not in [
                    str(u.get("nickname", "")).strip()
                    for u in db.get("users", [])
                    if str(u.get("id", "")) == author_id
                ]
            else:
                post["isAnonymous"] = True
            changed = True

    for comment in db.get("comments", []):
        for k, v in {
            "likeCount": 0, "authorAlias": "匿名同学",
            "deleted": False, "reviewStatus": "approved",
            "riskMarked": False, "isAnonymous": True,
        }.items():
            if k not in comment:
                comment[k] = v
                changed = True

    for notification in db.get("notifications", []):
        for k, v in {
            "relatedType": "", "relatedId": "", "actorId": "",
            "actorAlias": "", "deleted": False, "readAt": "",
        }.items():
            if k not in notification:
                notification[k] = v
                changed = True

    for announcement in db.get("systemAnnouncements", []):
        if "createdBy" not in announcement:
            announcement["createdBy"] = ""
            changed = True

    for upload in db.get("mediaUploads", []):
        for k, v in {
            "objectKey": "", "moderationReason": "", "reviewNote": "",
            "reviewedBy": "", "reviewedAt": "", "sha256": "",
            "deleted": False, "uploaderId": "",
        }.items():
            if k not in upload:
                upload[k] = v
                changed = True

    return changed


def load_db() -> dict[str, Any]:
    return _globals.REPOSITORY.load_state()
