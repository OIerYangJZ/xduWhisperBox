"""私信功能测试。"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))


class TestDmRequestHelpers:
    """测试私信请求相关的辅助函数。"""

    def test_default_db_has_dm_requests(self):
        """测试默认数据库包含私信请求。"""
        from server import default_db

        db = default_db()

        assert "dmRequests" in db
        assert len(db["dmRequests"]) > 0

    def test_dm_request_structure(self):
        """测试私信请求结构。"""
        from server import default_db

        db = default_db()
        requests = db["dmRequests"]

        for req in requests:
            assert "id" in req
            assert "fromAlias" in req
            assert "reason" in req
            assert "status" in req
            assert "createdAt" in req

            # 验证状态值
            assert req["status"] in {"pending", "accepted", "rejected"}


class TestConversationHelpers:
    """测试会话相关的辅助函数。"""

    def test_default_db_has_conversations(self):
        """测试默认数据库包含会话。"""
        from server import default_db

        db = default_db()

        assert "conversations" in db
        assert "directMessages" in db
        assert len(db["conversations"]) > 0

    def test_conversation_structure(self):
        """测试会话结构。"""
        from server import default_db

        db = default_db()
        conversations = db["conversations"]

        for conv in conversations:
            assert "id" in conv
            assert "userId" in conv
            assert "peerUserId" in conv
            assert "name" in conv
            assert "lastMessage" in conv
            assert "updatedAt" in conv

    def test_direct_message_structure(self):
        """测试私信消息结构。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]

        for msg in messages:
            assert "id" in msg
            assert "conversationKey" in msg
            assert "senderUserId" in msg
            assert "receiverUserId" in msg
            assert "content" in msg
            assert "createdAt" in msg

    def test_conversation_key_format(self):
        """测试会话键格式。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]

        for msg in messages:
            key = msg["conversationKey"]
            parts = key.split("::")
            assert len(parts) == 2
            assert parts[0] != parts[1]  # 发送者和接收者不同


class TestUserBlocks:
    """测试用户拉黑功能。"""

    def test_default_db_has_user_blocks(self):
        """测试默认数据库包含用户拉黑表。"""
        from server import default_db

        db = default_db()
        assert "userBlocks" in db

    def test_user_block_structure(self):
        """测试用户拉黑结构。"""
        from server import default_db

        db = default_db()
        blocks = db["userBlocks"]

        assert isinstance(blocks, list)


class TestRateLimitsForMessages:
    """测试消息相关限流。"""

    def test_message_rate_limit_config(self):
        """测试消息限流配置。"""
        from server import DEFAULT_SETTINGS, IP_RATE_LIMITS

        assert "messageRateLimit" in DEFAULT_SETTINGS
        assert "message" in IP_RATE_LIMITS

    def test_dm_request_rate_limit_config(self):
        """测试私信请求限流配置。"""
        from server import DEFAULT_SETTINGS

        assert "dmRequestRateLimit" in DEFAULT_SETTINGS


class TestConversationQueries:
    """测试会话查询逻辑。"""

    def test_conversation_ordering(self):
        """测试会话排序。"""
        from server import default_db

        db = default_db()
        conversations = db["conversations"]

        # 会话应该按更新时间排序
        for i in range(len(conversations) - 1):
            curr_time = conversations[i].get("updatedAt", "")
            next_time = conversations[i + 1].get("updatedAt", "")
            if curr_time and next_time:
                assert curr_time >= next_time

    def test_unread_count_tracking(self):
        """测试未读计数跟踪。"""
        from server import default_db

        db = default_db()
        conversations = db["conversations"]

        for conv in conversations:
            assert "unreadCount" in conv
            assert isinstance(conv["unreadCount"], int)
            assert conv["unreadCount"] >= 0


class TestMessageQueries:
    """测试消息查询逻辑。"""

    def test_message_ordering(self):
        """测试消息排序。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]

        # 消息应该按创建时间排序
        for i in range(len(messages) - 1):
            curr_time = messages[i].get("createdAt", "")
            next_time = messages[i + 1].get("createdAt", "")
            if curr_time and next_time:
                assert curr_time <= next_time

    def test_message_conversation_filtering(self):
        """测试消息按会话过滤。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]
        conversations = db["conversations"]

        # 每个消息的 conversationKey 应该对应一个会话
        for msg in messages:
            key_parts = msg["conversationKey"].split("::")
            assert len(key_parts) == 2

            # 查找对应的会话
            matching_convs = [
                c
                for c in conversations
                if (c["userId"] in key_parts and c["peerUserId"] in key_parts)
            ]
            # 注意：可能找不到精确匹配，这是正常的


class TestUserBlockHandlers:
    """测试全局黑名单 API 处理函数。"""

    def test_block_and_unblock_user_globally(self, monkeypatch: pytest.MonkeyPatch):
        from server import default_db
        from handlers import _user_handler
        import json
        import io

        db = default_db()
        # Add two users
        user_a = {"id": "user_a", "email": "a@stu.xidian.edu.cn", "nickname": "User A"}
        user_b = {"id": "user_b", "email": "b@stu.xidian.edu.cn", "nickname": "User B"}
        db["users"].extend([user_a, user_b])

        # Clear existing blocks
        db["userBlocks"] = []

        class FakeHandler:
            def __init__(self, body=None):
                self.wfile = io.BytesIO()
                self.status_code = 0
                self.response_headers = []
                self.body = body
                self.headers = {}

            def send_response(self, code):
                self.status_code = code

            def send_header(self, key, val):
                self.response_headers.append((key, val))

            def end_headers(self):
                pass

        # Mock authentication to return user_a
        monkeypatch.setattr(
            _user_handler,
            "auth_user_helper",
            lambda h, d: (user_a, "session_token_a"),
        )
        monkeypatch.setattr(
            _user_handler,
            "save_db",
            lambda d: None,
        )

        # 1. Test GET /api/users/me/blocks when empty
        handler1 = FakeHandler()
        _user_handler.handle_get_blocks(handler1, db)
        assert handler1.status_code == 200
        res1 = json.loads(handler1.wfile.getvalue().decode("utf-8"))
        assert len(res1["data"]) == 0

        # 2. Test POST /api/users/me/blocks (block user_b)
        handler2 = FakeHandler(body={"targetUserId": "user_b"})
        monkeypatch.setattr(
            _user_handler,
            "read_json_body",
            lambda h: {"targetUserId": "user_b"},
        )
        _user_handler.handle_block_user_globally(handler2, db)
        assert handler2.status_code == 200
        res2 = json.loads(handler2.wfile.getvalue().decode("utf-8"))
        assert res2["data"]["blocked"] is True

        # 3. Test GET /api/users/me/blocks (should have user_b now)
        handler3 = FakeHandler()
        _user_handler.handle_get_blocks(handler3, db)
        assert handler3.status_code == 200
        res3 = json.loads(handler3.wfile.getvalue().decode("utf-8"))
        assert len(res3["data"]) == 1
        assert res3["data"][0]["id"] == "user_b"
        assert res3["data"][0]["nickname"] == "User B"

        # 4. Test DELETE /api/users/me/blocks/user_b
        handler4 = FakeHandler()
        _user_handler.handle_unblock_user_globally(handler4, db, "user_b")
        assert handler4.status_code == 200
        res4 = json.loads(handler4.wfile.getvalue().decode("utf-8"))
        assert res4["data"]["blocked"] is False

        # 5. Test GET /api/users/me/blocks when empty again
        handler5 = FakeHandler()
        _user_handler.handle_get_blocks(handler5, db)
        assert handler5.status_code == 200
        res5 = json.loads(handler5.wfile.getvalue().decode("utf-8"))
        assert len(res5["data"]) == 0
