"""
handlers/_user_handler.py

User profile & social endpoints:
  GET  /api/users/me                           — own profile
  GET  re("/api/users/([^/]+)")                 — public user profile
  PATCH /api/users/me                          — update own profile
  PATCH /api/users/privacy                     — update privacy settings
  POST re("/api/users/([^/]+)/(follow|unfollow)") — follow/unfollow
  GET  /api/users/me/following                  — list following
  GET  /api/users/me/followers                  — list followers
  GET  /api/users/me/friends                    — list mutual follows
"""
from __future__ import annotations

import re
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    is_valid_student_id,
    json_error,
    normalize_avatar_url,
    normalize_media_url,
    read_json_body,
    sanitize_alias,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    current_user_level,
    find_user_by_id,
    is_user_following,
    is_level_one_user,
    latest_account_cancellation_request_for_user,
    latest_user_level_request_for_user,
    list_posts,
    list_follower_users,
    list_following_users,
    list_friend_users,
    normalize_optional_bool,
    save_db,
    search_public_users,
    serialize_account_cancellation_request,
    serialize_public_user_profile,
    serialize_user_level_request_summary,
    user_avatar_url,
    user_level_label,
    user_nickname,
)


def handle_get_me(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    uid = str(user.get("id", "")).strip()
    cancellation_req = latest_account_cancellation_request_for_user(db, uid)
    level_req = latest_user_level_request_for_user(db, uid)
    favorite_post_ids = {
        str(x.get("postId", ""))
        for x in db.get("favorites", [])
        if x.get("userId") == user["id"]
    }
    favorite_count = sum(
        1
        for post in list_posts(db)
        if str(post.get("id", "")) in favorite_post_ids
    )

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "id": uid,
                "alias": user_nickname(user),
                "nickname": user_nickname(user),
                "studentId": str(user.get("studentId", "")).strip(),
                "avatarUrl": user_avatar_url(user),
                "bio": str(user.get("bio", "")).strip(),
                "gender": str(user.get("gender", "")).strip(),
                "backgroundImageUrl": normalize_media_url(str(user.get("backgroundImageUrl", "")).strip()),
                "verified": bool(user.get("verified")),
                "verifiedAt": str(user.get("verifiedAt", "")).strip(),
                "allowStrangerDm": bool(user.get("allowStrangerDm", True)),
                "showContactable": bool(user.get("showContactable", True)),
                "notifyComment": bool(user.get("notifyComment", True)),
                "notifyReply": bool(user.get("notifyReply", True)),
                "notifyLike": bool(user.get("notifyLike", True)),
                "notifyFavorite": bool(user.get("notifyFavorite", True)),
                "notifyReportResult": bool(user.get("notifyReportResult", True)),
                "notifySystem": bool(user.get("notifySystem", True)),
                "favoriteCount": favorite_count,
                "isAdmin": bool(user.get("isAdmin", False)),
                "userLevel": current_user_level(user),
                "userLevelLabel": user_level_label(current_user_level(user)),
                "isLevelOneUser": is_level_one_user(user),
                "email": str(user.get("email", "")).strip(),
                "levelUpgradeRequest": serialize_user_level_request_summary(level_req) if level_req else None,
                "accountCancellationRequest": serialize_account_cancellation_request(cancellation_req) if cancellation_req else None,
                "createdAt": str(user.get("createdAt", "")).strip(),
                "deleted": bool(user.get("deleted", False)),
                "banned": bool(user.get("banned", False)),
                "muted": bool(user.get("muted", False)),
            }
        },
    )


def handle_get_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    user_id: str,
) -> None:
    """GET /api/users/<id>"""
    viewer, _ = auth_user_helper(handler, db)
    if viewer is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return
    target = find_user_by_id(db, user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "用户不存在")
        return

    viewer_id = str(viewer.get("id", "")) if viewer else ""
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": serialize_public_user_profile(
                db,
                target_user=target,
                viewer_user_id=viewer_id,
            )
        },
    )


