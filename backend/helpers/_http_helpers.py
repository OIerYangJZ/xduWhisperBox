from __future__ import annotations

import io
import json
import mimetypes
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any

from helpers._datetime_helpers import now_iso


def read_json_body(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length_str = handler.headers.get("Content-Length", "0")
    try:
        length = max(0, int(length_str))
    except ValueError:
        length = 0
    body = handler.rfile.read(length) if length > 0 else b""
    if not body:
        return {}
    try:
        return json.loads(body.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return {}


def send_json(
    handler: BaseHTTPRequestHandler,
    status: HTTPStatus | int,
    data: Any,
    *,
    no_cache: bool = False,
) -> None:
    code = int(status)
    body = json.dumps(data, ensure_ascii=False)
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    if no_cache:
        handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", str(len(body.encode("utf-8"))))
    handler.end_headers()
    handler.wfile.write(body.encode("utf-8"))


def json_error(
    handler: BaseHTTPRequestHandler,
    status: HTTPStatus | int,
    message: str,
    *,
    data: Any = None,
) -> None:
    payload: dict[str, Any] = {"message": message}
    if data is not None:
        payload["data"] = data
    send_json(handler, status, payload)


def send_binary(
    handler: BaseHTTPRequestHandler,
    status: HTTPStatus | int,
    data: bytes,
    content_type: str,
    *,
    filename: str = "",
) -> None:
    code = int(status)
    handler.send_response(code)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    if filename:
        encoded_filename = filename.encode("utf-8")
        handler.send_header(
            "Content-Disposition",
            f'attachment; filename*=UTF-8\'\'{encoded_filename.decode("latin-1")}',
        )
    handler.end_headers()
    handler.wfile.write(data)


def send_static_file(
    handler: BaseHTTPRequestHandler,
    file_path: Path,
) -> None:
    try:
        data = file_path.read_bytes()
    except OSError:
        json_error(handler, HTTPStatus.NOT_FOUND, "Not Found")
        return

    content_type, _ = mimetypes.guess_type(str(file_path))
    if file_path.suffix == ".wasm":
        content_type = "application/wasm"
    if not content_type:
        content_type = "application/octet-stream"

    handler.send_response(HTTPStatus.OK)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
    # Beta deployment prefers freshness over caching to avoid stale Flutter bundles.
    handler.send_header("Cache-Control", "no-cache")
    handler.end_headers()
    handler.wfile.write(data)


def resolve_web_asset_path(path: str) -> Path | None:
    from _globals import WEB_ROOT_DIR

    raw = path or "/"
    # Remove URL-encoded characters (unquote equivalent via urllib)
    try:
        from urllib.parse import unquote
        raw = unquote(raw)
    except ImportError:
        pass
    normalized = raw.lstrip("/")
    if not normalized:
        target = WEB_ROOT_DIR / "index.html"
    else:
        target = (WEB_ROOT_DIR / normalized).resolve()
    try:
        target.relative_to(WEB_ROOT_DIR)
    except ValueError:
        return None
    if target.is_dir():
        target = target / "index.html"
    return target


def should_fallback_to_spa(path: str) -> bool:
    if not path.startswith("/"):
        return False
    if "?" in path:
        path = path.split("?")[0]
    if "." in path:
        filename = path.rsplit(".", 1)[-1].lower()
        if filename not in {"html", "htm"}:
            return True
        return False
    return True
