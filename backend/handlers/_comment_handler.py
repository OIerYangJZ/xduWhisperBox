"""
handlers/_comment_handler.py

User account management & standalone comment endpoints:
  POST /api/users/me/cancellation-request   — submit account cancellation request
  POST /api/users/me/level-upgrade-request — submit level-1 user upgrade request
  DELETE re("/api/comments/([^/]+)")        — delete own comment (also in _post_handler.py)
"""
from __future__ import annotations

import re
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    json_error,
    now_iso,
    read_json_body,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    find_user_by_id,
    latest_account_cancellation_request_for_user,
    latest_pending_appeal_for_user,
    latest_user_level_request_for_user,
    next_id,
    normalize_user_level,
    save_db,
    serialize_account_cancellation_request,
    serialize_user_level_request_summary,
    user_nickname,
)


def _require_auth(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None
    return user


def handle_cancel_account_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/users/me/cancellation-request"""
    user = _require_auth(handler, db)
    if user is None:
        return

    existing = latest_account_cancellation_request_for_user(db, user["id"])
    if existing is not None:
        json_error(handler, HTTPStatus.CONFLICT, "已有待处理的注销申请")
        return

    body = read_json_body(handler)
    reason = str(body.get("reason", "用户主动申请注销")).strip()

    req = {
        "id": next_id(db, "cancellation", "cr"),
        "userId": user["id"],
        "email": str(user.get("email", "")).strip().lower(),
        "reason": reason,
        "status": "pending",
        "result": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db["accountCancellationRequests"].append(req)
    add_audit_log(db, user["id"], "request_cancellation", f"申请注销账号: {reason}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": serialize_account_cancellation_request(req)})


def handle_level_upgrade_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/users/me/level-upgrade-request"""
    user = _require_auth(handler, db)
    if user is None:
        return

    current = normalize_user_level(user.get("userLevel"))
    if current == _globals.USER_LEVEL_ONE:
        json_error(handler, HTTPStatus.CONFLICT, "您已是一级用户，无需申请")
        return

    existing = latest_user_level_request_for_user(db, user["id"])
    if existing is not None:
        json_error(handler, HTTPStatus.CONFLICT, "已有待处理的升级申请")
        return

    body = read_json_body(handler)
    reason = str(body.get("reason", "")).strip()

    req = {
        "id": next_id(db, "levelRequest", "lr"),
        "userId": user["id"],
        "email": str(user.get("email", "")).strip().lower(),
        "currentLevel": current,
        "targetLevel": _globals.USER_LEVEL_ONE,
        "reason": reason,
        "status": "pending",
        "adminNote": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db["userLevelRequests"].append(req)
    add_audit_log(
        db,
        user["id"],
        "request_level_upgrade",
        "申请升级为一级用户" if not reason else f"申请升级为一级用户: {reason}",
    )
    save_db(db)
    send_json(
        handler,
        HTTPStatus.CREATED,
        {
            "message": "一级用户申请已提交，请等待一级管理员审核",
            "data": serialize_user_level_request_summary(req),
        },
    )
