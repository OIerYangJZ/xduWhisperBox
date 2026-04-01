from __future__ import annotations

from datetime import timezone
from typing import Any

import _globals
from helpers._auth_helpers import normalize_avatar_url, normalize_media_url, sanitize_alias
from helpers._datetime_helpers import now_iso, now_utc, parse_iso
from services._db_service import next_id


# ---------------------------------------------------------------------------
# User lookup helpers
# ---------------------------------------------------------------------------


def find_user_by_email(
    db: dict[str, Any],
    email: str,
    *,
    include_deleted: bool = False,
) -> dict[str, Any] | None:
    target = email.lower().strip()
    for user in db["users"]:
        if user.get("deleted") and not include_deleted:
            continue
        if user.get("email", "").lower().strip() == target:
            return user
    return None


def find_user_by_student_id(
    db: dict[str, Any],
    student_id: str,
    *,
    include_deleted: bool = False,
) -> dict[str, Any] | None:
    target = student_id.strip()
    if not target:
        return None
    for user in db["users"]:
        if user.get("deleted") and not include_deleted:
            continue
        if str(user.get("studentId", "")).strip() == target:
            return user
    return None


def find_user_by_id(
    db: dict[str, Any],
    user_id: str,
    *,
    include_deleted: bool = False,
) -> dict[str, Any] | None:
    for user in db["users"]:
        if user.get("deleted") and not include_deleted:
            continue
        if user.get("id") == user_id:
            return user
    return None


def user_nickname(user: dict[str, Any] | None) -> str:
    if not user:
        return "匿名同学"
    nickname = sanitize_alias(str(user.get("nickname", "")), fallback="")
    if nickname:
        return nickname
    return sanitize_alias(str(user.get("alias", "")), fallback="匿名同学")


def user_avatar_url(user: dict[str, Any] | None) -> str:
    if not user:
        return ""
    return normalize_avatar_url(str(user.get("avatarUrl", "")))


def normalize_optional_bool(value: Any, default: bool | None = None) -> bool | None:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off"}:
            return False
    return default


def is_post_anonymous(db: dict[str, Any], post: dict[str, Any]) -> bool:
    normalized = normalize_optional_bool(post.get("isAnonymous"))
    if normalized is not None:
        return normalized

    author_id = str(post.get("authorId", "")).strip()
    author_alias = str(post.get("authorAlias", "")).strip()
    if not author_id or not author_alias:
        return True

    author = find_user_by_id(db, author_id)
    if not isinstance(author, dict):
        return True

    nickname = str(author.get("nickname", "")).strip() or str(author.get("alias", "")).strip()
    if not nickname:
        return True
    return author_alias != nickname


def normalize_post_visibility(value: Any) -> str:
    return "private" if str(value or "").strip().lower() == "private" else "public"


def is_post_private(post: dict[str, Any]) -> bool:
    return normalize_post_visibility(post.get("visibility")) == "private"


def effective_post_allow_dm(db: dict[str, Any], post: dict[str, Any]) -> bool:
    if is_post_anonymous(db, post):
        return False
    if is_post_private(post):
        return False
    author_id = str(post.get("authorId", "")).strip()
    if not author_id:
        return False
    author = find_user_by_id(db, author_id)
    if not author:
        return False
    return bool(author.get("allowStrangerDm", True))


def can_request_dm_from_post(
    db: dict[str, Any],
    *,
    viewer_user_id: str,
    post: dict[str, Any],
) -> bool:
    viewer = viewer_user_id.strip()
    author_id = str(post.get("authorId", "")).strip()
    if not viewer or not author_id or viewer == author_id:
        return False
    if not effective_post_allow_dm(db, post):
        return False
    if is_user_blocked(db, viewer, author_id):
        return False
    if is_user_blocked(db, author_id, viewer):
        return False
    return True


def is_user_following(db: dict[str, Any], follower_id: str, followed_id: str) -> bool:
    follower = follower_id.strip()
    followed = followed_id.strip()
    if not follower or not followed or follower == followed:
        return False
    return any(
        str(row.get("followerUserId", "")).strip() == follower
        and str(row.get("followeeUserId", "")).strip() == followed
        for row in db.get("userFollows", [])
    )


def count_following(db: dict[str, Any], user_id: str) -> int:
    uid = user_id.strip()
    if not uid:
        return 0
    return sum(
        1
        for row in db.get("userFollows", [])
        if str(row.get("followerUserId", "")).strip() == uid
        and find_user_by_id(db, str(row.get("followeeUserId", "")).strip()) is not None
    )


def count_followers(db: dict[str, Any], user_id: str) -> int:
    uid = user_id.strip()
    if not uid:
        return 0
    return sum(
        1
        for row in db.get("userFollows", [])
        if str(row.get("followeeUserId", "")).strip() == uid
        and find_user_by_id(db, str(row.get("followerUserId", "")).strip()) is not None
    )


