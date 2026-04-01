"""认证接口测试。"""
from __future__ import annotations

import re
import subprocess
import sys
from http import HTTPStatus
from pathlib import Path
from typing import Any

import pytest

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))


class TestAuthHelpers:
    """测试认证相关的辅助函数。"""

    def test_is_campus_email_valid(self):
        """测试校园邮箱验证 - 有效邮箱。"""
        from server import is_campus_email

        assert is_campus_email("student@stu.xidian.edu.cn") is True
        assert is_campus_email("teacher@xidian.edu.cn") is True
        assert is_campus_email("STUDENT@Stu.Xidian.EDU.CN") is True

    def test_is_campus_email_invalid(self):
        """测试校园邮箱验证 - 无效邮箱。"""
        from server import is_campus_email

        assert is_campus_email("student@gmail.com") is False
        assert is_campus_email("student@qq.com") is False
        assert is_campus_email("notanemail") is False
        assert is_campus_email("") is False

    def test_hash_password(self):
        """测试密码哈希。"""
        from server import hash_password, is_password_hashed, verify_password

        password = "test_password_123"
        hashed = hash_password(password)

        # 验证哈希格式
        assert is_password_hashed(hashed) is True
        assert hashed.startswith("pbkdf2_sha256$")

        # 验证密码匹配
        assert verify_password(hashed, password) is True
        assert verify_password(hashed, "wrong_password") is False

    def test_hash_password_different_hashes(self):
        """测试相同密码生成不同哈希（salt）。"""
        from server import hash_password

        password = "same_password"
        hash1 = hash_password(password)
        hash2 = hash_password(password)

        # 相同密码应该生成不同的哈希（因为 salt 不同）
        assert hash1 != hash2

        # 但两个哈希都应该能验证原始密码
        from server import verify_password

        assert verify_password(hash1, password) is True
        assert verify_password(hash2, password) is True

    def test_random_code_length(self):
        """测试随机验证码长度。"""
        from server import random_code

        code = random_code()
        assert len(code) == 6
        assert code.isdigit() is True

    def test_random_code_uniqueness(self):
        """测试随机验证码唯一性。"""
        from server import random_code

        codes = [random_code() for _ in range(100)]
        # 允许极少数碰撞，但大多数应该唯一
        assert len(set(codes)) > 90

    def test_student_id_from_email(self):
        """测试从邮箱提取学号。"""
        from server import student_id_from_email

        assert student_id_from_email("2111111@stu.xidian.edu.cn") == "2111111"
        assert student_id_from_email("2023000001@xidian.edu.cn") == "2023000001"

    def test_is_valid_student_id(self):
        """测试学号格式验证。"""
        from server import is_valid_student_id

        # 有效学号
        assert is_valid_student_id("2111111") is True
        assert is_valid_student_id("2023001") is True
        assert is_valid_student_id("ABC12345") is True

        # 无效学号
        assert is_valid_student_id("12345") is False  # 太短
        assert is_valid_student_id("") is False  # 为空
        assert is_valid_student_id("abc") is False  # 太短

    def test_sanitize_alias(self):
        """测试昵称清理。"""
        from server import sanitize_alias

        # 基本测试
        assert sanitize_alias("正常昵称") == "正常昵称"
        assert sanitize_alias("  带空格  ") == "带空格"
        assert sanitize_alias("") == "匿名同学"
        assert sanitize_alias("   ") == "匿名同学"

        # 长度限制
        long_name = "a" * 30
        result = sanitize_alias(long_name)
        assert len(result) <= 24

    def test_normalize_avatar_url(self):
        """测试头像 URL 规范化。"""
        from server import normalize_avatar_url

        # 有效的存储路径
        assert normalize_avatar_url("/api/storage/avatar.png") == "/api/storage/avatar.png"

        # 有效的 HTTP URL
        assert normalize_avatar_url("https://example.com/avatar.png") == "https://example.com/avatar.png"

        # 无效值
        assert normalize_avatar_url("") == ""
        assert normalize_avatar_url("invalid") == ""