def handle_search_users(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/users/search?keyword=..."""
    viewer, _ = auth_user_helper(handler, db)
    if viewer is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    keyword = str((query.get("keyword") or [""])[0]).strip()
    if not keyword:
        send_json(handler, HTTPStatus.OK, {"data": []})
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": search_public_users(
                db,
                viewer_user_id=str(viewer.get("id", "")).strip(),
                keyword=keyword,
            )
        },
    )


def handle_update_me(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/users/me"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    new_nickname = sanitize_alias(str(body.get("nickname", "")), fallback="")
    new_avatar = normalize_avatar_url(str(body.get("avatarUrl", "")))
    new_background_image = normalize_media_url(str(body.get("backgroundImageUrl", "")))
    new_student_id = str(body.get("studentId", "")).strip()
    new_bio = str(body.get("bio", "")).strip()
    new_gender = str(body.get("gender", "")).strip()

    if new_student_id and not is_valid_student_id(new_student_id):
        json_error(handler, HTTPStatus.BAD_REQUEST, "学号格式不正确（需为 6-20 位字母或数字）")
        return
    if len(new_bio) > 100:
        json_error(handler, HTTPStatus.BAD_REQUEST, "个性签名不能超过 100 个字符")
        return
    if new_gender not in {"", "男", "女"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "性别仅支持：男、女")
        return

    if new_nickname and new_nickname != user_nickname(user):
        user["nickname"] = new_nickname
        user["alias"] = new_nickname
        add_audit_log(db, user["id"], "update_nickname", f"更新昵称为 {new_nickname}")

    if new_avatar:
        user["avatarUrl"] = new_avatar

    if new_student_id:
        user["studentId"] = new_student_id

    user["bio"] = new_bio
    user["gender"] = new_gender
    user["backgroundImageUrl"] = new_background_image

    add_audit_log(db, user["id"], "update_profile", "更新个人资料")
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "ok": True,
                "nickname": user_nickname(user),
                "bio": str(user.get("bio", "")).strip(),
                "gender": str(user.get("gender", "")).strip(),
                "backgroundImageUrl": normalize_media_url(str(user.get("backgroundImageUrl", "")).strip()),
            }
        },
    )


def handle_update_privacy(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/users/privacy"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    user["allowStrangerDm"] = normalize_optional_bool(
        body.get("allowStrangerDm"),
        default=True,
    )
    user["showContactable"] = normalize_optional_bool(
        body.get("showContactable"),
        default=True,
    )
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_update_notification_preferences(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/users/notification-preferences"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    user["notifyComment"] = normalize_optional_bool(
        body.get("notifyComment"),
        default=True,
    )
    user["notifyReply"] = normalize_optional_bool(
        body.get("notifyReply"),
        default=True,
    )
    user["notifyLike"] = normalize_optional_bool(
        body.get("notifyLike"),
        default=True,
    )
    user["notifyFavorite"] = normalize_optional_bool(
        body.get("notifyFavorite"),
        default=True,
    )
    user["notifyReportResult"] = normalize_optional_bool(
        body.get("notifyReportResult"),
        default=True,
    )
    user["notifySystem"] = normalize_optional_bool(
        body.get("notifySystem"),
        default=True,
    )
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_follow(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_user_id: str,
) -> None:
    """POST /api/users/<id>/follow"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    if target_user_id == user["id"]:
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能关注自己")
        return

    target = find_user_by_id(db, target_user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在")
        return

    already = is_user_following(db, user["id"], target_user_id)
    if already:
        send_json(handler, HTTPStatus.OK, {"data": {"followed": True, "already": True}})
        return

    db["userFollows"].append({
        "followerUserId": user["id"],
        "followeeUserId": target_user_id,
        "createdAt": _globals.now_iso(),
    })
    add_audit_log(db, user["id"], "follow_user", target_user_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"userId": target_user_id, "following": True}})


def handle_unfollow(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_user_id: str,
) -> None:
    """POST /api/users/<id>/unfollow"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    db["userFollows"][:] = [
        f for f in db["userFollows"]
        if not (
            str(f.get("followerUserId", "")).strip() == str(user.get("id", "")).strip()
            and str(f.get("followeeUserId", "")).strip() == target_user_id
        )
    ]
    add_audit_log(db, user["id"], "unfollow_user", target_user_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"userId": target_user_id, "following": False}})


def handle_get_following(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/following"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": list_following_users(
                db,
                user_id=user["id"],
                viewer_user_id=user["id"],
            )
        },
    )


def handle_get_followers(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/followers"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": list_follower_users(
                db,
                user_id=user["id"],
                viewer_user_id=user["id"],
            )
        },
    )


def handle_get_friends(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/friends"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {"data": list_friend_users(db, user_id=user["id"])},
    )