def build_follow_user_item(
    db: dict[str, Any],
    *,
    target_user_id: str,
    viewer_user_id: str,
) -> dict[str, Any] | None:
    target_id = target_user_id.strip()
    target = find_user_by_id(db, target_id)
    if target is None:
        return None
    return {
        "userId": target_id,
        "nickname": user_nickname(target),
        "avatarUrl": user_avatar_url(target),
        "isFollowing": is_user_following(db, viewer_user_id, target_id),
        "isFollower": is_user_following(db, target_id, viewer_user_id),
    }


def list_following_users(
    db: dict[str, Any],
    *,
    user_id: str,
    viewer_user_id: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for follow in db.get("userFollows", []):
        if str(follow.get("followerUserId", "")).strip() != user_id.strip():
            continue
        item = build_follow_user_item(
            db,
            target_user_id=str(follow.get("followeeUserId", "")).strip(),
            viewer_user_id=viewer_user_id,
        )
        if item is not None:
            item["_createdAt"] = str(follow.get("createdAt", ""))
            rows.append(item)
    rows.sort(
        key=lambda item: (str(item.get("_createdAt", "")), str(item.get("userId", ""))),
        reverse=True,
    )
    for item in rows:
        item.pop("_createdAt", None)
    return rows


def list_follower_users(
    db: dict[str, Any],
    *,
    user_id: str,
    viewer_user_id: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for follow in db.get("userFollows", []):
        if str(follow.get("followeeUserId", "")).strip() != user_id.strip():
            continue
        item = build_follow_user_item(
            db,
            target_user_id=str(follow.get("followerUserId", "")).strip(),
            viewer_user_id=viewer_user_id,
        )
        if item is not None:
            item["_createdAt"] = str(follow.get("createdAt", ""))
            rows.append(item)
    rows.sort(
        key=lambda item: (str(item.get("_createdAt", "")), str(item.get("userId", ""))),
        reverse=True,
    )
    for item in rows:
        item.pop("_createdAt", None)
    return rows


def list_friend_users(
    db: dict[str, Any],
    *,
    user_id: str,
) -> list[dict[str, Any]]:
    following_ids = {
        str(row.get("followeeUserId", "")).strip()
        for row in db.get("userFollows", [])
        if str(row.get("followerUserId", "")).strip() == user_id.strip()
    }
    follower_ids = {
        str(row.get("followerUserId", "")).strip()
        for row in db.get("userFollows", [])
        if str(row.get("followeeUserId", "")).strip() == user_id.strip()
    }
    mutual_ids = sorted(following_ids & follower_ids)
    rows: list[dict[str, Any]] = []
    for target_user_id in mutual_ids:
        item = build_follow_user_item(
            db,
            target_user_id=target_user_id,
            viewer_user_id=user_id,
        )
        if item is not None:
            rows.append(item)
    rows.sort(key=lambda item: (str(item.get("nickname", "")), str(item.get("userId", ""))))
    return rows


def can_request_dm_to_user(
    db: dict[str, Any],
    *,
    viewer_user_id: str,
    target_user_id: str,
) -> bool:
    viewer = viewer_user_id.strip()
    target = target_user_id.strip()
    if not viewer or not target or viewer == target:
        return False

    viewer_user = find_user_by_id(db, viewer)
    target_user = find_user_by_id(db, target)
    if viewer_user is None or target_user is None:
        return False
    if not bool(target_user.get("showContactable", True)):
        return False
    if not bool(target_user.get("allowStrangerDm", True)):
        return False
    if is_user_blocked(db, viewer, target):
        return False
    if is_user_blocked(db, target, viewer):
        return False
    return True


# ---------------------------------------------------------------------------
# Profile / Level helpers
# ---------------------------------------------------------------------------


def serialize_public_user_profile(
    db: dict[str, Any],
    *,
    target_user: dict[str, Any],
    viewer_user_id: str,
) -> dict[str, Any]:
    target_user_id = str(target_user.get("id", "")).strip()
    return {
        "id": target_user_id,
        "alias": user_nickname(target_user),
        "nickname": user_nickname(target_user),
        "avatarUrl": user_avatar_url(target_user),
        "verified": bool(target_user.get("verified", False)),
        "verifiedAt": str(target_user.get("verifiedAt", "")),
        "userLevel": current_user_level(target_user),
        "userLevelLabel": user_level_label(current_user_level(target_user)),
        "isLevelOneUser": is_level_one_user(target_user),
        "favoriteCount": 0,
        "postCount": sum(
            1
            for post in db.get("posts", [])
            if not post.get("deleted")
            and str(post.get("authorId", "")).strip() == target_user_id
            and not is_post_anonymous(db, post)
        ),
        "followingCount": count_following(db, target_user_id),
        "followerCount": count_followers(db, target_user_id),
        "isFollowing": is_user_following(db, viewer_user_id, target_user_id),
        "isFollower": is_user_following(db, target_user_id, viewer_user_id),
        "isOwnProfile": bool(viewer_user_id and viewer_user_id == target_user_id),
        "canFollow": bool(viewer_user_id and viewer_user_id != target_user_id),
        "bio": str(target_user.get("bio", "")).strip(),
        "gender": str(target_user.get("gender", "")).strip(),
        "backgroundImageUrl": normalize_media_url(str(target_user.get("backgroundImageUrl", "")).strip()),
        "canDirectMessage": can_request_dm_to_user(
            db,
            viewer_user_id=viewer_user_id,
            target_user_id=target_user_id,
        ),
    }


def search_public_users(
    db: dict[str, Any],
    *,
    viewer_user_id: str,
    keyword: str,
    limit: int = 50,
) -> list[dict[str, Any]]:
    normalized_keyword = keyword.strip().lower()
    if not normalized_keyword:
        return []

    rows: list[tuple[int, int, str, dict[str, Any]]] = []
    for user in db.get("users", []):
        if not isinstance(user, dict) or user.get("deleted"):
            continue
        nickname = user_nickname(user).strip()
        if not nickname:
            continue
        normalized_nickname = nickname.lower()
        if normalized_keyword not in normalized_nickname:
            continue

        if normalized_nickname == normalized_keyword:
            priority = 0
        elif normalized_nickname.startswith(normalized_keyword):
            priority = 1
        else:
            priority = 2

        profile = serialize_public_user_profile(
            db,
            target_user=user,
            viewer_user_id=viewer_user_id,
        )
        follower_count = int(profile.get("followerCount", 0) or 0)
        rows.append((priority, -follower_count, nickname, profile))

    rows.sort(key=lambda item: (item[0], item[1], item[2]))
    return [item[3] for item in rows[: max(1, limit)]]


def current_user_level(user: dict[str, Any] | None) -> int:
    if not user:
        return _globals.USER_LEVEL_TWO
    return normalize_user_level(user.get("userLevel"))


def is_level_one_user(user: dict[str, Any] | None) -> bool:
    return current_user_level(user) == _globals.USER_LEVEL_ONE


def normalize_user_level(value: Any) -> int:
    try:
        level = int(value)
    except (TypeError, ValueError):
        return _globals.USER_LEVEL_TWO
    return _globals.USER_LEVEL_ONE if level == _globals.USER_LEVEL_ONE else _globals.USER_LEVEL_TWO


def user_level_label(level: Any) -> str:
    return "一级用户" if normalize_user_level(level) == _globals.USER_LEVEL_ONE else "二级用户"


def parse_pin_duration_minutes(value: Any) -> int | None:
    try:
        duration = int(value)
    except (TypeError, ValueError):
        return None
    return duration if duration in _globals.PIN_DURATION_OPTIONS else None


def pin_duration_label(duration_minutes: Any) -> str:
    try:
        duration = int(duration_minutes)
    except (TypeError, ValueError):
        return ""
    return _globals.PIN_DURATION_OPTIONS.get(duration, "")


def apply_post_pin(
    post: dict[str, Any],
    *,
    duration_minutes: int,
    started_at: str | None = None,
) -> None:
    from helpers._datetime_helpers import now_utc
    pin_started_at = started_at or now_iso()
    started_dt = parse_iso(pin_started_at)
    if started_dt is None:
        started_dt = now_utc()
        pin_started_at = started_dt.isoformat()
    post["pinStartedAt"] = pin_started_at
    post["pinExpiresAt"] = (started_dt + __import__("datetime").timedelta(minutes=duration_minutes)).isoformat()
    post["pinDurationMinutes"] = duration_minutes
    post["updatedAt"] = now_iso()


def is_post_pin_active(post: dict[str, Any]) -> bool:
    expires_at = parse_iso(str(post.get("pinExpiresAt", "")))
    duration_minutes = parse_pin_duration_minutes(post.get("pinDurationMinutes"))
    if expires_at is None or duration_minutes is None:
        return False
    from helpers._datetime_helpers import now_utc
    return expires_at > now_utc()


def latest_pending_post_pin_request_for_post(
    db: dict[str, Any],
    post_id: str,
) -> dict[str, Any] | None:
    rows = [
        row
        for row in db.get("postPinRequests", [])
        if str(row.get("postId", "")).strip() == post_id.strip()
        and str(row.get("status", "pending")).strip().lower() == "pending"
    ]
    if not rows:
        return None
    rows.sort(
        key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))),
        reverse=True,
    )
    return rows[0]


