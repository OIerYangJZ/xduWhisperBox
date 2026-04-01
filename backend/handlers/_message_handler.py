"""
handlers/_message_handler.py

Direct-message & conversation endpoints:
  GET  /api/messages/requests                          — list received DM requests
  POST /api/messages/requests                          — send a DM request
  POST re("/api/messages/requests/([^/]+)/(accept|reject)") — accept/reject DM request
  GET  /api/messages/conversations                     — list DM conversations
  POST /api/messages/conversations/direct             — find or create conversation directly
  GET  re("/api/messages/conversations/([^/]+)/messages") — list messages in conversation
  POST re("/api/messages/conversations/([^/]+)/messages") — send a message
  DELETE re("/api/messages/conversations/([^/]+)")     — delete own conversation
  POST re("/api/messages/conversations/([^/]+)/(block|unblock)") — block/unblock peer
"""
from __future__ import annotations

from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    assess_text_risk,
    check_ip_rate_limit,
    consume_rate_limit,
    is_campus_email,
    json_error,
    now_iso,
    now_utc,
    parse_iso,
    read_json_body,
    sanitize_alias,
    send_rate_limit_error,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    can_request_dm_from_post,
    can_request_dm_to_user,
    conversation_block_state,
    deliver_message_to_conversation_pair,
    effective_post_allow_dm,
    find_user_by_id,
    get_setting_int,
    is_post_anonymous,
    is_user_blocked,
    list_comments,
    mark_conversation_read,
    next_id,
    post_counts,
    refresh_conversation_pair_metadata,
    reject_pending_dm_requests_between,
    save_db,
    serialize_direct_message,
    serialize_notification,
    serialize_post,
    sync_conversation_pair,
    user_avatar_url,
    user_nickname,
)


