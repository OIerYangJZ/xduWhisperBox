#!/usr/bin/env python3
from __future__ import annotations

import json
import logging
import mimetypes
import os
import re
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse

from object_storage import build_object_storage_from_env
from sql_repository import SqliteTreeholeRepository

import _globals

# Handler modules (extracted from this file)
import handlers as _handlers
import handlers._admin_handler as _admin_handler
import handlers._auth_handler as _auth_handler
import handlers._comment_handler as _comment_handler
import handlers._message_handler as _message_handler
import handlers._notification_handler as _notification_handler
import handlers._post_handler as _post_handler
import handlers._static_handler as _static_handler
import handlers._upload_handler as _upload_handler
import handlers._user_handler as _user_handler

_logger = logging.getLogger("xduwhisperbox")
_logged_already = False

# ---------------------------------------------------------------------------
# Configuration (from _globals)
# ---------------------------------------------------------------------------
_globals.configure()

ROOT_DIR = _globals.ROOT_DIR
DATA_DIR = _globals.DATA_DIR
LEGACY_DB_FILE = _globals.LEGACY_DB_FILE
SQL_DB_FILE = _globals.SQL_DB_FILE
OBJECT_STORAGE_DIR = _globals.OBJECT_STORAGE_DIR
WEB_ROOT_DIR = _globals.WEB_ROOT_DIR
DB_LOCK = _globals.DB_LOCK
REPOSITORY = _globals.REPOSITORY
OBJECT_STORAGE = _globals.OBJECT_STORAGE
ADMIN_SESSIONS = _globals.ADMIN_SESSIONS
ADMIN_SESSION_LOCK = _globals.ADMIN_SESSION_LOCK
ALLOWED_IMAGE_TYPES = _globals.ALLOWED_IMAGE_TYPES
BACKEND_VERSION = _globals.BACKEND_VERSION
DEFAULT_ADMIN_USERNAME = _globals.DEFAULT_ADMIN_USERNAME
DEFAULT_ADMIN_PASSWORD = _globals.DEFAULT_ADMIN_PASSWORD
DEMO_USER_EMAIL = _globals.DEMO_USER_EMAIL
SMTP_HOST = _globals.SMTP_HOST
SMTP_PORT = _globals.SMTP_PORT
SMTP_FROM_EMAIL = _globals.SMTP_FROM_EMAIL
SMTP_USE_SSL = _globals.SMTP_USE_SSL
SMTP_USE_STARTTLS = _globals.SMTP_USE_STARTTLS

# ---------------------------------------------------------------------------
# Re-export helpers for TreeholeHandler
# ---------------------------------------------------------------------------
from helpers import (
    read_json_body,
    send_json,
    json_error,
    send_binary,
    send_static_file,
    resolve_web_asset_path,
    should_fallback_to_spa,
    now_iso,
    now_utc,
    parse_iso,
    CHINA_TZ,
)
from helpers._auth_helpers import hash_password, verify_password, is_password_hashed, is_campus_email, is_valid_student_id, sanitize_alias, normalize_avatar_url, extract_local_object_key_from_url, decode_base64_payload, detect_image_type, random_code, student_id_from_email, calc_sha256_hex, parse_bool, parse_list
from helpers._rate_limit import consume_rate_limit, get_client_ip, check_ip_rate_limit, check_duplicate_image_hash, assess_text_risk, send_rate_limit_error, get_setting_int
from helpers._mailer import send_verification_email, send_password_reset_email, verification_send_error_message
from services import (
    load_db, save_db, default_db, ensure_db, migrate_db, add_audit_log, next_id,
    find_user_by_email, find_user_by_id, find_user_by_student_id,
    user_nickname, user_avatar_url, serialize_public_user_profile,
    create_notification, serialize_notification, serialize_system_announcement,
    publish_system_announcement, cancel_user_account, restore_user_account,
    serialize_account_cancellation_request, serialize_appeal,
    serialize_admin_user_level_request, serialize_admin_post_pin_request,
    sync_cancellation_requests_after_admin_cancel, recalc_post_has_image,
    reject_pending_dm_requests_between, upsert_conversation_for_user,
    sync_conversation_pair, deliver_message_to_conversation_pair,
    mark_conversation_read, serialize_direct_message, is_user_blocked,
    conversation_block_state, conversation_key_for_users, can_request_dm_to_user,
    apply_post_pin, is_post_pin_active, latest_pending_post_pin_request_for_post,
    latest_user_level_request_for_user, latest_pending_appeal_for_user,
    latest_account_cancellation_request_for_user,
    account_cancellation_status_label, appeal_status_label, appeal_type_label,
    serialize_user_level_request_summary, list_following_users, list_follower_users,
    list_friend_users, is_user_following, count_following, count_followers,
    build_follow_user_item, normalize_optional_bool, is_post_anonymous,
    effective_post_allow_dm,
)
from services._db_service import (
    build_admin_account, normalize_admin_username, is_valid_admin_username,
    find_admin_account_by_username, find_admin_account_by_id,
    build_authenticated_admin, serialize_admin_auth_payload,
    build_admin_account_rows, build_admin_review_rows, build_admin_report_rows,
    build_admin_image_rows, serialize_admin_report, build_appeal_rows,
    serialize_image_upload, build_image_rows, public_system_settings,
    auth_user as auth_user_helper, build_pagination_meta, IS_SQL_DB,
)
from _globals import smtp_configured, verify_code_debug_enabled, DEFAULT_CHANNELS