def latest_user_level_request_for_user(
    db: dict[str, Any],
    user_id: str,
    *,
    status: str = "",
) -> dict[str, Any] | None:
    normalized_status = status.strip().lower()
    rows = [
        row
        for row in db.get("userLevelRequests", [])
        if str(row.get("userId", "")).strip() == user_id.strip()
        and (
            not normalized_status
            or str(row.get("status", "pending")).strip().lower() == normalized_status
        )
    ]
    if not rows:
        return None
    rows.sort(
        key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))),
        reverse=True,
    )
    return rows[0]


# ---------------------------------------------------------------------------
# Conversation / DM helpers
# ---------------------------------------------------------------------------


def conversation_key_for_users(user_a_id: str, user_b_id: str) -> str:
    left = user_a_id.strip()
    right = user_b_id.strip()
    if not left or not right:
        return ""
    return "::".join(sorted([left, right]))


def is_user_blocked(db: dict[str, Any], blocker_user_id: str, blocked_user_id: str) -> bool:
    blocker = blocker_user_id.strip()
    blocked = blocked_user_id.strip()
    if not blocker or not blocked:
        return False
    return any(
        str(row.get("blockerUserId", "")).strip() == blocker
        and str(row.get("blockedUserId", "")).strip() == blocked
        for row in db.get("userBlocks", [])
    )


