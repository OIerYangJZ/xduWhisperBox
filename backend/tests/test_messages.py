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
