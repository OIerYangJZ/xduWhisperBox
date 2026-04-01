"""
handlers/_post_handler.py

Post, comment, report, favorite, like, and appeal endpoints:
  GET  /api/posts                                      — list posts
  GET  /api/posts/mine                                 — list own posts
  GET  /api/posts/favorites                            — list favorited posts
  GET  /api/uploads/mine                               — list own uploads
  GET  /api/comments/mine                              — list own comments
  GET  /api/reports/mine                               — list own reports
  GET  /api/reports/<id>                              — get report detail
  GET  re("/api/posts/([^/]+)")                        — get single post
  GET  re("/api/posts/([^/]+)/comments")              — list post comments
  POST /api/posts                                      — create a post
  POST /api/reports                                    — submit a report
  POST /api/appeals                                    — submit an appeal
  POST re("/api/posts/([^/]+)/comments")             — create a comment
  POST re("/api/posts/([^/]+)/like")                 — toggle like
  POST re("/api/posts/([^/]+)/favorite")              — toggle favorite
  POST re("/api/posts/([^/]+)/pin-request")          — request pin-top
  POST re("/api/posts/([^/]+)/view")                  — increment view count
  DELETE re("/api/posts/([^/]+)")                     — delete own post
  DELETE re("/api/comments/([^/]+)")                  — delete own comment
  DELETE re("/api/posts/([^/]+)/favorite")            — remove favorite
"""
from __future__ import annotations

import re
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
    parse_bool,
    read_json_body,
    sanitize_alias,
    send_rate_limit_error,
    send_json,
)
from services import (
    add_audit_log,
    apply_post_pin,
    auth_user as auth_user_helper,
    create_notification,
    find_user_by_email,
    find_user_by_id,
    iso_to_time_text,
    is_level_one_user,
    is_post_private,
    is_user_following,
    latest_pending_appeal_for_user,
    latest_pending_post_pin_request_for_post,
    latest_user_level_request_for_user,
    list_comments,
    list_following_users,
    list_posts,
    next_id,
    parse_pin_duration_minutes,
    normalize_optional_bool,
    normalize_post_visibility,
    post_counts,
    recalc_post_has_image,
    save_db,
    serialize_admin_post_pin_request,
    serialize_comment,
    serialize_notification,
    serialize_post,
    serialize_public_user_profile,
    is_post_pin_active,
    user_avatar_url,
    user_nickname,
)


