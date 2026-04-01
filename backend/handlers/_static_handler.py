"""
handlers/_static_handler.py

Static file / asset serving:
  GET /api/storage/<object_key>   — object storage (avatars, post images)
  GET /<fallback>                — SPA index.html for unmatched GET paths
"""
from __future__ import annotations

import re
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    resolve_web_asset_path,
    send_binary,
    send_static_file,
    should_fallback_to_spa,
)


def handle_storage_get(
    handler: BaseHTTPRequestHandler,
    path: str,
) -> bool:
    """
    Handle GET /api/storage/<object_key>.
    Returns True if this path was handled, False otherwise.
    """
    prefix = "/api/storage/"
    if not path.startswith(prefix):
        return False

    object_key = path[len(prefix):].strip("/")
    if not object_key:
        return False

    try:
        result = _globals.OBJECT_STORAGE.get_bytes(object_key)
    except ValueError:
        return False
    if result is None:
        return False

    data, content_type = result
    send_binary(handler, HTTPStatus.OK, data, content_type)
    return True


def handle_web_fallback_get(
    handler: BaseHTTPRequestHandler,
    path: str,
) -> bool:
    """
    Serve index.html for any unmatched GET path that should fall back to SPA.
    Returns True if this path was handled, False otherwise.
    """
    if not should_fallback_to_spa(path):
        return False

    asset_path = resolve_web_asset_path(path)
    send_static_file(handler, asset_path, fallback_to_index=True)
    return True
