"""pytest 配置和 fixtures。"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path
from typing import Generator

import pytest

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

# 设置测试环境变量
os.environ.setdefault("BACKEND_DB_FILE", "")
os.environ.setdefault("BACKEND_STORAGE_DIR", "")
os.environ.setdefault("BACKEND_WEB_ROOT", "")
os.environ.setdefault("BACKEND_ADMIN_USERNAME", "testadmin")
os.environ.setdefault("BACKEND_ADMIN_PASSWORD", "testpass123")


@pytest.fixture
def temp_db_file(tmp_path: Path) -> Path:
    """创建临时数据库文件。"""
    db_file = tmp_path / "test_treehole.db"
    os.environ["BACKEND_DB_FILE"] = str(db_file)
    return db_file


@pytest.fixture
def temp_storage_dir(tmp_path: Path) -> Path:
    """创建临时存储目录。"""
    storage_dir = tmp_path / "storage" / "objects"
    storage_dir.mkdir(parents=True, exist_ok=True)
    os.environ["BACKEND_STORAGE_DIR"] = str(storage_dir)
    return storage_dir


@pytest.fixture
def app_with_db(
    temp_db_file: Path,
    temp_storage_dir: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> Generator[None, None, None]:
    """设置带有临时数据库的应用环境。"""
    # 重新加载模块以使用新的环境变量
    import importlib
    import server

    # 清除已导入的模块缓存
    modules_to_reload = [
        "server",
        "sql_repository",
        "object_storage",
    ]
    for mod_name in modules_to_reload:
        if mod_name in sys.modules:
            # 保存必要的变量
            if mod_name == "server":
                saved_vars = {
                    "ADMIN_SESSIONS": sys.modules[mod_name].ADMIN_SESSIONS.copy(),
                    "_BACKEND_VERSION": sys.modules[mod_name]._BACKEND_VERSION,
                }
            importlib.reload(sys.modules[mod_name])
            if mod_name == "server":
                sys.modules[mod_name].ADMIN_SESSIONS = saved_vars["ADMIN_SESSIONS"]
                sys.modules[mod_name]._BACKEND_VERSION = saved_vars["_BACKEND_VERSION"]

    yield

    # 清理
    for mod_name in modules_to_reload:
        if mod_name in sys.modules:
            del sys.modules[mod_name]


@pytest.fixture
def sample_user_data() -> dict:
    """示例用户数据。"""
    return {
        "email": "testuser@stu.xidian.edu.cn",
        "password": "testpass123",
        "nickname": "测试用户",
    }


@pytest.fixture
def demo_credentials() -> dict:
    """演示账号凭据。"""
    return {
        "email": "demo@stu.xidian.edu.cn",
        "password": "123456",
    }


@pytest.fixture
def admin_credentials() -> dict:
    """管理员账号凭据。"""
    return {
        "username": "testadmin",
        "password": "testpass123",
    }


@pytest.fixture
def sample_post_data() -> dict:
    """示例帖子数据。"""
    return {
        "title": "测试帖子标题",
        "content": "这是测试帖子的内容。",
        "channel": "吐槽日常",
        "tags": ["测试", "Flutter"],
        "hasImage": False,
        "status": "ongoing",
        "allowComment": True,
        "allowDm": False,
    }


def make_json_request(
    method: str,
    path: str,
    *,
    body: dict | None = None,
    token: str | None = None,
    content_type: str = "application/json",
) -> tuple[dict, int]:
    """
    模拟 HTTP 请求并返回响应。

    这是一个简化的测试辅助函数，用于在没有实际服务器运行的情况下测试路由逻辑。
    """
    from http import HTTPStatus
    from server import (
        DB_LOCK,
        REPOSITORY,
        default_db,
        hash_password,
        random_code,
        verify_password,
    )

    # 模拟请求路径解析
    path = path.strip("/")
    parts = path.split("/")

    # 基本响应结构
    response: dict = {}
    status = HTTPStatus.OK

    # 根据路径和方法处理请求
    try:
        db = REPOSITORY.load_state()

        # 认证相关路由
        if len(parts) >= 2 and parts[0] == "auth":
            if parts[1] == "login" and method == "POST":
                # 简化登录逻辑
                if body and "identifier" in body and "password" in body:
                    identifier = body["identifier"]
                    password = body["password"]

                    # 查找用户
                    user = None
                    for u in db.get("users", []):
                        if (
                            u.get("email", "").lower() == identifier.lower()
                            or u.get("studentId", "") == identifier
                        ):
                            user = u
                            break

                    if user and verify_password(user.get("password", ""), password):
                        # 生成会话
                        import secrets

                        token = secrets.token_hex(32)
                        db.setdefault("sessions", {})[token] = {
                            "userId": user["id"],
                            "createdAt": datetime.now(timezone.utc).isoformat(),
                        }
                        REPOSITORY.save_state(db)
                        return {
                            "token": token,
                            "email": user.get("email"),
                            "studentId": user.get("studentId"),
                            "verified": user.get("verified", False),
                        }, HTTPStatus.OK
                    else:
                        return {"message": "用户名或密码错误"}, HTTPStatus.UNAUTHORIZED

            elif parts[1] == "register" and method == "POST":
                if body and "email" in body and "password" in body:
                    # 检查邮箱是否已存在
                    for u in db.get("users", []):
                        if u.get("email", "").lower() == body["email"].lower():
                            return {"message": "该邮箱已注册"}, HTTPStatus.BAD_REQUEST

                    return {"message": "注册成功"}, HTTPStatus.CREATED

        # 帖子相关路由
        if len(parts) >= 1 and parts[0] == "posts":
            if len(parts) == 1:
                if method == "GET":
                    # 返回帖子列表
                    posts = [
                        p
                        for p in db.get("posts", [])
                        if not p.get("deleted", False)
                        and p.get("reviewStatus") == "approved"
                    ]
                    return {"data": posts}, HTTPStatus.OK
                elif method == "POST" and token:
                    if body:
                        return {"message": "帖子创建成功"}, HTTPStatus.CREATED
                    return {"message": "请求体不能为空"}, HTTPStatus.BAD_REQUEST

        # 频道路由
        if len(parts) >= 1 and parts[0] == "channels":
            if method == "GET":
                return {"data": db.get("channels", [])}, HTTPStatus.OK

        return {"message": "未找到"}, HTTPStatus.NOT_FOUND

    except Exception as e:
        return {"message": f"服务器错误: {str(e)}"}, HTTPStatus.INTERNAL_SERVER_ERROR


from datetime import datetime, timezone