def _require_auth(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None
    return user


def _can_view_post(post: dict[str, Any], viewer_user_id: str) -> bool:
    if not is_post_private(post):
        return True
    author_id = str(post.get("authorId", "")).strip()
    return bool(viewer_user_id and viewer_user_id == author_id)


def _normalize_post_content_format(value: Any) -> str:
    return "markdown" if str(value or "").strip().lower() == "markdown" else "plain"


def _markdown_to_plain_text(source: str) -> str:
    text = source.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(
        r"```([\s\S]*?)```",
        lambda match: f"\n{(match.group(1) or '').strip()}\n",
        text,
    )
    text = re.sub(r"`([^`]*)`", lambda match: match.group(1) or "", text)
    text = re.sub(
        r"!\[([^\]]*)\]\([^)]+\)",
        lambda match: (match.group(1) or "").strip() or "图片",
        text,
    )
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", lambda match: match.group(1) or "", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"^\s{0,3}#{1,6}\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s{0,3}>\s?", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*([-*_]\s*){3,}$", "", text, flags=re.MULTILINE)
    text = re.sub(r"[*_~]", "", text)
    text = text.replace("|", " ")
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n[ \t]+", "\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _serialize_comment(db: dict[str, Any], comment: dict[str, Any], viewer_user_id: str) -> dict[str, Any]:
    author_id = str(comment.get("userId", "")).strip()
    author_user = find_user_by_id(db, author_id)
    is_anonymous = bool(comment.get("isAnonymous", True))
    liked = bool(
        viewer_user_id
        and any(
            x for x in db["likes"]
            if x.get("userId") == viewer_user_id and x.get("commentId") == comment.get("id")
        )
    )
    like_count_raw = comment.get("likeCount", 0)
    try:
        like_count = max(0, int(like_count_raw or 0))
    except (TypeError, ValueError):
        like_count = 0
    author_avatar_url = user_avatar_url(author_user)
    return {
        "id": comment.get("id", ""),
        "postId": comment.get("postId", ""),
        "content": comment.get("content", ""),
        "authorAlias": _globals.sanitize_alias(str(comment.get("authorAlias", "")), fallback="匿名同学"),
        "authorId": author_id,
        "authorAvatarUrl": author_avatar_url,
        "authorAvatar": author_avatar_url,
        "authorUserId": "" if is_anonymous else author_id,
        "likeCount": like_count,
        "liked": liked,
        "createdAt": comment.get("createdAt", ""),
        "isAnonymous": is_anonymous,
        "reviewStatus": str(comment.get("reviewStatus", "approved") or "approved"),
        "parentId": str(comment.get("parentId", "")).strip(),
    }


def _serialize_upload(db: dict[str, Any], upload: dict[str, Any]) -> dict[str, Any]:
    uploader = find_user_by_id(db, str(upload.get("uploaderId", "")))
    return {
        "id": upload.get("id", ""),
        "url": upload.get("url", ""),
        "fileName": upload.get("fileName", ""),
        "contentType": upload.get("contentType", ""),
        "sizeBytes": int(upload.get("sizeBytes", 0)),
        "status": upload.get("status", "pending"),
        "createdAt": upload.get("createdAt", ""),
        "postId": upload.get("postId", ""),
        "uploaderId": upload.get("uploaderId", ""),
        "uploaderAlias": user_nickname(uploader),
    }


def _normalize_comment_sort(value: Any) -> str:
    text = str(value or "").strip().lower()
    if text in {"hot", "top"}:
        return "hot"
    return "latest"


# ===========================================================================
# GET handlers
# ===========================================================================


def handle_get_posts(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/posts"""
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""

    keyword = (query.get("keyword", [""])[0] or "").strip().lower()
    channel = (query.get("channel", [""])[0] or "").strip()
    has_image = parse_bool(query.get("hasImage", [None])[0])
    allow_dm = parse_bool(query.get("allowDm", [None])[0])
    status = (query.get("status", [""])[0] or "").strip().lower()
    sort_by = (query.get("sort", ["latest"])[0] or "latest").strip().lower()
    author_id = (query.get("authorId", [""])[0] or "").strip()

    filtered_posts = []
    for post in list_posts(db, sort_by=sort_by):
        if not _can_view_post(post, viewer_user_id):
            continue
        if channel and post.get("channel") != channel:
            continue
        if status and str(post.get("status", "")).lower() != status:
            continue
        if has_image is not None and bool(post.get("hasImage", False)) != has_image:
            continue
        if allow_dm is not None and _globals.effective_post_allow_dm(db, post) != allow_dm:
            continue
        if author_id and str(post.get("authorId", "")).strip() != author_id:
            continue

        if keyword:
            text = " ".join(
                [
                    str(post.get("title", "")).lower(),
                    str(post.get("content", "")).lower(),
                    str(post.get("channel", "")).lower(),
                    " ".join(str(tag).lower() for tag in post.get("tags", [])),
                ]
            )
            if keyword not in text:
                continue

        filtered_posts.append(post)

    filtered_posts = _globals.sort_posts_for_view(db, filtered_posts, sort_by=sort_by)
    rows = [serialize_post(db, post, viewer_user_id=viewer_user_id) for post in filtered_posts]
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_get_posts_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/posts/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    rows = [p for p in list_posts(db, include_rejected=True) if p.get("authorId") == user["id"]]
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": [
                serialize_post(db, p, include_unapproved_images=True, viewer_user_id=user["id"])
                for p in rows
            ]
        },
    )


def handle_get_posts_favorites(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/posts/favorites"""
    user = _require_auth(handler, db)
    if user is None:
        return

    fav_post_ids = {f["postId"] for f in db["favorites"] if f.get("userId") == user["id"]}
    rows = [
        p for p in list_posts(db)
        if p.get("id") in fav_post_ids and _can_view_post(p, user["id"])
    ]
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": [serialize_post(db, p, viewer_user_id=user["id"]) for p in rows]},
    )


def handle_get_uploads_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/uploads/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    rows = [
        _serialize_upload(db, u)
        for u in db.get("mediaUploads", [])
        if not u.get("deleted") and u.get("uploaderId") == user["id"]
    ]
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_get_comments_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/comments/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    result = []
    for comment in db["comments"]:
        if comment.get("userId") != user["id"] or comment.get("deleted"):
            continue
        post = next(
            (p for p in db["posts"] if p.get("id") == comment.get("postId") and not p.get("deleted")),
            None,
        )
        result.append(
            {
                "id": comment.get("id"),
                "commentId": comment.get("id"),
                "postId": comment.get("postId", ""),
                "postTitle": post.get("title") if post else "原帖",
                "content": comment.get("content", ""),
                "timeText": iso_to_time_text(comment.get("createdAt")),
            }
        )
    result.sort(key=lambda x: x.get("timeText", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": result})


def handle_get_reports_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/reports/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    result = []
    for report in db["reports"]:
        if report.get("userId") != user["id"]:
            continue
        target_type = str(report.get("targetType", "other"))
        target_id = str(report.get("targetId", "unknown"))
        target_title = ""
        if target_type == "post":
            post = next(
                (p for p in db["posts"] if p.get("id") == target_id and not p.get("deleted")),
                None,
            )
            if post is not None:
                target_title = str(post.get("title", "")).strip()
        elif target_type == "comment":
            comment = next(
                (c for c in db["comments"] if c.get("id") == target_id and not c.get("deleted")),
                None,
            )
            if comment is not None:
                target_title = str(comment.get("content", "")).strip()[:50]
        result.append({
            "id": report.get("id"),
            "target": f"{target_type}: {target_id}",
            "targetType": target_type,
            "targetId": target_id,
            "targetTitle": target_title,
            "reason": report.get("reason", "-"),
            "status": report.get("status", "pending"),
            "description": report.get("description", ""),
            "result": report.get("result", ""),
            "createdAt": report.get("createdAt", ""),
            "handledAt": report.get("handledAt", ""),
        })
    result.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": result})


def handle_get_report_detail(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    report_id: str,
) -> None:
    """GET /api/reports/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    report = next((r for r in db["reports"] if r.get("id") == report_id), None)
    if report is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "举报记录不存在")
        return
    if report.get("userId") != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "无权限查看此举报记录")
        return

    target_type = str(report.get("targetType", "other"))
    target_id = str(report.get("targetId", "unknown"))
    target_title = ""
    if target_type == "post":
        post = next(
            (p for p in db["posts"] if p.get("id") == target_id and not p.get("deleted")),
            None,
        )
        if post is not None:
            target_title = str(post.get("title", "")).strip()
    elif target_type == "comment":
        comment = next(
            (c for c in db["comments"] if c.get("id") == target_id and not c.get("deleted")),
            None,
        )
        if comment is not None:
            target_title = str(comment.get("content", "")).strip()[:50]

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "id": report.get("id"),
                "targetType": target_type,
                "targetId": target_id,
                "targetTitle": target_title,
                "reason": report.get("reason", "-"),
                "description": report.get("description", ""),
                "status": report.get("status", "pending"),
                "result": report.get("result", ""),
                "createdAt": report.get("createdAt", ""),
                "handledAt": report.get("handledAt", ""),
            }
        },
    )


def handle_get_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """GET /api/posts/<id>"""
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, viewer_user_id):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    send_json(handler, HTTPStatus.OK, {"data": serialize_post(db, post, viewer_user_id=viewer_user_id)})


def handle_get_post_comments(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
    query: dict[str, list[str]] | None = None,
) -> None:
    """GET /api/posts/<id>/comments"""
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""
    sort_by = _normalize_comment_sort(
        ((query or {}).get("sort", ["latest"])[0] if query is not None else "latest")
    )

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, viewer_user_id):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    rows = [
        _serialize_comment(db, comment, viewer_user_id)
        for comment in list_comments(
            db,
            post_id=post_id,
            viewer_user_id=viewer_user_id,
        )
    ]

    like_count_by_comment: dict[str, int] = {}
    for like in db.get("likes", []):
        comment_id = str(like.get("commentId", "")).strip()
        if not comment_id:
            continue
        like_count_by_comment[comment_id] = like_count_by_comment.get(comment_id, 0) + 1

    def _to_int(value: Any) -> int:
        try:
            return int(value or 0)
        except (TypeError, ValueError):
            return 0

    for row in rows:
        row_comment_id = str(row.get("id", "")).strip()
        computed = like_count_by_comment.get(row_comment_id)
        if computed is None:
            computed = max(0, _to_int(row.get("likeCount", 0)))
        row["likeCount"] = computed

    if sort_by == "hot":
        rows.sort(
            key=lambda row: (
                max(0, _to_int(row.get("likeCount", 0))),
                str(row.get("createdAt", "") or ""),
                str(row.get("id", "") or ""),
            ),
            reverse=True,
        )
    else:
        rows.sort(
            key=lambda row: (
                str(row.get("createdAt", "") or ""),
                str(row.get("id", "") or ""),
            ),
            reverse=True,
        )
    send_json(handler, HTTPStatus.OK, {"data": rows})


# ===========================================================================
# POST handlers
# ===========================================================================


def handle_create_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/posts"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if user.get("muted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法发帖")
        return

    body = read_json_body(handler)
    title = str(body.get("title", "")).strip()
    raw_content = str(body.get("content", "")).strip()
    content_format = _normalize_post_content_format(body.get("contentFormat"))
    markdown_source = ""
    content = raw_content
    if content_format == "markdown":
        markdown_source = str(body.get("markdownSource", raw_content)).strip() or raw_content
        content = _markdown_to_plain_text(markdown_source) or markdown_source
    available_channels = list(
        dict.fromkeys(["综合", *(db.get("channels", []) or []), *_globals.DEFAULT_CHANNELS])
    )
    channel = str(body.get("channel", "")).strip()
    if not channel:
        channel = available_channels[0] if available_channels else "综合"
    raw_tags = body.get("tags", [])
    tags = [str(tag).strip() for tag in raw_tags if str(tag).strip()] if isinstance(raw_tags, list) else []
    raw_image_ids = body.get("imageUploadIds") or body.get("imageIds") or []
    image_ids = [str(image_id).strip() for image_id in raw_image_ids if str(image_id).strip()] if isinstance(raw_image_ids, list) else []
    use_anonymous_alias = bool(body.get("useAnonymousAlias"))
    anonymous_alias = sanitize_alias(str(body.get("anonymousAlias", "")).strip(), fallback="")
    status = str(body.get("status", "ongoing")).strip().lower()
    visibility = normalize_post_visibility(body.get("visibility"))
    pin_duration_minutes = parse_pin_duration_minutes(body.get("pinDurationMinutes"))

    if not raw_content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "帖子内容不能为空")
        return
    if channel not in available_channels:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的频道")
        return
    if pin_duration_minutes is not None and not is_level_one_user(user):
        json_error(handler, HTTPStatus.FORBIDDEN, "仅一级用户可在发帖时直接置顶")
        return

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="post",
        setting_key="postRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["postRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="发帖",
            retry_after_seconds=retry_after,
        )
        return
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "post")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="发帖",
            retry_after_seconds=ip_retry_after,
        )
        return

    risk_marked, high_risk, risk_reasons = assess_text_risk(
        db,
        " ".join([title, content, " ".join(tags)]),
    )
    if high_risk:
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            f"内容触发高风险风控：{'; '.join(risk_reasons)}",
        )
        add_audit_log(db, user["id"], "risk_block_post", ";".join(risk_reasons))
        save_db(db)
        return

    author_alias = user_nickname(user)
    if use_anonymous_alias:
        author_alias = anonymous_alias or "匿名同学"
    has_image = False
    picked_uploads: list[dict[str, Any]] = []
    for img_id in image_ids:
        upload = next((u for u in db.get("mediaUploads", []) if u.get("id") == img_id), None)
        if upload is None or upload.get("deleted"):
            json_error(handler, HTTPStatus.BAD_REQUEST, f"图片不存在: {img_id}")
            return
        if upload.get("uploaderId") != user["id"]:
            json_error(handler, HTTPStatus.FORBIDDEN, f"图片无权限绑定: {img_id}")
            return
        if upload.get("postId"):
            json_error(handler, HTTPStatus.BAD_REQUEST, f"图片已绑定帖子: {img_id}")
            return
        picked_uploads.append(upload)
        if str(upload.get("status", "approved")).strip().lower() != "rejected":
            has_image = True

    post = {
        "id": next_id(db, "post", "p"),
        "title": title,
        "content": content,
        "contentFormat": content_format,
        "markdownSource": markdown_source,
        "channel": channel,
        "tags": tags,
        "hasImage": has_image or bool(picked_uploads),
        "imageIds": image_ids,
        "status": status if status in {"ongoing", "resolved", "closed"} else "ongoing",
        "allowComment": True,
        "allowDm": not use_anonymous_alias,
        "visibility": visibility,
        "authorAlias": _globals.sanitize_alias(author_alias, fallback="匿名同学"),
        "authorId": user["id"],
        "pinStartedAt": "",
        "pinExpiresAt": "",
        "pinDurationMinutes": 0,
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
        "deleted": False,
        "reviewStatus": "approved",
        "riskMarked": risk_marked,
        "isAnonymous": use_anonymous_alias,
    }
    if pin_duration_minutes is not None:
        apply_post_pin(
            post,
            duration_minutes=pin_duration_minutes,
            started_at=post["createdAt"],
        )
    db["posts"].append(post)
    for upload in picked_uploads:
        upload["postId"] = post["id"]
        upload_status = str(upload.get("status", "approved")).strip().lower()
        if upload_status != "rejected":
            upload["status"] = "approved"
            upload["moderationReason"] = ""
            if not str(upload.get("reviewNote", "")).strip():
                upload["reviewNote"] = "发帖时自动通过"
            upload["reviewedAt"] = post["createdAt"]
    recalc_post_has_image(db, post["id"])
    add_audit_log(db, user["id"], "create_post", f"发布帖子 {post['id']}")
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": serialize_post(
                db,
                post,
                include_unapproved_images=True,
                viewer_user_id=user["id"],
            )
        },
    )


def handle_create_comment(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/comments"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if user.get("muted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法评论")
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not post.get("allowComment", True):
        json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子已关闭评论")
        return

    body = read_json_body(handler)
    comment_content = str(body.get("content", "")).strip()
    if not comment_content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "评论内容不能为空")
        return

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="comment",
        setting_key="commentRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["commentRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="评论",
            retry_after_seconds=retry_after,
        )
        return
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "comment")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="评论",
            retry_after_seconds=ip_retry_after,
        )
        return

    risk_marked, high_risk, risk_reasons = assess_text_risk(db, comment_content)
    if high_risk:
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            f"评论触发高风险风控：{'; '.join(risk_reasons)}",
        )
        add_audit_log(db, user["id"], "risk_block_comment", ";".join(risk_reasons))
        save_db(db)
        return

    author_alias = _globals.sanitize_alias(user_nickname(user), fallback="匿名同学")
    comment = {
        "id": next_id(db, "comment", "cm"),
        "postId": post_id,
        "userId": user["id"],
        "authorAlias": author_alias,
        "content": comment_content,
        "likeCount": 0,
        "createdAt": now_iso(),
        "deleted": False,
        "reviewStatus": "approved",
        "riskMarked": risk_marked,
        "isAnonymous": True,
        "parentId": str(body.get("parentId", "")).strip(),
    }
    db["comments"].append(comment)

    post_author_id = str(post.get("authorId", "")).strip()
    if post_author_id and post_author_id != user["id"]:
        create_notification(
            db,
            user_id=post_author_id,
            notification_type="comment",
            title="收到新评论",
            content=comment_content[:100],
            related_type="post",
            related_id=post_id,
            post_id=post_id,
            actor_id=user["id"],
            actor_alias=author_alias,
        )

    add_audit_log(db, user["id"], "create_comment", f"在帖子 {post_id} 下发表评论 {comment['id']}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": _serialize_comment(db, comment, viewer_user_id=user["id"])})


def handle_toggle_like(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/like"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    existing = next(
        (x for x in db["likes"] if x.get("userId") == user["id"] and x.get("postId") == post_id and not x.get("commentId")),
        None,
    )
    liked = False
    if existing is None:
        db["likes"].append({"userId": user["id"], "postId": post_id, "createdAt": now_iso()})
        liked = True
        post_author_id = str(post.get("authorId", "")).strip()
        if post_author_id and post_author_id != user["id"]:
            create_notification(
                db,
                user_id=post_author_id,
                notification_type="like",
                title="收到点赞",
                content=str(post.get("title", "")).strip()[:50],
                related_type="post",
                related_id=post_id,
                post_id=post_id,
                actor_id=user["id"],
                actor_alias=_globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
            )
        add_audit_log(db, user["id"], "like_post", f"点赞帖子 {post_id}")
    else:
        db["likes"] = [x for x in db["likes"] if not (
            x.get("userId") == user["id"]
            and x.get("postId") == post_id
            and not x.get("commentId")
        )]
        add_audit_log(db, user["id"], "unlike_post", f"取消点赞帖子 {post_id}")

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"liked": liked}})


def handle_toggle_comment_like(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    comment_id: str,
) -> None:
    """POST /api/comments/<id>/like"""
    user = _require_auth(handler, db)
    if user is None:
        return

    comment = next(
        (c for c in db["comments"] if c.get("id") == comment_id and not c.get("deleted")),
        None,
    )
    if comment is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "评论不存在或已被删除")
        return

    existing = next(
        (x for x in db["likes"]
         if x.get("userId") == user["id"]
         and x.get("commentId") == comment_id),
        None,
    )
    liked = False
    if existing is None:
        db["likes"].append({"userId": user["id"], "commentId": comment_id, "createdAt": now_iso()})
        liked = True
        comment_author_id = str(comment.get("userId", "")).strip()
        if comment_author_id and comment_author_id != user["id"]:
            post_id = str(comment.get("postId", "")).strip()
            create_notification(
                db,
                user_id=comment_author_id,
                notification_type="like",
                title="收到点赞",
                content=str(comment.get("content", "")).strip()[:50],
                related_type="comment",
                related_id=comment_id,
                post_id=post_id,
                actor_id=user["id"],
                actor_alias=_globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
            )
        add_audit_log(db, user["id"], "like_comment", f"点赞评论 {comment_id}")
    else:
        db["likes"] = [x for x in db["likes"] if x is not existing]
        add_audit_log(db, user["id"], "unlike_comment", f"取消点赞评论 {comment_id}")

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"liked": liked}})


def handle_toggle_favorite(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/favorite"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    existing = next(
        (f for f in db["favorites"] if f.get("userId") == user["id"] and f.get("postId") == post_id),
        None,
    )
    favorited = False
    if existing is None:
        db["favorites"].append({"userId": user["id"], "postId": post_id, "createdAt": now_iso()})
        favorited = True
        post_author_id = str(post.get("authorId", "")).strip()
        if post_author_id and post_author_id != user["id"]:
            create_notification(
                db,
                user_id=post_author_id,
                notification_type="favorite",
                title="收到收藏",
                content=str(post.get("title", "")).strip()[:50],
                related_type="post",
                related_id=post_id,
                post_id=post_id,
                actor_id=user["id"],
                actor_alias=_globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
            )
        add_audit_log(db, user["id"], "favorite_post", f"收藏帖子 {post_id}")
    else:
        db["favorites"] = [f for f in db["favorites"] if not (f.get("userId") == user["id"] and f.get("postId") == post_id)]
        add_audit_log(db, user["id"], "unfavorite_post", f"取消收藏帖子 {post_id}")

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
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"favorited": favorited, "likeCount": like_count, "favoriteCount": favorite_count}})


def handle_increment_view(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/view"""
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, viewer_user_id):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    post["viewCount"] = max(0, int(post.get("viewCount", 0) or 0)) + 1
    save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "viewCount": max(0, int(post.get("viewCount", 0) or 0))}})