class TestPasswordReset:
    """测试密码重置相关功能。"""

    def test_password_reset_code_key(self):
        """测试密码重置验证码键生成。"""
        from server import password_reset_code_key

        key = password_reset_code_key("Test@Stu.Xidian.EDU.CN")
        assert key.startswith("reset::")
        # 应该被规范化为小写
        assert "test@" in key

    def test_parse_bool(self):
        """测试布尔值解析。"""
        from server import parse_bool

        # 有效值
        assert parse_bool("true") is True
        assert parse_bool("True") is True
        assert parse_bool("1") is True
        assert parse_bool("yes") is True

        assert parse_bool("false") is False
        assert parse_bool("0") is False
        assert parse_bool("no") is False

        # 无效值
        assert parse_bool("invalid") is None
        assert parse_bool(None) is None

    def test_parse_list(self):
        """测试列表解析。"""
        from server import parse_list

        # 字符串转列表
        assert parse_list("a,b,c") == ["a", "b", "c"]
        assert parse_list("a, b, c") == ["a", "b", "c"]

        # 已经是列表
        assert parse_list(["a", "b", "c"]) == ["a", "b", "c"]

        # 空值
        assert parse_list("") == []
        assert parse_list(None) == []


class TestTextValidation:
    """测试文本验证功能。"""

    def test_assess_text_risk_empty(self):
        """测试空文本风险评估。"""
        from server import assess_text_risk

        risk_marked, high_risk, reasons = assess_text_risk({}, "")
        assert risk_marked is False
        assert high_risk is False
        assert reasons == []

    def test_assess_text_risk_sensitive_words(self):
        """测试敏感词检测。"""
        from server import assess_text_risk

        db = {"sensitiveWords": ["广告", "诈骗"]}
        risk_marked, high_risk, reasons = assess_text_risk(db, "这是广告内容")

        assert risk_marked is True
        assert len(reasons) > 0
        assert any("敏感词" in r for r in reasons)

    def test_assess_text_risk_repeat_spam(self):
        """测试重复刷屏检测。"""
        from server import assess_text_risk

        risk_marked, high_risk, reasons = assess_text_risk({}, "aaaaaaaabbbbbbbbccccccccc")
        assert risk_marked is True
        assert any("刷屏" in r for r in reasons)

    def test_assess_text_risk_too_long(self):
        """测试超长文本检测。"""
        from server import assess_text_risk

        long_text = "a" * 5001
        risk_marked, high_risk, reasons = assess_text_risk({}, long_text)

        assert risk_marked is True
        assert any("长度" in r for r in reasons)


class TestTimeUtilities:
    """测试时间工具函数。"""

    def test_now_iso(self):
        """测试 ISO 时间生成。"""
        from server import now_iso

        iso = now_iso()
        assert "T" in iso  # ISO 格式包含 T
        assert "Z" in iso or "+" in iso  # UTC 偏移

    def test_parse_iso(self):
        """测试 ISO 时间解析。"""
        from server import parse_iso

        dt = parse_iso("2024-01-15T10:30:00+00:00")
        assert dt is not None
        assert dt.year == 2024
        assert dt.month == 1
        assert dt.day == 15

        # 无效格式
        assert parse_iso(None) is None
        assert parse_iso("invalid") is None


class TestDatabaseMigration:
    """测试数据库迁移功能。"""

    def test_default_db_structure(self):
        """测试默认数据库结构。"""
        from server import default_db

        db = default_db()

        # 检查必要字段
        assert "users" in db
        assert "posts" in db
        assert "channels" in db
        assert "tags" in db
        assert "sessions" in db
        assert "settings" in db

    def test_default_db_demo_user(self):
        """测试默认演示用户。"""
        from server import default_db, DEMO_USER_EMAIL, DEMO_USER_ID

        db = default_db()

        # 查找演示用户
        demo_user = None
        for user in db.get("users", []):
            if user.get("id") == DEMO_USER_ID:
                demo_user = user
                break

        assert demo_user is not None
        assert demo_user["email"] == DEMO_USER_EMAIL
        assert demo_user["verified"] is True

    def test_default_db_seed_posts(self):
        """测试默认种子帖子。"""
        from server import default_db, SEED_POSTS

        db = default_db()
        posts = db.get("posts", [])

        assert len(posts) == len(SEED_POSTS)

        # 验证帖子结构
        for post in posts:
            assert "id" in post
            assert "title" in post
            assert "content" in post
            assert "channel" in post
            assert "authorId" in post


class TestVersionInfo:
    """测试版本信息功能。"""

    def test_get_version_info(self):
        """测试版本信息获取。"""
        from server import _get_version_info

        info = _get_version_info()

        assert "version" in info
        assert "backendVersion" in info
        assert "gitHash" in info
        assert "buildDate" in info
        assert "timestamp" in info

    def test_version_format(self):
        """测试版本号格式。"""
        from server import _get_version_info

        info = _get_version_info()
        assert "XduTreeholeBackend" in info["version"]
        assert info["backendVersion"] == "0.2"
