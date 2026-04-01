"""管理员审核测试。"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))


class TestAdminAuthHelpers:
    """测试管理员认证辅助函数。"""

    def test_default_admin_credentials(self):
        """测试默认管理员凭据。"""
        from server import (
            DEFAULT_ADMIN_PASSWORD,
            DEFAULT_ADMIN_USERNAME,
            ensure_admin_auth_settings,
            get_admin_auth_credentials,
        )

        db: dict = {}
        ensure_admin_auth_settings(db)

        username, password_hash = get_admin_auth_credentials(db)
        assert username == DEFAULT_ADMIN_USERNAME
        assert len(password_hash) > 0

        # 验证密码正确
        from server import verify_password

        assert verify_password(password_hash, DEFAULT_ADMIN_PASSWORD) is True

    def test_admin_sessions_management(self):
        """测试管理员会话管理。"""
        from server import ADMIN_SESSIONS, ADMIN_SESSION_LOCK

        assert isinstance(ADMIN_SESSIONS, dict)

        with ADMIN_SESSION_LOCK:
            initial_len = len(ADMIN_SESSIONS)


class TestAdminSettings:
    """测试管理员设置。"""

    def test_admin_settings_keys(self):
        """测试管理员设置键。"""
        from server import ADMIN_PASSWORD_HASH_SETTING_KEY, ADMIN_USERNAME_SETTING_KEY

        assert "adminUsername" in ADMIN_USERNAME_SETTING_KEY
        assert "adminPasswordHash" in ADMIN_PASSWORD_HASH_SETTING_KEY

    def test_admin_auth_settings_persistence(self):
        """测试管理员设置持久化。"""
        from server import ensure_admin_auth_settings, hash_password

        db: dict = {}
        ensure_admin_auth_settings(db)

        assert "settings" in db
        assert ADMIN_USERNAME_SETTING_KEY in db["settings"]
        assert ADMIN_PASSWORD_HASH_SETTING_KEY in db["settings"]

        # 再次调用不应更改设置
        db2 = dict(db)
        ensure_admin_auth_settings(db2)
        assert db["settings"] == db2["settings"]


class TestAuditLogging:
    """测试审计日志功能。"""

    def test_default_db_has_audit_logs(self):
        """测试默认数据库包含审计日志表。"""
        from server import default_db

        db = default_db()
        assert "auditLogs" in db
        assert isinstance(db["auditLogs"], list)

    def test_audit_log_structure(self):
        """测试审计日志结构。"""
        from server import default_db

        db = default_db()
        audit_logs = db["auditLogs"]

        for log in audit_logs:
            assert "id" in log
            assert "action" in log
            assert "createdAt" in log


class TestAccountCancellation:
    """测试账号注销功能。"""

    def test_default_db_has_cancellation_requests(self):
        """测试默认数据库包含账号注销请求表。"""
        from server import default_db

        db = default_db()
        assert "accountCancellationRequests" in db
        assert isinstance(db["accountCancellationRequests"], list)


class TestContentModeration:
    """测试内容审核功能。"""

    def test_post_review_status_values(self):
        """测试帖子审核状态值。"""
        from server import default_db

        db = default_db()
        posts = db["posts"]

        valid_statuses = {"pending", "approved", "rejected"}
        for post in posts:
            if "reviewStatus" in post:
                assert post["reviewStatus"] in valid_statuses

    def test_comment_review_status_values(self):
        """测试评论审核状态值。"""
        from server import default_db

        db = default_db()
        comments = db["comments"]

        valid_statuses = {"pending", "approved", "rejected"}
        for comment in comments:
            if "reviewStatus" in comment:
                assert comment["reviewStatus"] in valid_statuses

    def test_risk_marking(self):
        """测试风险标记。"""
        from server import default_db

        db = default_db()
        posts = db["posts"]

        for post in posts:
            if "riskMarked" in post:
                assert isinstance(post["riskMarked"], bool)


class TestReportHandling:
    """测试举报处理功能。"""

    def test_default_db_has_reports(self):
        """测试默认数据库包含举报表。"""
        from server import default_db

        db = default_db()
        assert "reports" in db
        assert isinstance(db["reports"], list)

    def test_report_structure(self):
        """测试举报结构。"""
        from server import default_db

        db = default_db()
        reports = db["reports"]

        for report in reports:
            assert "id" in report
            assert "targetType" in report
            assert "targetId" in report
            assert "reason" in report
            assert "status" in report
            assert "createdAt" in report

    def test_report_status_values(self):
        """测试举报状态值。"""
        from server import default_db

        db = default_db()
        reports = db["reports"]

        valid_statuses = {"pending", "handled", "dismissed"}
        for report in reports:
            if "status" in report:
                assert report["status"] in valid_statuses


class TestMediaModeration:
    """测试媒体审核功能。"""

    def test_default_db_has_media_uploads(self):
        """测试默认数据库包含媒体上传表。"""
        from server import default_db

        db = default_db()
        assert "mediaUploads" in db
        assert isinstance(db["mediaUploads"], list)

    def test_media_upload_structure(self):
        """测试媒体上传结构。"""
        from server import default_db

        db = default_db()
        uploads = db["mediaUploads"]

        for upload in uploads:
            assert "id" in upload
            assert "objectKey" in upload
            assert "publicUrl" in upload
            assert "uploaderId" in upload
            assert "status" in upload


class TestAdminOverviewData:
    """测试管理员概览数据。"""

    def test_default_db_has_all_required_collections(self):
        """测试默认数据库包含所有必要的数据集合。"""
        from server import default_db

        db = default_db()

        required_collections = [
            "users",
            "posts",
            "comments",
            "reports",
            "dmRequests",
            "conversations",
            "mediaUploads",
        ]

        for collection in required_collections:
            assert collection in db
            assert isinstance(db[collection], list)


class TestSettingsManagement:
    """测试设置管理功能。"""

    def test_default_settings_structure(self):
        """测试默认设置结构。"""
        from server import DEFAULT_SETTINGS

        assert isinstance(DEFAULT_SETTINGS, dict)

        # 验证必要设置
        assert "postRateLimit" in DEFAULT_SETTINGS
        assert "commentRateLimit" in DEFAULT_SETTINGS
        assert "messageRateLimit" in DEFAULT_SETTINGS
        assert "imageMaxMB" in DEFAULT_SETTINGS
        assert "reportRateLimit" in DEFAULT_SETTINGS
        assert "dmRequestRateLimit" in DEFAULT_SETTINGS

    def test_sensitive_words_default(self):
        """测试默认敏感词。"""
        from server import DEFAULT_SENSITIVE_WORDS, default_db

        assert isinstance(DEFAULT_SENSITIVE_WORDS, list)
        assert len(DEFAULT_SENSITIVE_WORDS) > 0

        db = default_db()
        assert "sensitiveWords" in db
        assert isinstance(db["sensitiveWords"], list)