def conversation_block_state(
    db: dict[str, Any],
    *,
    viewer_user_id: str,
    peer_user_id: str,
) -> tuple[bool, bool]:
    return (
        is_user_blocked(db, viewer_user_id, peer_user_id),
        is_user_blocked(db, peer_user_id, viewer_user_id),
    )


def upsert_conversation_for_user(
    db: dict[str, Any],
    *,
    user_id: str,
    peer_user_id: str,
    last_message: str,
    updated_at: str,
    unread_count: int | None = None,
    last_read_at: str | None = None,
    deleted: bool | None = None,
) -> dict[str, Any] | None:
    user = find_user_by_id(db, user_id)
    peer_user = find_user_by_id(db, peer_user_id)
    if user is None or peer_user is None:
        return None

    row = next(
        (
            item
            for item in db.get("conversations", [])
            if item.get("userId") == user_id and item.get("peerUserId") == peer_user_id
        ),
        None,
    )
    if row is None:
        row = {
            "id": next_id(db, "conversation", "c"),
            "userId": user_id,
            "peerUserId": peer_user_id,
            "name": user_nickname(peer_user),
            "avatarUrl": user_avatar_url(peer_user),
            "lastMessage": last_message,
            "unreadCount": max(0, int(unread_count or 0)),
            "lastReadAt": last_read_at or "",
            "updatedAt": updated_at,
            "deleted": bool(deleted) if deleted is not None else False,
        }
        db["conversations"].append(row)
        return row

    row["name"] = user_nickname(peer_user)
    row["avatarUrl"] = user_avatar_url(peer_user)
    row["lastMessage"] = last_message
    row["updatedAt"] = updated_at
    if unread_count is not None:
        row["unreadCount"] = max(0, int(unread_count))
    if last_read_at is not None:
        row["lastReadAt"] = last_read_at
    if deleted is not None:
        row["deleted"] = bool(deleted)
    return row


def sync_conversation_pair(
    db: dict[str, Any],
    *,
    left_user_id: str,
    right_user_id: str,
    last_message: str,
    updated_at: str,
) -> None:
    if not left_user_id.strip() or not right_user_id.strip():
        return
    upsert_conversation_for_user(
        db,
        user_id=left_user_id,
        peer_user_id=right_user_id,
        last_message=last_message,
        updated_at=updated_at,
        deleted=False,
    )
    upsert_conversation_for_user(
        db,
        user_id=right_user_id,
        peer_user_id=left_user_id,
        last_message=last_message,
        updated_at=updated_at,
        deleted=False,
    )


def deliver_message_to_conversation_pair(
    db: dict[str, Any],
    *,
    sender_user_id: str,
    receiver_user_id: str,
    last_message: str,
    updated_at: str,
) -> None:
    sender_row = next(
        (
            item
            for item in db.get("conversations", [])
            if item.get("userId") == sender_user_id and item.get("peerUserId") == receiver_user_id
        ),
        None,
    )
    receiver_row = next(
        (
            item
            for item in db.get("conversations", [])
            if item.get("userId") == receiver_user_id and item.get("peerUserId") == sender_user_id
        ),
        None,
    )
    upsert_conversation_for_user(
        db,
        user_id=sender_user_id,
        peer_user_id=receiver_user_id,
        last_message=last_message,
        updated_at=updated_at,
        unread_count=int(sender_row.get("unreadCount", 0)) if sender_row else 0,
        last_read_at=updated_at,
        deleted=False,
    )
    upsert_conversation_for_user(
        db,
        user_id=receiver_user_id,
        peer_user_id=sender_user_id,
        last_message=last_message,
        updated_at=updated_at,
        unread_count=(int(receiver_row.get("unreadCount", 0)) if receiver_row else 0) + 1,
        deleted=False,
    )