def handle_pin_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/pin-request"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在")
        return
    if str(post.get("authorId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能为自己的帖子申请置顶")
        return

    body = read_json_body(handler)
    duration_minutes = int(body.get("durationMinutes", 1440))
    reason = str(body.get("reason", "")).strip()

    if is_level_one_user(user):
        if is_post_pin_active(post):
            json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子当前已在置顶中")
            return
        apply_post_pin(post, duration_minutes=duration_minutes)
        add_audit_log(
            db,
            user["id"],
            "direct_pin_post",
            f"{post_id}:{duration_minutes}",
        )
        save_db(db)
        send_json(
            handler,
            HTTPStatus.OK,
            {
                "message": "帖子已置顶",
                "data": {
                    "mode": "direct",
                    "post": serialize_post(
                        db,
                        post,
                        viewer_user_id=user["id"],
                    ),
                },
            },
        )
        return

    if is_post_pin_active(post):
        json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子当前已在置顶中")
        return

    existing = latest_pending_post_pin_request_for_post(db, post_id)
    if existing is not None:
        json_error(handler, HTTPStatus.CONFLICT, "该帖子已有待处理的置顶申请")
        return

    request = {
        "id": next_id(db, "pinRequest", "pin"),
        "postId": post_id,
        "userId": str(user.get("id", "")).strip(),
        "durationMinutes": duration_minutes,
        "reason": reason,
        "status": "pending",
        "adminNote": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db.setdefault("postPinRequests", []).append(request)
    add_audit_log(
        db,
        user["id"],
        "submit_post_pin_request",
        f"{request['id']}:{post_id}:{duration_minutes}",
    )
    save_db(db)
    send_json(
        handler,
        HTTPStatus.CREATED,
        {
            "message": "置顶申请已提交，请等待管理员审核",
            "data": {
                "mode": "pending",
                "request": serialize_admin_post_pin_request(db, request),
            },
        },
    )


def handle_submit_report(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/reports"""
    user = _require_auth(handler, db)
    if user is None:
        return

    body = read_json_body(handler)
    target_type = str(body.get("targetType", "")).strip().lower()
    target_id = str(body.get("targetId", "")).strip()
    reason = str(body.get("reason", "")).strip()
    description = str(body.get("description", "")).strip()

    if target_type not in {"post", "comment"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "targetType 必须是 post 或 comment")
        return
    if not target_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少目标 ID")
        return
    if reason not in {"广告引流", "人身攻击", "违规内容", "垃圾信息", "其他"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的举报原因")
        return

    if target_type == "post":
        post = next(
            (p for p in db["posts"] if p.get("id") == target_id and not p.get("deleted")),
            None,
        )
        if post is None or not _can_view_post(post, user["id"]):
            json_error(handler, HTTPStatus.NOT_FOUND, "目标内容不存在")
            return
    else:
        comment = next(
            (c for c in db["comments"] if c.get("id") == target_id and not c.get("deleted")),
            None,
        )
        if comment is None:
            json_error(handler, HTTPStatus.NOT_FOUND, "目标内容不存在")
            return
        comment_post = next(
            (
                p for p in db["posts"]
                if p.get("id") == comment.get("postId") and not p.get("deleted")
            ),
            None,
        )
        if comment_post is None or not _can_view_post(comment_post, user["id"]):
            json_error(handler, HTTPStatus.NOT_FOUND, "目标内容不存在")
            return

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="report",
        setting_key="reportRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["reportRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="举报",
            retry_after_seconds=retry_after,
        )
        return

    report = {
        "id": next_id(db, "report", "r"),
        "userId": user["id"],
        "reporterAlias": _globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
        "targetType": target_type,
        "targetId": target_id,
        "reason": reason,
        "description": description,
        "status": "pending",
        "result": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db["reports"].append(report)
    add_audit_log(db, user["id"], "submit_report", f"举报 {target_type} {target_id}: {reason}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "id": report["id"]}})


def handle_submit_appeal(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/appeals"""
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    appeal_type = str(body.get("appealType", "")).strip().lower()
    content = str(body.get("content", "")).strip()

    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
        return
    if appeal_type not in {"account_restore", "ban_revoke", "wrong_punishment", "account_cancel_reject"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的申诉类型")
        return
    if not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "申诉内容不能为空")
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在")
        return
    if not user.get("deleted"):
        if latest_pending_appeal_for_user(db, str(user.get("id", ""))) is not None:
            json_error(handler, HTTPStatus.CONFLICT, "该账号已有待处理的申诉")
            return

    appeal = {
        "id": next_id(db, "appeal", "ap"),
        "userId": str(user.get("id", "")),
        "email": email,
        "appealType": appeal_type,
        "content": content,
        "status": "pending",
        "result": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db["appeals"].append(appeal)
    add_audit_log(db, user["id"], "submit_appeal", f"提交申诉 {appeal_type}: {content[:30]}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "id": appeal["id"]}})


# ===========================================================================
# PATCH handlers
# ===========================================================================


def handle_update_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """PATCH /api/posts/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if str(post.get("authorId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能编辑自己的帖子")
        return

    body = read_json_body(handler)
    new_status = str(body.get("status", "")).strip().lower()
    if new_status in {"ongoing", "open", "resolved", "closed"}:
        post["status"] = "ongoing" if new_status == "open" else new_status
        post["updatedAt"] = now_iso()
        add_audit_log(db, user["id"], "update_post_status", f"更新帖子状态为 {new_status}")
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": serialize_post(db, post, viewer_user_id=user["id"])})


# ===========================================================================
# DELETE handlers
# ===========================================================================


def handle_delete_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """DELETE /api/posts/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if str(post.get("authorId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能删除自己的帖子")
        return

    post["deleted"] = True
    for upload in db.get("mediaUploads", []):
        if upload.get("postId") == post_id and not upload.get("deleted"):
            upload["deleted"] = True
    add_audit_log(db, user["id"], "delete_post", f"删除帖子 {post_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_delete_comment(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    comment_id: str,
) -> None:
    """DELETE /api/comments/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    comment = next(
        (c for c in db["comments"] if c.get("id") == comment_id and not c.get("deleted")),
        None,
    )
    if comment is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "评论不存在或已被删除")
        return
    if str(comment.get("userId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能删除自己的评论")
        return

    comment["deleted"] = True
    add_audit_log(db, user["id"], "delete_comment", f"删除评论 {comment_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_remove_favorite(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """DELETE /api/posts/<id>/favorite"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None or not _can_view_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    db["favorites"] = [
        f for f in db["favorites"]
        if not (f.get("userId") == user["id"] and f.get("postId") == post_id)
    ]
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
    add_audit_log(db, user["id"], "unfavorite_post", f"取消收藏帖子 {post_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "likeCount": like_count, "favoriteCount": favorite_count}})