def _require_auth(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    """Short-hand for requiring an authorized user."""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None
    return user


def _resolve_post_dm_target(
    db: dict[str, Any],
    *,
    from_post_id: str,
    target_user_id: str,
) -> tuple[dict[str, Any] | None, str, str | None]:
    post = next(
        (
            item
            for item in db.get("posts", [])
            if str(item.get("id", "")).strip() == from_post_id
            and not item.get("deleted")
        ),
        None,
    )
    if post is None:
        return None, "", "帖子不存在"
    author_id = str(post.get("authorId", "")).strip()
    if target_user_id and target_user_id != author_id:
        return None, "", "帖子作者与私信目标不一致"
    return post, author_id, None


def _conversations_for_user(
    db: dict[str, Any],
    user_id: str,
) -> list[dict[str, Any]]:
    rows = [x for x in db["conversations"] if x.get("userId") == user_id and not x.get("deleted")]
    rows.sort(key=lambda x: x.get("updatedAt", ""), reverse=True)
    return rows


def handle_get_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/messages/requests"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if user.get("muted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法发送私信申请")
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
        from_avatar = user_avatar_url(from_user)
        if not from_avatar:
            from_avatar = _globals.normalize_avatar_url(str(row.get("fromAvatarUrl", "")))
        status_label = {
            "pending": "待处理",
            "accepted": "已同意",
            "rejected": "已拒绝",
        }.get(status, status)
        requests.append({
            "id": row.get("id"),
            "fromAlias": from_alias,
            "fromAvatarUrl": from_avatar,
            "reason": row.get("reason", "请求联系"),
            "timeText": _globals.iso_to_time_text(row.get("createdAt")),
            "status": status,
            "statusLabel": status_label,
            "createdAt": row.get("createdAt", ""),
            "updatedAt": row.get("updatedAt", ""),
        })

    requests.sort(key=lambda x: x.get("updatedAt", "") or x.get("createdAt", ""), reverse=True)
    requests.sort(key=lambda x: 0 if x.get("status") == "pending" else 1)
    send_json(handler, HTTPStatus.OK, {"data": requests})


def handle_send_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/messages/requests"""
    user = _require_auth(handler, db)
    if user is None:
        return

    body = read_json_body(handler)
    target_user_id = str(body.get("targetUserId", "")).strip()
    post_id = str(body.get("postId") or body.get("fromPostId") or "").strip()
    reason = str(body.get("reason", "想认识你")).strip()
    if len(reason) > 120:
        json_error(handler, HTTPStatus.BAD_REQUEST, "私信申请理由不能超过 120 个字符")
        return

    post = None
    if post_id:
        post, target_user_id, error_message = _resolve_post_dm_target(
            db,
            from_post_id=post_id,
            target_user_id=target_user_id,
        )
        if error_message:
            status = HTTPStatus.BAD_REQUEST if error_message == "帖子作者与私信目标不一致" else HTTPStatus.NOT_FOUND
            json_error(handler, status, error_message)
            return
        if str(post.get("reviewStatus", "approved")).lower() == "rejected":
            json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在")
            return
        if is_post_anonymous(db, post):
            json_error(handler, HTTPStatus.BAD_REQUEST, "匿名帖子不支持通过帖子发起私信")
            return
        if not effective_post_allow_dm(db, post):
            target = find_user_by_id(db, str(post.get("authorId", "")).strip())
            if target is not None and not bool(target.get("allowStrangerDm", True)):
                json_error(handler, HTTPStatus.FORBIDDEN, "对方暂不接受私信")
            else:
                json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子未开启私信")
            return

    if not target_user_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少联系对象")
        return
    if target_user_id == user["id"]:
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能给自己发送私信申请")
        return

    target = find_user_by_id(db, target_user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "联系对象不存在")
        return

    if post is not None:
        if not can_request_dm_from_post(
            db,
            viewer_user_id=str(user.get("id", "")),
            post=post,
        ):
            if not bool(target.get("allowStrangerDm", True)):
                json_error(handler, HTTPStatus.FORBIDDEN, "对方暂不接受私信")
                return
            if is_user_blocked(db, user["id"], target_user_id):
                json_error(handler, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发起私信")
                return
            if is_user_blocked(db, target_user_id, user["id"]):
                json_error(handler, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发起私信")
                return
            json_error(handler, HTTPStatus.FORBIDDEN, "当前无法发起私信")
            return
    elif not can_request_dm_to_user(
        db,
        viewer_user_id=str(user.get("id", "")),
        target_user_id=target_user_id,
    ):
        if not bool(target.get("showContactable", True)):
            json_error(handler, HTTPStatus.FORBIDDEN, "对方当前未开放联系入口")
            return
        if not bool(target.get("allowStrangerDm", True)):
            json_error(handler, HTTPStatus.FORBIDDEN, "对方暂不接受私信")
            return
        if is_user_blocked(db, user["id"], target_user_id):
            json_error(handler, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发起私信")
            return
        if is_user_blocked(db, target_user_id, user["id"]):
            json_error(handler, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发起私信")
            return
        json_error(handler, HTTPStatus.FORBIDDEN, "当前无法发起私信")
        return

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="dm_request",
        setting_key="dmRequestRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["dmRequestRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="发送私信申请",
            retry_after_seconds=retry_after,
        )
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
            handler,
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

    existing = next(
        (r for r in db["dmRequests"]
         if r.get("fromUserId") == user["id"] and r.get("toUserId") == target_user_id
         and r.get("status") == "pending"),
        None,
    )
    if existing:
        send_json(
            handler,
            HTTPStatus.OK,
            {
                "message": "私信申请已发送，请等待对方处理",
                "data": existing,
            },
        )
        return

    created_at = now_iso()
    req = {
        "id": next_id(db, "request", "req"),
        "toUserId": target_user_id,
        "fromUserId": user["id"],
        "fromAlias": user_nickname(user),
        "fromAvatarUrl": user_avatar_url(user),
        "postId": post_id,
        "reason": reason or "想和你继续交流这个话题",
        "status": "pending",
        "createdAt": created_at,
        "updatedAt": created_at,
    }
    db["dmRequests"].append(req)
    add_audit_log(
        db,
        user["id"],
        "create_dm_request",
        f"to={target_user_id} post={post_id or '-'}",
    )
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "私信申请已发送",
            "data": req,
        },
    )


def handle_accept_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/messages/requests/<id>/accept"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if user.get("muted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法发送消息")
        return

    req = next(
        (r for r in db["dmRequests"] if r.get("id") == request_id and r.get("toUserId") == user["id"]),
        None,
    )
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "请求不存在")
        return
    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "请求已被处理")
        return

    req["status"] = "accepted"
    req["updatedAt"] = now_iso()
    sync_conversation_pair(
        db,
        left_user_id=user["id"],
        right_user_id=str(req.get("fromUserId", "")),
        last_message="已同意私信申请，开始聊天吧。",
        updated_at=str(req.get("updatedAt", "")),
    )
    add_audit_log(db, user["id"], "accept_dm_request", f"接受来自 {req.get('fromUserId')} 的私信请求")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_reject_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/messages/requests/<id>/reject"""
    user = _require_auth(handler, db)
    if user is None:
        return

    req = next(
        (r for r in db["dmRequests"] if r.get("id") == request_id and r.get("toUserId") == user["id"]),
        None,
    )
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "请求不存在")
        return
    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "请求已被处理")
        return

    req["status"] = "rejected"
    req["updatedAt"] = now_iso()
    add_audit_log(db, user["id"], "reject_dm_request", f"拒绝来自 {req.get('fromUserId')} 的私信请求")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_get_conversations(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/messages/conversations"""
    user = _require_auth(handler, db)
    if user is None:
        return

    rows = _conversations_for_user(db, user["id"])
    result = []
    for row in rows:
        peer_user_id = str(row.get("peerUserId", "")).strip()
        peer_user = find_user_by_id(db, peer_user_id)
        name = user_nickname(peer_user) if peer_user else sanitize_alias(
            str(row.get("name", "")), fallback="匿名同学",
        )
        avatar_url = user_avatar_url(peer_user)
        if not avatar_url:
            avatar_url = _globals.normalize_avatar_url(str(row.get("avatarUrl", "")))
        blocked_by_me, blocked_by_peer = conversation_block_state(
            db,
            viewer_user_id=str(user.get("id", "")),
            peer_user_id=peer_user_id,
        )
        unread_count = max(0, int(row.get("unreadCount", 0) or 0))
        result.append({
            "id": row.get("id"),
            "peerUserId": peer_user_id,
            "name": name,
            "avatarUrl": avatar_url,
            "lastMessage": row.get("lastMessage", "") or "开始聊天吧",
            "timeText": _globals.iso_to_time_text(row.get("updatedAt")),
            "unreadCount": unread_count,
            "hasUnread": unread_count > 0,
            "blockedByMe": blocked_by_me,
            "blockedByPeer": blocked_by_peer,
        })

    send_json(handler, HTTPStatus.OK, {"data": result})


def handle_direct_conversation(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/messages/conversations/direct — find or create conversation directly (WeChat-style)"""
    user = _require_auth(handler, db)
    if user is None:
        return

    body = read_json_body(handler)
    target_user_id = str(body.get("targetUserId", "")).strip()
    post_id = str(body.get("postId") or body.get("fromPostId") or "").strip()
    post: dict[str, Any] | None = None

    if post_id:
        post, target_user_id, error_message = _resolve_post_dm_target(
            db,
            from_post_id=post_id,
            target_user_id=target_user_id,
        )
        if error_message:
            status = HTTPStatus.BAD_REQUEST if error_message == "帖子作者与私信目标不一致" else HTTPStatus.NOT_FOUND
            json_error(handler, status, error_message)
            return
        if is_post_anonymous(db, post):
            json_error(handler, HTTPStatus.BAD_REQUEST, "匿名帖子不支持通过帖子发起私信")
            return
        if not effective_post_allow_dm(db, post):
            target_user = find_user_by_id(db, str(post.get("authorId", "")).strip())
            if target_user is not None and not bool(target_user.get("allowStrangerDm", True)):
                json_error(handler, HTTPStatus.FORBIDDEN, "对方暂不接受私信")
            else:
                json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子未开启私信")
            return

    if not target_user_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少目标用户")
        return
    if target_user_id == user["id"]:
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能给自己发私信")
        return

    target_user = find_user_by_id(db, target_user_id)
    if target_user is None or target_user.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在")
        return

    if is_user_blocked(db, user["id"], target_user_id):
        json_error(handler, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发私信")
        return
    if is_user_blocked(db, target_user_id, user["id"]):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发私信")
        return

    now = now_iso()
    existing = next(
        (
            row
            for row in db.get("conversations", [])
            if row.get("userId") == user["id"] and row.get("peerUserId") == target_user_id
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
            handler,
            HTTPStatus.OK,
            {
                "data": {
                    "id": existing.get("id"),
                    "peerUserId": target_user_id,
                    "name": user_nickname(target_user),
                    "avatarUrl": user_avatar_url(target_user),
                    "lastMessage": existing.get("lastMessage", "") or "开始聊天吧",
                    "timeText": _globals.iso_to_time_text(existing.get("updatedAt")),
                    "unreadCount": max(0, int(existing.get("unreadCount", 0) or 0)),
                    "hasUnread": int(existing.get("unreadCount", 0) or 0) > 0,
                    "blockedByMe": blocked_by_me,
                    "blockedByPeer": blocked_by_peer,
                }
            },
        )
        return

    if post is not None:
        if not can_request_dm_from_post(
            db,
            viewer_user_id=str(user.get("id", "")),
            post=post,
        ):
            if not bool(target_user.get("allowStrangerDm", True)):
                json_error(handler, HTTPStatus.FORBIDDEN, "对方暂不接受私信")
                return
            json_error(handler, HTTPStatus.FORBIDDEN, "当前无法发起私信")
            return
    elif not can_request_dm_to_user(
        db,
        viewer_user_id=str(user.get("id", "")),
        target_user_id=target_user_id,
    ):
        if not bool(target_user.get("showContactable", True)):
            json_error(handler, HTTPStatus.FORBIDDEN, "对方当前未开放联系入口")
            return
        if not bool(target_user.get("allowStrangerDm", True)):
            json_error(handler, HTTPStatus.FORBIDDEN, "对方暂不接受私信")
            return
        json_error(handler, HTTPStatus.FORBIDDEN, "当前无法发起私信")
        return

    sync_conversation_pair(
        db,
        left_user_id=user["id"],
        right_user_id=target_user_id,
        last_message="开始聊天吧",
        updated_at=now,
    )
    add_audit_log(db, user["id"], "create_direct_conversation", f"与用户 {target_user_id} 创建私信会话")
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
    if new_conv is None:
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "会话创建失败")
        return
    send_json(
        handler,
        HTTPStatus.CREATED,
        {
            "data": {
                "id": new_conv.get("id", ""),
                "peerUserId": target_user_id,
                "name": user_nickname(target_user),
                "avatarUrl": user_avatar_url(target_user),
                "lastMessage": "开始聊天吧",
                "timeText": _globals.iso_to_time_text(now),
                "unreadCount": 0,
                "hasUnread": False,
                "blockedByMe": False,
                "blockedByPeer": False,
            }
        },
    )


def handle_get_messages(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """GET /api/messages/conversations/<id>/messages"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"] and not c.get("deleted")),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    if is_user_blocked(db, user["id"], peer_user_id):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方已将你屏蔽，无法查看消息")
        return

    conv_key = _globals.conversation_key_for_users(str(user.get("id", "")), peer_user_id)
    messages = [
        serialize_direct_message(
            db,
            msg,
            viewer_user_id=str(user.get("id", "")),
        )
        for msg in db.get("directMessages", [])
        if msg.get("conversationKey") == conv_key and not msg.get("deleted")
    ]
    messages.sort(key=lambda m: (m.get("createdAt", ""), m.get("id", "")))

    changed = mark_conversation_read(
        db,
        user_id=str(user.get("id", "")),
        conversation=conv,
    )
    if changed:
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": messages})


def handle_send_message(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """POST /api/messages/conversations/<id>/messages"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"] and not c.get("deleted")),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    if is_user_blocked(db, user["id"], peer_user_id):
        json_error(handler, HTTPStatus.FORBIDDEN, "你已屏蔽对方，无法发送消息")
        return
    if is_user_blocked(db, peer_user_id, user["id"]):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方已将你屏蔽，暂时无法发送消息")
        return
    conversation_key = _globals.conversation_key_for_users(
        str(user.get("id", "")),
        peer_user_id,
    )

    body = read_json_body(handler)
    content = str(body.get("content", "")).strip()
    reply_to_id = str(body.get("replyToId", "")).strip()
    if not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "消息内容不能为空")
        return
    if len(content) > 1000:
        json_error(handler, HTTPStatus.BAD_REQUEST, "单条消息不能超过 1000 个字符")
        return

    reply_to_sender = ""
    reply_to_content = ""
    if reply_to_id:
        reply_message = next(
            (
                item
                for item in db.get("directMessages", [])
                if str(item.get("id", "")).strip() == reply_to_id
                and str(item.get("conversationKey", "")).strip() == conversation_key
                and not item.get("deleted")
            ),
            None,
        )
        if reply_message is None:
            json_error(handler, HTTPStatus.BAD_REQUEST, "回复的消息不存在或已被撤回")
            return
        reply_sender_user = find_user_by_id(
            db,
            str(reply_message.get("senderUserId", "")).strip(),
            include_deleted=True,
        )
        reply_to_sender = user_nickname(reply_sender_user)
        reply_to_content = str(reply_message.get("content", "")).strip()

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="message",
        setting_key="messageRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["messageRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="发送私信",
            retry_after_seconds=retry_after,
        )
        return
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "message")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="发送私信",
            retry_after_seconds=ip_retry_after,
        )
        return

    _, high_risk, risk_reasons = assess_text_risk(db, content)
    if high_risk:
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            f"消息触发高风险风控：{'; '.join(risk_reasons)}",
        )
        add_audit_log(db, user["id"], "risk_block_message", ";".join(risk_reasons))
        save_db(db)
        return

    created_at = now_iso()
    message = {
        "id": next_id(db, "message", "m"),
        "conversationKey": conversation_key,
        "senderUserId": str(user.get("id", "")),
        "receiverUserId": peer_user_id,
        "content": content,
        "replyToId": reply_to_id,
        "replyToSender": reply_to_sender,
        "replyToContent": reply_to_content,
        "createdAt": created_at,
        "readAt": "",
        "deleted": False,
    }
    db.setdefault("directMessages", []).append(message)
    deliver_message_to_conversation_pair(
        db,
        sender_user_id=str(user.get("id", "")),
        receiver_user_id=peer_user_id,
        last_message=content,
        updated_at=created_at,
    )
    add_audit_log(db, user["id"], "send_message", f"向用户 {peer_user_id} 发送私信: {content[:20]}")
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "发送成功",
            "data": serialize_direct_message(
                db,
                message,
                viewer_user_id=str(user.get("id", "")),
            ),
        },
    )