def refresh_conversation_pair_metadata(
    db: dict[str, Any],
    *,
    left_user_id: str,
    right_user_id: str,
    updated_at: str = "",
) -> None:
    left_user_id = left_user_id.strip()
    right_user_id = right_user_id.strip()
    if not left_user_id or not right_user_id:
        return

    conversation_key = conversation_key_for_users(left_user_id, right_user_id)
    messages = [
        row
        for row in db.get("directMessages", [])
        if str(row.get("conversationKey", "")).strip() == conversation_key
        and not row.get("deleted")
    ]
    messages.sort(key=lambda row: (str(row.get("createdAt", "")), str(row.get("id", ""))))

    preview = "开始聊天吧"
    if messages:
        preview = str(messages[-1].get("content", "")).strip() or preview

    effective_updated_at = (
        (str(messages[-1].get("createdAt", "")).strip() if messages else "")
        or updated_at.strip()
        or now_iso()
    )

    def unread_count_for(user_id: str) -> int:
        return sum(
            1
            for row in messages
            if str(row.get("receiverUserId", "")).strip() == user_id
            and not str(row.get("readAt", "")).strip()
        )

    for user_id, peer_user_id in (
        (left_user_id, right_user_id),
        (right_user_id, left_user_id),
    ):
        row = next(
            (
                item
                for item in db.get("conversations", [])
                if item.get("userId") == user_id
                and item.get("peerUserId") == peer_user_id
            ),
            None,
        )
        if row is None:
            continue
        row["lastMessage"] = preview
        row["updatedAt"] = effective_updated_at
        row["unreadCount"] = unread_count_for(user_id)
        row["deleted"] = False


def mark_conversation_read(
    db: dict[str, Any],
    *,
    user_id: str,
    conversation: dict[str, Any],
) -> bool:
    peer_user_id = str(conversation.get("peerUserId", "")).strip()
    if not peer_user_id:
        return False
    conversation_key = conversation_key_for_users(user_id, peer_user_id)
    if not conversation_key:
        return False
    read_at = now_iso()
    changed = False
    for row in db.get("directMessages", []):
        if row.get("deleted"):
            continue
        if str(row.get("conversationKey", "")).strip() != conversation_key:
            continue
        if str(row.get("receiverUserId", "")).strip() != user_id:
            continue
        if str(row.get("readAt", "")).strip():
            continue
        row["readAt"] = read_at
        changed = True
    if int(conversation.get("unreadCount", 0) or 0) != 0:
        conversation["unreadCount"] = 0
        changed = True
    if conversation.get("lastReadAt") != read_at:
        conversation["lastReadAt"] = read_at
        changed = True
    return changed


def reject_pending_dm_requests_between(
    db: dict[str, Any],
    *,
    left_user_id: str,
    right_user_id: str,
    updated_at: str,
) -> bool:
    changed = False
    for row in db.get("dmRequests", []):
        if str(row.get("status", "pending")).strip().lower() != "pending":
            continue
        from_user_id = str(row.get("fromUserId", "")).strip()
        to_user_id = str(row.get("toUserId", "")).strip()
        if {from_user_id, to_user_id} != {left_user_id.strip(), right_user_id.strip()}:
            continue
        row["status"] = "rejected"
        row["updatedAt"] = updated_at
        changed = True
    return changed


def serialize_direct_message(
    db: dict[str, Any],
    row: dict[str, Any],
    *,
    viewer_user_id: str,
) -> dict[str, Any]:
    sender_user_id = str(row.get("senderUserId", ""))
    sender_user = find_user_by_id(db, sender_user_id, include_deleted=True)
    created_at = str(row.get("createdAt", ""))
    read_at = str(row.get("readAt", "")).strip()
    reply_to_id = str(row.get("replyToId", "")).strip()
    reply_to_sender = str(row.get("replyToSender", "")).strip()
    reply_to_content = str(row.get("replyToContent", "")).strip()
    from_me = viewer_user_id == sender_user_id

    can_recall = False
    created_dt = parse_iso(created_at)
    if from_me and created_dt is not None:
        if created_dt.tzinfo is None:
            created_dt = created_dt.replace(tzinfo=timezone.utc)
        can_recall = (now_utc() - created_dt).total_seconds() <= 120

    if reply_to_id and (not reply_to_sender or not reply_to_content):
        reply_message = next(
            (
                item
                for item in db.get("directMessages", [])
                if str(item.get("id", "")).strip() == reply_to_id
            ),
            None,
        )
        if reply_message is not None:
            reply_to_content = reply_to_content or str(reply_message.get("content", "")).strip()
            reply_sender_user = find_user_by_id(
                db,
                str(reply_message.get("senderUserId", "")).strip(),
                include_deleted=True,
            )
            reply_to_sender = reply_to_sender or user_nickname(reply_sender_user)

    return {
        "id": str(row.get("id", "")),
        "content": str(row.get("content", "")),
        "createdAt": created_at,
        "timeText": iso_to_time_text(created_at),
        "fromMe": from_me,
        "senderUserId": sender_user_id,
        "senderAlias": user_nickname(sender_user),
        "readAt": read_at,
        "isRead": bool(read_at),
        "deliveryStatus": "read" if read_at else "sent",
        "canRecall": can_recall,
        "replyToId": reply_to_id or None,
        "replyToSender": reply_to_sender or None,
        "replyToContent": reply_to_content or None,
    }


