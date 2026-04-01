"""帖子 CRUD 测试。"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))


class TestPostHelpers:
    """测试帖子相关的辅助函数。"""

    def test_default_channels(self):
        """测试默认频道列表。"""
        from server import DEFAULT_CHANNELS

        assert len(DEFAULT_CHANNELS) > 0
        assert "吐槽日常" in DEFAULT_CHANNELS
        assert "求助问答" in DEFAULT_CHANNELS
        assert "二手交易" in DEFAULT_CHANNELS

    def test_default_tags(self):
        """测试默认标签列表。"""
        from server import DEFAULT_TAGS

        assert len(DEFAULT_TAGS) > 0
        assert "学习" in DEFAULT_TAGS
        assert "北校区" in DEFAULT_TAGS
        assert "南校区" in DEFAULT_TAGS

    def test_seed_posts_structure(self):
        """测试种子帖子结构。"""
        from server import SEED_POSTS

        for post in SEED_POSTS:
            assert "title" in post
            assert "content" in post
            assert "channel" in post
            assert "tags" in post
            assert "hasImage" in post
            assert "status" in post
            assert "allowComment" in post
            assert "allowDm" in post
            assert "authorAlias" in post
            assert "authorId" in post

            # 验证值类型
            assert isinstance(post["title"], str)
            assert isinstance(post["tags"], list)
            assert isinstance(post["hasImage"], bool)

    def test_seed_posts_valid_channels(self):
        """测试种子帖子的频道有效性。"""
        from server import SEED_POSTS, DEFAULT_CHANNELS

        for post in SEED_POSTS:
            assert post["channel"] in DEFAULT_CHANNELS

    def test_post_status_values(self):
        """测试帖子状态值。"""
        from server import SEED_POSTS

        valid_statuses = {"ongoing", "resolved", "closed"}
        for post in SEED_POSTS:
            assert post["status"] in valid_statuses


class TestImageProcessing:
    """测试图片处理功能。"""

    def test_detect_image_type_png(self):
        """测试 PNG 图片类型检测。"""
        from server import detect_image_type

        png_data = b"\x89PNG\r\n\x1a\n" + b"\x00" * 12
        assert detect_image_type(png_data) == "image/png"

    def test_detect_image_type_jpeg(self):
        """测试 JPEG 图片类型检测。"""
        from server import detect_image_type

        jpeg_data = b"\xff\xd8\xff\xe0" + b"\x00" * 12
        assert detect_image_type(jpeg_data) == "image/jpeg"

    def test_detect_image_type_gif(self):
        """测试 GIF 图片类型检测。"""
        from server import detect_image_type

        gif87_data = b"GIF87a" + b"\x00" * 6
        gif89_data = b"GIF89a" + b"\x00" * 6
        assert detect_image_type(gif87_data) == "image/gif"
        assert detect_image_type(gif89_data) == "image/gif"

    def test_detect_image_type_webp(self):
        """测试 WebP 图片类型检测。"""
        from server import detect_image_type

        webp_data = b"RIFF" + b"\x00\x00\x00\x00" + b"WEBP"
        assert detect_image_type(webp_data) == "image/webp"

    def test_detect_image_type_unknown(self):
        """测试未知图片类型。"""
        from server import detect_image_type

        assert detect_image_type(b"\x00\x00\x00\x00") is None
        assert detect_image_type(b"") is None
        assert detect_image_type(b"not an image") is None

    def test_decode_base64_payload(self):
        """测试 Base64 解码。"""
        from server import decode_base64_payload

        # 标准 Base64
        data = decode_base64_payload("SGVsbG8gV29ybGQ=")  # "Hello World"
        assert data == b"Hello World"

        # 带前缀的 Base64 (data URI)
        data = decode_base64_payload("data:text/plain;base64,SGVsbG8=")
        assert data == b"Hello"

    def test_calc_sha256_hex(self):
        """测试 SHA256 哈希计算。"""
        from server import calc_sha256_hex

        hash1 = calc_sha256_hex(b"test")
        hash2 = calc_sha256_hex(b"test")
        hash3 = calc_sha256_hex(b"different")

        # 相同输入产生相同输出
        assert hash1 == hash2

        # 不同输入产生不同输出
        assert hash1 != hash3

        # 验证是有效的十六进制字符串
        assert len(hash1) == 64
        assert all(c in "0123456789abcdef" for c in hash1)


class TestRateLimit:
    """测试限流功能。"""

    def test_rate_limit_settings(self):
        """测试限流设置。"""
        from server import DEFAULT_SETTINGS, RATE_LIMIT_WINDOWS_SECONDS

        assert "postRateLimit" in DEFAULT_SETTINGS
        assert "commentRateLimit" in DEFAULT_SETTINGS
        assert "messageRateLimit" in DEFAULT_SETTINGS
        assert "imageMaxMB" in DEFAULT_SETTINGS

        # 验证限流窗口配置
        assert "post" in RATE_LIMIT_WINDOWS_SECONDS
        assert "comment" in RATE_LIMIT_WINDOWS_SECONDS
        assert RATE_LIMIT_WINDOWS_SECONDS["post"] == 3600

    def test_ip_rate_limit_config(self):
        """测试 IP 限流配置。"""
        from server import IP_RATE_LIMITS

        assert "post" in IP_RATE_LIMITS
        assert "comment" in IP_RATE_LIMITS
        assert "upload" in IP_RATE_LIMITS

        for action, config in IP_RATE_LIMITS.items():
            assert "limit" in config
            assert "window" in config
            assert config["limit"] > 0
            assert config["window"] > 0


class TestSettings:
    """测试设置管理功能。"""

    def test_get_setting_int(self):
        """测试整数设置获取。"""
        from server import get_setting_int

        db = {"settings": {"postRateLimit": 10}}
        result = get_setting_int(db, "postRateLimit", 5)
        assert result == 10

        # 默认值
        result = get_setting_int(db, "nonexistent", 3)
        assert result == 3

        # 最小值限制
        result = get_setting_int(db, "postRateLimit", 0, minimum=1)
        assert result >= 1

    def test_admin_auth_settings(self):
        """测试管理员认证设置。"""
        from server import (
            DEFAULT_ADMIN_PASSWORD,
            DEFAULT_ADMIN_USERNAME,
            ensure_admin_auth_settings,
        )

        db: dict = {}
        changed = ensure_admin_auth_settings(db)

        assert changed is True
        assert "settings" in db
        assert "adminUsername" in db["settings"]
        assert db["settings"]["adminUsername"] == DEFAULT_ADMIN_USERNAME

    def test_get_admin_auth_credentials(self):
        """测试获取管理员认证凭据。"""
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

        # 验证密码可以验证
        from server import verify_password

        assert verify_password(password_hash, DEFAULT_ADMIN_PASSWORD) is True


class TestSpamDetection:
    """测试垃圾内容检测。"""

    def test_spam_repeat_regex(self):
        """测试重复字符正则表达式。"""
        from server import SPAM_REPEAT_REGEX

        # 应该匹配超过 8 个重复字符
        assert SPAM_REPEAT_REGEX.search("aaaaaaaaaa") is not None
        assert SPAM_REPEAT_REGEX.search("aaaaaaaaab") is not None
        assert SPAM_REPEAT_REGEX.search("abcdefghi") is None
        assert SPAM_REPEAT_REGEX.search("aaaaaaaab") is None  # 只有 7 个 a

    def test_duplicate_image_hash_check(self):
        """测试重复图片哈希检查。"""
        from server import check_duplicate_image_hash

        db = {
            "mediaUploads": [
                {"hash": "abc123"},
                {"hash": "def456"},
            ]
        }

        assert check_duplicate_image_hash(db, "abc123") is True
        assert check_duplicate_image_hash(db, "xyz789") is False
        assert check_duplicate_image_hash(db, "") is False


class TestEmailValidation:
    """测试邮件验证功能。"""

    def test_is_email_not_found_error(self):
        """测试邮箱不存在错误检测。"""
        import smtplib

        from server import is_email_not_found_error

        # SMTP 拒绝错误
        error1 = smtplib.SMTPRecipientsRefused("test@example.com")
        assert is_email_not_found_error(error1) is True

    def test_smtp_configured(self):
        """测试 SMTP 配置检查。"""
        from server import smtp_configured

        # 默认不配置 SMTP
        assert smtp_configured() is False

    def test_verify_code_debug_enabled(self):
        """测试验证码调试模式。"""
        from server import ALLOW_DEBUG_VERIFY_CODE, verify_code_debug_enabled

        # 未配置 SMTP 且未启用调试时，应该启用调试模式
        expected = ALLOW_DEBUG_VERIFY_CODE or not (
            __import__("server", fromlist=["smtp_configured"]).smtp_configured()
        )
        assert verify_code_debug_enabled() == expected