def handle_delete_conversation(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """DELETE /api/messages/conversations/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"] and not c.get("deleted")),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    conv["deleted"] = True
    add_audit_log(db, user["id"], "delete_conversation", f"删除与用户 {conv.get('peerUserId')} 的私信会话")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_block_peer(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """POST /api/messages/conversations/<id>/block"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"]),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    if not is_user_blocked(db, user["id"], peer_user_id):
        blocked_at = now_iso()
        db["userBlocks"].append({
            "blockerUserId": user["id"],
            "blockedUserId": peer_user_id,
            "createdAt": blocked_at,
        })
        reject_pending_dm_requests_between(
            db,
            left_user_id=user["id"],
            right_user_id=peer_user_id,
            updated_at=blocked_at,
        )
        add_audit_log(db, user["id"], "block_user", f"屏蔽用户 {peer_user_id}")
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"blocked": True}})


def handle_unblock_peer(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """POST /api/messages/conversations/<id>/unblock"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"]),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    db["userBlocks"][:] = [
        b for b in db["userBlocks"]
        if not (
            b.get("blockerUserId") == user["id"]
            and b.get("blockedUserId") == peer_user_id
        )
    ]
    add_audit_log(db, user["id"], "unblock_user", f"解除屏蔽用户 {peer_user_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"blocked": False}})


def handle_message_recall(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    message_id: str,
) -> None:
    """DELETE /api/messages/messages/<id>/recall"""
    user = _require_auth(handler, db)
    if user is None:
        return

    parsed = handler.path.split("?")
    query_params = {}
    if len(parsed) > 1:
        from urllib.parse import parse_qs
        query_params = parse_qs(parsed[1])

    conversation_id = query_params.get("conversationId", [None])[0]
    if not conversation_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少 conversationId 参数")
        return

    conv = next(
        (
            c
            for c in db.get("conversations", [])
            if c.get("id") == conversation_id and c.get("userId") == user["id"]
        ),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    conv_key = _globals.conversation_key_for_users(user["id"], peer_user_id)

    msg = next(
        (
            m
            for m in db.get("directMessages", [])
            if m.get("id") == message_id
            and m.get("conversationKey") == conv_key
            and not m.get("deleted")
        ),
        None,
    )
    if msg is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "消息不存在")
        return

    if msg.get("senderUserId") != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能撤回自己的消息")
        return

    msg_created = parse_iso(msg.get("createdAt"))
    if msg_created is None:
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "消息时间解析失败")
        return

    elapsed = (now_utc() - msg_created).total_seconds()
    if elapsed > 120:
        json_error(handler, HTTPStatus.BAD_REQUEST, "消息已超过 2 分钟，无法撤回")
        return

    msg["deleted"] = True
    refresh_conversation_pair_metadata(
        db,
        left_user_id=str(msg.get("senderUserId", "")).strip(),
        right_user_id=str(msg.get("receiverUserId", "")).strip(),
        updated_at=now_iso(),
    )
    add_audit_log(db, user["id"], "recall_message", f"撤回消息: {message_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})
