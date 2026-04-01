"""
handlers/_notification_handler.py

Notification endpoints:
  GET  /api/notifications                        — list notifications + unread count
  POST /api/notifications/read-all               — mark all as read
  GET  re("/api/notifications/([^/]+)/read")     — mark single notification as read
"""
from __future__ import annotations

from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import json_error, send_json
from services import (
    auth_user as auth_user_helper,
    find_user_by_id,
    load_db,
    save_db,
    serialize_notification,
    user_avatar_url,
)


def _serialize_notification_with_actor_avatar(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    payload = serialize_notification(row)
    actor_id = str(row.get("actorId", "")).strip()
    actor = find_user_by_id(db, actor_id, include_deleted=True) if actor_id else None
    payload["actorAvatarUrl"] = user_avatar_url(actor)
    return payload


def handle_get_notifications(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/notifications"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    rows = [
        _serialize_notification_with_actor_avatar(db, row)
        for row in db.get("notifications", [])
        if str(row.get("userId", "")).strip() == str(user.get("id", "")).strip()
        and not row.get("deleted")
    ]
    rows.sort(
        key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))),
        reverse=True,
    )
    unread_count = sum(1 for item in rows if not item.get("isRead"))
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {"items": rows, "unreadCount": unread_count}},
    )


def handle_mark_all_notifications_read(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/notifications/read-all"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    user_id = str(user.get("id", "")).strip()
    now = _globals.now_iso()
    changed = False
    for notif in db.get("notifications", []):
        if str(notif.get("userId", "")).strip() == user_id and not notif.get("deleted"):
            if not notif.get("isRead"):
                notif["isRead"] = True
                notif["readAt"] = now
                changed = True

    if changed:
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_mark_notification_read(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    notification_id: str,
) -> None:
    """GET /api/notifications/<id>/read"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    user_id = str(user.get("id", "")).strip()
    now = _globals.now_iso()
    target = None
    for notif in db.get("notifications", []):
        if notif.get("id") == notification_id and str(notif.get("userId", "")).strip() == user_id:
            target = notif
            break

    if target is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "通知不存在")
        return

    if not target.get("isRead"):
        target["isRead"] = True
        target["readAt"] = now
        save_db(db)

    send_json(
        handler,
        HTTPStatus.OK,
        {"data": _serialize_notification_with_actor_avatar(db, target)},
    )