def _configure_logging() -> None:
    global _logged_already
    if _logged_already:
        return
    _logged_already = True
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-8s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    if verify_code_debug_enabled():
        _logger.setLevel(logging.DEBUG)


_BACKEND_VERSION = "0.2"


def _get_version_info() -> dict[str, Any]:
    import subprocess
    git_hash = "unknown"
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(ROOT_DIR),
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            git_hash = result.stdout.strip()
    except Exception:
        pass
    return {
        "version": f"XduTreeholeBackend/{_BACKEND_VERSION}",
        "backendVersion": _BACKEND_VERSION,
        "gitHash": git_hash,
        "buildDate": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


class TreeholeHandler(BaseHTTPRequestHandler):
    server_version = "XduTreeholeBackend/0.2"

    def do_OPTIONS(self) -> None:  # noqa: N802
        send_json(self, HTTPStatus.OK, {"message": "ok"})

    def do_GET(self) -> None:  # noqa: N802
        self._handle("GET")

    def do_POST(self) -> None:  # noqa: N802
        self._handle("POST")

    def do_PATCH(self) -> None:  # noqa: N802
        self._handle("PATCH")

    def do_DELETE(self) -> None:  # noqa: N802
        self._handle("DELETE")

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        return

    def _handle(self, method: str) -> None:
        try:
            parsed = urlparse(self.path)
            path = parsed.path
            query = parse_qs(parsed.query)
            if not path.startswith("/api"):
                if method == "GET":
                    self._handle_web_get(path)
                    return
                json_error(self, HTTPStatus.NOT_FOUND, "Not Found")
                return

            if method == "GET":
                self._handle_get(path, query)
                return
            if method == "POST":
                self._handle_post(path)
                return
            if method == "PATCH":
                self._handle_patch(path)
                return
            if method == "DELETE":
                self._handle_delete(path)
                return

            json_error(self, HTTPStatus.METHOD_NOT_ALLOWED, "Method not allowed")
        except Exception as error:  # pragma: no cover
            _logger.exception("Unhandled error in _handle_web_delete")
            json_error(self, HTTPStatus.INTERNAL_SERVER_ERROR, "Internal server error")

    def _handle_web_get(self, path: str) -> None:
        index_file = WEB_ROOT_DIR / "index.html"
        if not WEB_ROOT_DIR.exists() or not index_file.exists():
            json_error(
                self,
                HTTPStatus.NOT_FOUND,
                f"Web bundle not found, run flutter build web first ({WEB_ROOT_DIR})",
            )
            return

        target = resolve_web_asset_path(path)
        if target and target.exists() and target.is_file():
            send_static_file(self, target)
            return

        if should_fallback_to_spa(path):
            send_static_file(self, index_file)
            return

        json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_get(self, path: str, query: dict[str, list[str]]) -> None:
        # Static / info endpoints (still inline for now)
        if path == "/api/health":
            db_ok = False
            storage_ok = False
            try:
                with DB_LOCK:
                    test_db = load_db()
                    db_ok = isinstance(test_db, dict)
            except Exception:
                pass
            try:
                storage_ok = OBJECT_STORAGE.get_bytes("__health_check__") is not None or True
            except Exception:
                pass
            status = "healthy" if (db_ok and storage_ok) else "degraded"
            http_status = HTTPStatus.OK if db_ok else HTTPStatus.SERVICE_UNAVAILABLE
            send_json(self, http_status, {
                "status": status,
                "version": "XduTreeholeBackend/0.2",
                "database": "ok" if db_ok else "error",
                "smtp": "ok" if smtp_configured() else "not_configured",
                "storage": "ok" if storage_ok else "error",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })
            return

        if path == "/api/version":
            send_json(self, HTTPStatus.OK, _get_version_info())
            return

        if path == "/api/auth/xidian/start":
            _auth_handler.handle_xidian_auth_start(self, {}, query)
            return

        # Object storage
        if _static_handler.handle_storage_get(self, path):
            return

        with DB_LOCK:
            db = load_db()

            # Channels
            if path == "/api/channels":
                channel_rows = list(dict.fromkeys(["综合", *(db.get("channels", []) or []), *_globals.DEFAULT_CHANNELS]))
                send_json(self, HTTPStatus.OK, {"data": channel_rows})
                return

            # Notifications
            if path == "/api/notifications":
                _notification_handler.handle_get_notifications(self, db)
                return

            # Posts
            if path == "/api/posts":
                _post_handler.handle_get_posts(self, db, query)
                return
            if path == "/api/posts/mine":
                _post_handler.handle_get_posts_mine(self, db)
                return
            if path == "/api/posts/favorites":
                _post_handler.handle_get_posts_favorites(self, db)
                return
            if path == "/api/uploads/mine":
                _post_handler.handle_get_uploads_mine(self, db)
                return
            if path == "/api/comments/mine":
                _post_handler.handle_get_comments_mine(self, db)
                return
            if path == "/api/reports/mine":
                _post_handler.handle_get_reports_mine(self, db)
                return

            # Post detail / comments
            _post_m_comments_match = re.fullmatch(r"/api/posts/([^/]+)/comments", path)
            if _post_m_comments_match:
                _post_handler.handle_get_post_comments(
                    self,
                    db,
                    _post_m_comments_match.group(1),
                    query=query,
                )
                return

            _post_match = re.fullmatch(r"/api/posts/([^/]+)", path)
            if _post_match:
                _post_handler.handle_get_post(self, db, _post_match.group(1))
                return

            # Report detail
            _report_match = re.fullmatch(r"/api/reports/([^/]+)", path)
            if _report_match:
                _post_handler.handle_get_report_detail(self, db, _report_match.group(1))
                return

            # Messages — requests & conversations
            if path == "/api/messages/requests":
                _message_handler.handle_get_requests(self, db)
                return
            if path == "/api/messages/conversations":
                _message_handler.handle_get_conversations(self, db)
                return

            _conv_messages_match = re.fullmatch(r"/api/messages/conversations/([^/]+)/messages", path)
            if _conv_messages_match:
                _message_handler.handle_get_messages(self, db, _conv_messages_match.group(1))
                return

            # NOTE: POST /api/messages/conversations/direct is intentionally handled
            # inside _handle_post (see _handle_post for the direct-conversation route).

            # User — self / social
            if path == "/api/users/me/following":
                _user_handler.handle_get_following(self, db)
                return
            if path == "/api/users/me/followers":
                _user_handler.handle_get_followers(self, db)
                return
            if path == "/api/users/me/friends":
                _user_handler.handle_get_friends(self, db)
                return
            if path == "/api/users/me":
                _user_handler.handle_get_me(self, db)
                return
            if path == "/api/users/search":
                _user_handler.handle_search_users(self, db, query)
                return

            if path == "/api/auth/xidian/callback":
                _auth_handler.handle_xidian_auth_callback(self, db, query)
                return
            if path == "/api/auth/xidian/mobile/callback":
                _auth_handler.handle_xidian_mobile_callback(self, db, query)
                return

            _xidian_auth_session_match = re.fullmatch(r"/api/auth/xidian/session/([^/]+)", path)
            if _xidian_auth_session_match:
                _auth_handler.handle_xidian_auth_get_session(self, db, _xidian_auth_session_match.group(1))
                return

            _user_match = re.fullmatch(r"/api/users/([^/]+)", path)
            if _user_match:
                _user_handler.handle_get_user(self, db, _user_match.group(1))
                return

            # Notification actions
            if path == "/api/notifications/read-all":
                _notification_handler.handle_mark_all_notifications_read(self, db)
                return

            _notif_read_match = re.fullmatch(r"/api/notifications/([^/]+)/read", path)
            if _notif_read_match:
                _notification_handler.handle_mark_notification_read(self, db, _notif_read_match.group(1))
                return

            # Admin endpoints
            if path == "/api/admin/auth/me":
                _admin_handler.handle_admin_auth_me(self, db)
                return
            if path == "/api/admin/overview":
                _admin_handler.handle_admin_overview(self, db)
                return
            if path == "/api/admin/reviews":
                _admin_handler.handle_admin_reviews(self, db, query)
                return
            if path == "/api/admin/reports":
                _admin_handler.handle_admin_reports(self, db, query)
                return
            if path == "/api/admin/images/reviews":
                _admin_handler.handle_admin_images_reviews(self, db, query)
                return
            if path == "/api/admin/users":
                _admin_handler.handle_admin_users(self, db)
                return
            if path == "/api/admin/post-pin-requests":
                _admin_handler.handle_admin_post_pin_requests(self, db, query)
                return
            if path == "/api/admin/user-level-requests":
                _admin_handler.handle_admin_user_level_requests(self, db, query)
                return
            if path == "/api/admin/admin-accounts":
                _admin_handler.handle_admin_admin_accounts(self, db)
                return
            if path == "/api/admin/account-cancellation-requests":
                _admin_handler.handle_admin_account_cancellation_requests(self, db, query)
                return
            if path == "/api/admin/appeals":
                _admin_handler.handle_admin_appeals(self, db, query)
                return
            if path == "/api/admin/export":
                _admin_handler.handle_admin_export(self, db, query)
                return
            if path == "/api/admin/channels-tags":
                _admin_handler.handle_admin_channels_tags(self, db)
                return
            if path == "/api/admin/config":
                _admin_handler.handle_admin_config(self, db)
                return
            if path == "/api/admin/releases/android":
                _admin_handler.handle_admin_android_release(self, db)
                return
            if path == "/api/admin/announcements":
                _admin_handler.handle_admin_announcements(self, db)
                return
            if path == "/api/releases/android/latest":
                _admin_handler.handle_public_android_release(self, db)
                return

            # Fallback: 404
            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_post(self, path: str) -> None:
        with DB_LOCK:
            db = load_db()

            if path == "/api/admin/auth/login":
                _admin_handler.handle_admin_auth_login(self, db)
                return

            if path == "/api/admin/auth/logout":
                _admin_handler.handle_admin_auth_logout(self, db)
                return

            if path == "/api/admin/admin-accounts":
                _admin_handler.handle_admin_create_account(self, db)
                return

            if path in {"/api/auth/send-code", "/api/auth/resend-code"}:
                _auth_handler.handle_send_code(self, db)
                return

            if path == "/api/auth/password/send-code":
                _auth_handler.handle_password_send_code(self, db)
                return

            if path == "/api/auth/password/reset":
                _auth_handler.handle_password_reset(self, db)
                return

            if path == "/api/auth/login":
                _auth_handler.handle_login(self, db)
                return

            if path == "/api/auth/xidian/session":
                _auth_handler.handle_xidian_auth_create_session(self, db)
                return

            if path == "/api/auth/register":
                _auth_handler.handle_register(self, db)
                return

            if path == "/api/auth/verify":
                _auth_handler.handle_verify(self, db)
                return

            if path == "/api/auth/logout":
                _auth_handler.handle_logout(self, db)
                return

            if path == "/api/notifications/read-all":
                _notification_handler.handle_mark_all_notifications_read(self, db)
                return

            match_notification_read = re.fullmatch(r"/api/notifications/([^/]+)/read", path)
            if match_notification_read:
                _notification_handler.handle_mark_notification_read(self, db, match_notification_read.group(1))
                return

            if path == "/api/messages/requests":
                _message_handler.handle_send_request(self, db)
                return

            if path == "/api/messages/conversations/direct":
                _message_handler.handle_direct_conversation(self, db)
                return

            if path == "/api/uploads/images":
                _upload_handler.handle_upload_image(self, db)
                return

            if path == "/api/users/avatar":
                _upload_handler.handle_upload_avatar(self, db)
                return

            if path in {
                "/api/users/notification-preferences",
                "/api/users/me/notification-preferences",
            }:
                _user_handler.handle_update_notification_preferences(self, db)
                return

            if path == "/api/users/me/cancellation-request":
                _comment_handler.handle_cancel_account_request(self, db)
                return

            if path == "/api/users/me/level-upgrade-request":
                _comment_handler.handle_level_upgrade_request(self, db)
                return

            match_follow_user = re.fullmatch(r"/api/users/([^/]+)/(follow|unfollow)", path)
            if match_follow_user:
                target_user_id = match_follow_user.group(1)
                action = match_follow_user.group(2)
                if action == "follow":
                    _user_handler.handle_follow(self, db, target_user_id)
                else:
                    _user_handler.handle_unfollow(self, db, target_user_id)
                return

            if path == "/api/appeals":
                _post_handler.handle_submit_appeal(self, db)
                return

            if path == "/api/admin/announcements":
                _admin_handler.handle_admin_announcement(self, db)
                return

            if path == "/api/admin/releases/android":
                _admin_handler.handle_admin_upload_android_release(self, db)
                return

            match_conversation_send = re.fullmatch(
                r"/api/messages/conversations/([^/]+)/messages",
                path,
            )
            if match_conversation_send:
                _message_handler.handle_send_message(self, db, match_conversation_send.group(1))
                return

            match_conversation_block = re.fullmatch(
                r"/api/messages/conversations/([^/]+)/(block|unblock)",
                path,
            )
            if match_conversation_block:
                conversation_id = match_conversation_block.group(1)
                action = match_conversation_block.group(2)
                if action == "block":
                    _message_handler.handle_block_peer(self, db, conversation_id)
                else:
                    _message_handler.handle_unblock_peer(self, db, conversation_id)
                return

            if path == "/api/posts":
                _post_handler.handle_create_post(self, db)
                return

            match_post_pin_request = re.fullmatch(r"/api/posts/([^/]+)/pin-request", path)
            if match_post_pin_request:
                _post_handler.handle_pin_request(self, db, match_post_pin_request.group(1))
                return

            if path == "/api/reports":
                _post_handler.handle_submit_report(self, db)
                return

            match_action = re.fullmatch(r"/api/messages/requests/([^/]+)/(accept|reject)", path)
            if match_action:
                request_id = match_action.group(1)
                action = match_action.group(2)
                if action == "accept":
                    _message_handler.handle_accept_request(self, db, request_id)
                else:
                    _message_handler.handle_reject_request(self, db, request_id)
                return

            match_comment = re.fullmatch(r"/api/posts/([^/]+)/comments", path)
            if match_comment:
                _post_handler.handle_create_comment(self, db, match_comment.group(1))
                return

            match_like = re.fullmatch(r"/api/posts/([^/]+)/like", path)
            if match_like:
                _post_handler.handle_toggle_like(self, db, match_like.group(1))
                return

            match_comment_like = re.fullmatch(r"/api/comments/([^/]+)/like", path)
            if match_comment_like:
                _post_handler.handle_toggle_comment_like(self, db, match_comment_like.group(1))
                return

            match_fav = re.fullmatch(r"/api/posts/([^/]+)/favorite", path)
            if match_fav:
                _post_handler.handle_toggle_favorite(self, db, match_fav.group(1))
                return

            match_view = re.fullmatch(r"/api/posts/([^/]+)/view", path)
            if match_view:
                _post_handler.handle_increment_view(self, db, match_view.group(1))
                return

            if path == "/api/admin/reviews/batch":
                _admin_handler.handle_admin_review_batch(self, db)
                return

            match_review = re.fullmatch(r"/api/admin/reviews/(post|comment)/([^/]+)/(approve|reject|delete|risk)", path)
            if match_review:
                _admin_handler.handle_admin_single_review(
                    self, db,
                    match_review.group(1),
                    match_review.group(2),
                    match_review.group(3),
                )
                return

            match_report_handle = re.fullmatch(r"/api/admin/reports/([^/]+)/handle", path)
            if match_report_handle:
                _admin_handler.handle_admin_report_action(self, db, match_report_handle.group(1))
                return

            match_post_pin_request_handle = re.fullmatch(
                r"/api/admin/post-pin-requests/([^/]+)/handle",
                path,
            )
            if match_post_pin_request_handle:
                _admin_handler.handle_admin_post_pin_request_action(self, db, match_post_pin_request_handle.group(1))
                return

            match_user_level_request_handle = re.fullmatch(
                r"/api/admin/user-level-requests/([^/]+)/handle",
                path,
            )
            if match_user_level_request_handle:
                _admin_handler.handle_admin_user_level_request_action(self, db, match_user_level_request_handle.group(1))
                return

            match_admin_account_action = re.fullmatch(
                r"/api/admin/admin-accounts/([^/]+)/action",
                path,
            )
            if match_admin_account_action:
                _admin_handler.handle_admin_account_action(self, db, match_admin_account_action.group(1))
                return

            match_user_action = re.fullmatch(r"/api/admin/users/([^/]+)/action", path)
            if match_user_action:
                _admin_handler.handle_admin_user_action(self, db, match_user_action.group(1))
                return

            match_appeal_handle = re.fullmatch(r"/api/admin/appeals/([^/]+)/handle", path)
            if match_appeal_handle:
                _admin_handler.handle_admin_appeal_action(self, db, match_appeal_handle.group(1))
                return

            match_cancellation_handle = re.fullmatch(
                r"/api/admin/account-cancellation-requests/([^/]+)/handle",
                path,
            )
            if match_cancellation_handle:
                _admin_handler.handle_admin_cancellation_action(self, db, match_cancellation_handle.group(1))
                return

            match_image_review = re.fullmatch(r"/api/admin/images/([^/]+)/review", path)
            if match_image_review:
                _admin_handler.handle_admin_image_review(self, db, match_image_review.group(1))
                return

            if path == "/api/admin/channels":
                _admin_handler.handle_admin_add_channel(self, db)
                return

            if path == "/api/admin/tags":
                _admin_handler.handle_admin_add_tag(self, db)
                return

            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_patch(self, path: str) -> None:
        with DB_LOCK:
            db = load_db()

            if path == "/api/admin/auth/password":
                _admin_handler.handle_admin_change_password(self, db)
                return

            if path == "/api/users/privacy":
                _user_handler.handle_update_privacy(self, db)
                return

            if path in {
                "/api/users/notification-preferences",
                "/api/users/me/notification-preferences",
            }:
                _user_handler.handle_update_notification_preferences(self, db)
                return

            if path == "/api/users/me":
                _user_handler.handle_update_me(self, db)
                return

            match_post = re.fullmatch(r"/api/posts/([^/]+)", path)
            if match_post:
                _post_handler.handle_update_post(self, db, match_post.group(1))
                return

            match_channel = re.fullmatch(r"/api/admin/channels/(.+)", path)
            if match_channel:
                _admin_handler.handle_admin_rename_channel(self, db, unquote(match_channel.group(1)))
                return

            match_tag = re.fullmatch(r"/api/admin/tags/(.+)", path)
            if match_tag:
                _admin_handler.handle_admin_rename_tag(self, db, unquote(match_tag.group(1)))
                return

            if path == "/api/admin/config":
                _admin_handler.handle_admin_update_config(self, db)
                return

            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")

    def _handle_delete(self, path: str) -> None:
        with DB_LOCK:
            db = load_db()

            if path == "/api/users/me":
                json_error(self, HTTPStatus.METHOD_NOT_ALLOWED, "请改用注销申请接口")
                return

            match_comment = re.fullmatch(r"/api/comments/([^/]+)", path)
            if match_comment:
                _post_handler.handle_delete_comment(self, db, match_comment.group(1))
                return

            match_comment_unlike = re.fullmatch(r"/api/comments/([^/]+)/like", path)
            if match_comment_unlike:
                _post_handler.handle_toggle_comment_like(self, db, match_comment_unlike.group(1))
                return

            match_post = re.fullmatch(r"/api/posts/([^/]+)", path)
            if match_post:
                _post_handler.handle_delete_post(self, db, match_post.group(1))
                return

            match_conversation = re.fullmatch(r"/api/messages/conversations/([^/]+)", path)
            if match_conversation:
                _message_handler.handle_delete_conversation(self, db, match_conversation.group(1))
                return

            match_message_recall = re.fullmatch(
                r"/api/messages/messages/([^/]+)/recall",
                path,
            )
            if match_message_recall:
                _message_handler.handle_message_recall(self, db, match_message_recall.group(1))
                return

            match_favorite = re.fullmatch(r"/api/posts/([^/]+)/favorite", path)
            if match_favorite:
                _post_handler.handle_remove_favorite(self, db, match_favorite.group(1))
                return

            match_del_channel = re.fullmatch(r"/api/admin/channels/(.+)", path)
            if match_del_channel:
                _admin_handler.handle_admin_delete_channel(self, db, unquote(match_del_channel.group(1)))
                return

            match_del_tag = re.fullmatch(r"/api/admin/tags/(.+)", path)
            if match_del_tag:
                _admin_handler.handle_admin_delete_tag(self, db, unquote(match_del_tag.group(1)))
                return

            json_error(self, HTTPStatus.NOT_FOUND, "Not Found")


def main() -> None:
    _configure_logging()
    ensure_db()
    host = os.environ.get("BACKEND_HOST", "0.0.0.0")
    port = int(os.environ.get("BACKEND_PORT", "8080"))

    server = ThreadingHTTPServer((host, port), TreeholeHandler)
    _logger.info(f"XDU Treehole API is running at http://{host}:{port}/api")
    _logger.info(f"Web root: {WEB_ROOT_DIR}")
    if not WEB_ROOT_DIR.exists() or not (WEB_ROOT_DIR / "index.html").exists():
        _logger.warning("[backend] Web bundle missing. Run `flutter build web --dart-define=API_BASE_URL=/api`")
    _logger.info(f"SQL storage: {SQL_DB_FILE}")
    _logger.info(f"Object storage: {OBJECT_STORAGE.describe()}")
    if smtp_configured():
        smtp_mode = "SMTP_SSL" if SMTP_USE_SSL else ("SMTP+STARTTLS" if SMTP_USE_STARTTLS else "SMTP")
        _logger.info(
            f"SMTP: {smtp_mode} {SMTP_HOST}:{SMTP_PORT} from={SMTP_FROM_EMAIL}"
        )
    else:
        _logger.info("SMTP: not configured (set BACKEND_SMTP_* to enable email verification)")
    _logger.info("User auth: 浏览器统一认证回调登录（树洞后端不接收统一认证密码）")
    if getattr(_globals, "BACKEND_XIDIAN_PUBLIC_ORIGIN", ""):
        _logger.info(f"Xidian auth public origin: {getattr(_globals, 'BACKEND_XIDIAN_PUBLIC_ORIGIN')}")
    else:
        _logger.warning(
            "Xidian auth public origin is empty. "
            "If IDS browser/mobile login is enabled behind domain/proxy/IP, "
            "set BACKEND_XIDIAN_PUBLIC_ORIGIN to the IDS-registered HTTPS origin."
        )
    _logger.info(f"Admin account: {DEFAULT_ADMIN_USERNAME} / {DEFAULT_ADMIN_PASSWORD}")
    if verify_code_debug_enabled():
        _logger.debug("Debug verify code enabled: 123456")
    server.serve_forever()


if __name__ == "__main__":
    main()