def iso_to_time_text(value: str | None) -> str:
    if not value:
        return "-"
    dt = parse_iso(value)
    if dt is None:
        return value
    from helpers._datetime_helpers import CHINA_TZ
    return dt.astimezone(CHINA_TZ).strftime("%Y-%m-%d %H:%M")


# ---------------------------------------------------------------------------
# Notification helpers
# ---------------------------------------------------------------------------


def create_notification(
    db: dict[str, Any],
    *,
    user_id: str,
    notification_type: str,
    title: str,
    content: str,
    related_type: str = "",
    related_id: str = "",
    post_id: str = "",
    actor_id: str = "",
    actor_alias: str = "",
) -> dict[str, Any] | None:
    target_user = find_user_by_id(db, user_id, include_deleted=True)
    if target_user is None or target_user.get("deleted"):
        return None
    if not user_accepts_notification(target_user, notification_type):
        return None
    row = {
        "id": next_id(db, "notification", "n"),
        "userId": user_id.strip(),
        "type": notification_type.strip() or "system",
        "title": title.strip(),
        "content": content.strip(),
        "relatedType": related_type.strip(),
        "relatedId": related_id.strip(),
        "postId": post_id.strip(),
        "actorId": actor_id.strip(),
        "actorAlias": actor_alias.strip(),
        "createdAt": now_iso(),
        "readAt": "",
        "deleted": False,
    }
    db.setdefault("notifications", []).append(row)
    return row


def user_accepts_notification(user: dict[str, Any], notification_type: str) -> bool:
    key = _notification_preference_key(notification_type)
    if key is None:
        return True
    return bool(user.get(key, True))


def _notification_preference_key(notification_type: str) -> str | None:
    normalized = notification_type.strip().lower()
    if normalized == "comment":
        return "notifyComment"
    if normalized == "reply":
        return "notifyReply"
    if normalized == "like":
        return "notifyLike"
    if normalized == "favorite":
        return "notifyFavorite"
    if normalized == "report_result":
        return "notifyReportResult"
    if normalized in {"system", "system_announcement"}:
        return "notifySystem"
    return None


def serialize_notification(row: dict[str, Any]) -> dict[str, Any]:
    created_at = str(row.get("createdAt", ""))
    read_at = str(row.get("readAt", "")).strip()
    return {
        "id": str(row.get("id", "")),
        "type": str(row.get("type", "system")),
        "title": str(row.get("title", "")),
        "content": str(row.get("content", "")),
        "relatedType": str(row.get("relatedType", "")),
        "relatedId": str(row.get("relatedId", "")),
        "postId": str(row.get("postId", "")),
        "actorId": str(row.get("actorId", "")),
        "actorAlias": str(row.get("actorAlias", "")),
        "createdAt": created_at,
        "readAt": read_at,
        "isRead": bool(read_at),
    }


def serialize_system_announcement(row: dict[str, Any]) -> dict[str, Any]:
    created_at = str(row.get("createdAt", ""))
    return {
        "id": str(row.get("id", "")),
        "title": str(row.get("title", "")),
        "content": str(row.get("content", "")),
        "createdAt": created_at,
        "timeText": iso_to_time_text(created_at),
        "createdBy": str(row.get("createdBy", "")),
    }


def publish_system_announcement(
    db: dict[str, Any],
    *,
    admin: dict[str, Any],
    title: str,
    content: str,
) -> dict[str, Any]:
    announcement = {
        "id": next_id(db, "announcement", "ann"),
        "title": title.strip(),
        "content": content.strip(),
        "createdAt": now_iso(),
        "createdBy": str(admin.get("id", "")).strip(),
    }
    db.setdefault("systemAnnouncements", []).append(announcement)
    for user in db.get("users", []):
        if user.get("deleted"):
            continue
        create_notification(
            db,
            user_id=str(user.get("id", "")),
            notification_type="system_announcement",
            title=announcement["title"],
            content=announcement["content"],
            related_type="announcement",
            related_id=announcement["id"],
            actor_id=str(admin.get("id", "")),
            actor_alias="管理员",
        )
    return announcement


# ---------------------------------------------------------------------------
# Account cancellation helpers
# ---------------------------------------------------------------------------


def account_cancellation_status_label(status: str) -> str:
    normalized = status.strip().lower() or "pending"
    return {
        "pending": "待审核",
        "approved": "已通过",
        "rejected": "已驳回",
    }.get(normalized, normalized)


def latest_account_cancellation_request_for_user(
    db: dict[str, Any],
    user_id: str,
    *,
    status: str | None = None,
) -> dict[str, Any] | None:
    rows: list[dict[str, Any]] = []
    normalized_status = (status or "").strip().lower()
    for row in db.get("accountCancellationRequests", []):
        if str(row.get("userId", "")) != user_id:
            continue
        row_status = str(row.get("status", "pending")).strip().lower() or "pending"
        if normalized_status and row_status != normalized_status:
            continue
        rows.append(row)
    if not rows:
        return None
    rows.sort(
        key=lambda item: (
            str(item.get("createdAt", "")),
            str(item.get("id", "")),
        ),
        reverse=True,
    )
    return rows[0]


def serialize_account_cancellation_request(row: dict[str, Any]) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    return {
        "id": str(row.get("id", "")),
        "userId": str(row.get("userId", "")),
        "userEmail": str(row.get("userEmail", "")),
        "userNickname": sanitize_alias(str(row.get("userNickname", "")), fallback="匿名同学"),
        "studentId": str(row.get("studentId", "")),
        "avatarUrl": normalize_avatar_url(str(row.get("avatarUrl", ""))),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": account_cancellation_status_label(status),
        "reviewNote": str(row.get("reviewNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
    }


def appeal_status_label(status: str) -> str:
    normalized = status.strip().lower() or "pending"
    return {
        "pending": "待处理",
        "approved": "已通过",
        "rejected": "已驳回",
        "closed": "已关闭",
    }.get(normalized, normalized)


def appeal_type_label(appeal_type: str) -> str:
    normalized = appeal_type.strip().lower() or "other"
    return {
        "account_restore": "账号恢复申诉",
        "account_status": "账号状态申诉",
        "content_review": "内容审核申诉",
        "other": "其他申诉",
    }.get(normalized, normalized)


def serialize_appeal(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    user = find_user_by_id(
        db,
        str(row.get("userId", "")).strip(),
        include_deleted=True,
    )
    nickname = sanitize_alias(
        str(row.get("userNickname", "")),
        fallback=user_nickname(user),
    )
    return {
        "id": str(row.get("id", "")),
        "userId": str(row.get("userId", "")),
        "userEmail": str(row.get("userEmail", "")),
        "studentId": str(row.get("studentId", "")),
        "userNickname": nickname,
        "appealType": str(row.get("appealType", "other")),
        "appealTypeLabel": appeal_type_label(str(row.get("appealType", "other"))),
        "targetType": str(row.get("targetType", "")),
        "targetId": str(row.get("targetId", "")),
        "title": str(row.get("title", "")),
        "content": str(row.get("content", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
        "userDeleted": bool(user.get("deleted", False)) if user else False,
        "userBanned": bool(user.get("banned", False)) if user else False,
        "userMuted": bool(user.get("muted", False)) if user else False,
    }


def serialize_user_level_request_summary(
    row: dict[str, Any] | None,
) -> dict[str, Any] | None:
    if row is None:
        return None
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    current_level = normalize_user_level(row.get("currentLevel"))
    target_level = normalize_user_level(row.get("targetLevel"))
    return {
        "id": str(row.get("id", "")),
        "currentLevel": current_level,
        "currentLevelLabel": user_level_label(current_level),
        "targetLevel": target_level,
        "targetLevelLabel": user_level_label(target_level),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
    }


def serialize_admin_post_pin_request(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    post = next(
        (
            item
            for item in db.get("posts", [])
            if str(item.get("id", "")).strip() == str(row.get("postId", "")).strip()
        ),
        None,
    )
    user = find_user_by_id(
        db,
        str(row.get("userId", "")).strip(),
        include_deleted=True,
    )
    return {
        "id": str(row.get("id", "")),
        "postId": str(row.get("postId", "")),
        "postTitle": str(post.get("title", "")) if post else "",
        "userId": str(row.get("userId", "")),
        "userEmail": str(user.get("email", "")) if user else "",
        "userNickname": user_nickname(user),
        "durationMinutes": int(row.get("durationMinutes", 0) or 0),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
    }


def serialize_admin_user_level_request(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    status = str(row.get("status", "pending")).strip().lower() or "pending"
    user = find_user_by_id(
        db,
        str(row.get("userId", "")).strip(),
        include_deleted=True,
    )
    current_level = normalize_user_level(row.get("currentLevel"))
    target_level = normalize_user_level(row.get("targetLevel"))
    return {
        "id": str(row.get("id", "")),
        "userId": str(row.get("userId", "")),
        "userEmail": str(user.get("email", "")) if user else "",
        "userNickname": user_nickname(user),
        "studentId": str(user.get("studentId", "")) if user else "",
        "currentLevel": current_level,
        "currentLevelLabel": user_level_label(current_level),
        "targetLevel": target_level,
        "targetLevelLabel": user_level_label(target_level),
        "reason": str(row.get("reason", "")),
        "status": status,
        "statusLabel": appeal_status_label(status),
        "adminNote": str(row.get("adminNote", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
        "handledBy": str(row.get("handledBy", "")),
    }


def latest_pending_appeal_for_user(db: dict[str, Any], user_id: str) -> dict[str, Any] | None:
    rows = [
        row
        for row in db.get("appeals", [])
        if str(row.get("userId", "")).strip() == user_id.strip()
        and str(row.get("status", "pending")).strip().lower() == "pending"
    ]
    if not rows:
        return None
    rows.sort(key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))), reverse=True)
    return rows[0]


def restore_user_account(
    db: dict[str, Any],
    user: dict[str, Any],
) -> None:
    user["deleted"] = False
    user["banned"] = False
    user["muted"] = False


def sync_cancellation_requests_after_admin_cancel(
    db: dict[str, Any],
    *,
    user_id: str,
    handled_by: str,
    review_note: str,
) -> None:
    handled_at = now_iso()
    for row in db.get("accountCancellationRequests", []):
        if str(row.get("userId", "")).strip() != user_id.strip():
            continue
        if str(row.get("status", "pending")).strip().lower() != "pending":
            continue
        row["status"] = "approved"
        row["handledAt"] = handled_at
        row["handledBy"] = handled_by
        row["reviewNote"] = review_note or "管理员直接注销违规账号，申请已同步完成"


def cancel_user_account(
    db: dict[str, Any],
    user: dict[str, Any],
    *,
    actor_id: str,
    detail: str,
) -> None:
    user_id = str(user.get("id", "")).strip()
    user["deleted"] = True

    email = str(user.get("email", "")).strip().lower()
    if email:
        db["emailCodes"].pop(email, None)
        db["emailCodes"].pop(f"{_globals.PASSWORD_RESET_CODE_PREFIX}{email}", None)

    for token, uid in list(db["sessions"].items()):
        if uid == user_id:
            db["sessions"].pop(token, None)

    db["dmRequests"] = [
        row
        for row in db.get("dmRequests", [])
        if row.get("toUserId") != user_id and row.get("fromUserId") != user_id
    ]
    db["userBlocks"] = [
        row
        for row in db.get("userBlocks", [])
        if row.get("blockerUserId") != user_id and row.get("blockedUserId") != user_id
    ]
    db["conversations"] = [
        row
        for row in db.get("conversations", [])
        if row.get("userId") != user_id and row.get("peerUserId") != user_id
    ]
    db["directMessages"] = [
        row
        for row in db.get("directMessages", [])
        if row.get("senderUserId") != user_id and row.get("receiverUserId") != user_id
    ]
    db["notifications"] = [
        row
        for row in db.get("notifications", [])
        if row.get("userId") != user_id and row.get("actorId") != user_id
    ]

    avatar_key = ""
    avatar_url = user.get("avatarUrl", "")
    if avatar_url:
        marker = "/api/storage/"
        idx = avatar_url.find(marker)
        if idx >= 0:
            avatar_key = avatar_url[idx + len(marker):].strip().lstrip("/")
    if avatar_key:
        try:
            _globals.OBJECT_STORAGE.delete(avatar_key)
        except Exception:
            pass
    user["avatarUrl"] = ""

    affected_post_ids: set[str] = set()
    for upload in db.get("mediaUploads", []):
        if upload.get("uploaderId") != user.get("id") or upload.get("deleted"):
            continue
        upload["deleted"] = True
        post_id = str(upload.get("postId", "")).strip()
        if post_id:
            affected_post_ids.add(post_id)
        object_key = str(upload.get("objectKey", "")).strip()
        if object_key:
            try:
                _globals.OBJECT_STORAGE.delete(object_key)
            except Exception:
                pass

    for post_id in affected_post_ids:
        recalc_post_has_image(db, post_id)

    from services._db_service import add_audit_log
    add_audit_log(db, actor_id, "cancel_account", detail)


def recalc_post_has_image(db: dict[str, Any], post_id: str) -> bool:
    post = next((p for p in db["posts"] if p.get("id") == post_id), None)
    if post is None:
        return False

    has_image = any(
        (not upload.get("deleted"))
        and upload.get("postId") == post_id
        and str(upload.get("status", "pending")).lower() in {"pending", "approved", "risk"}
        for upload in db.get("mediaUploads", [])
    )
    if bool(post.get("hasImage", False)) != has_image:
        post["hasImage"] = has_image
        post["updatedAt"] = now_iso()
    return has_image
