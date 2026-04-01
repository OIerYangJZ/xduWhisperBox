from __future__ import annotations

import base64
import hashlib
import hmac
import re
import secrets
from typing import Any
from urllib.parse import urlsplit, urlunsplit

import _globals


def decode_base64_payload(value: str) -> bytes:
    text = value.strip()
    if "," in text and "base64" in text[:64]:
        text = text.split(",", 1)[1]
    missing_padding = len(text) % 4
    if missing_padding:
        text += "=" * (4 - missing_padding)
    return base64.b64decode(text, validate=False)


def detect_image_type(data: bytes) -> str | None:
    if len(data) < 12:
        return None
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"GIF87a") or data.startswith(b"GIF89a"):
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def calc_sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(_globals.PASSWORD_SALT_BYTES)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        _globals.PASSWORD_HASH_ITERATIONS,
    )
    return (
        f"{_globals.PASSWORD_HASH_SCHEME}"
        f"${_globals.PASSWORD_HASH_ITERATIONS}"
        f"${salt.hex()}"
        f"${digest.hex()}"
    )


def verify_password(stored: str | None, candidate: str) -> bool:
    if not stored:
        return False
    if not is_password_hashed(stored):
        return hmac.compare_digest(stored, candidate)
    parts = stored.split("$")
    if len(parts) != 4 or parts[0] != _globals.PASSWORD_HASH_SCHEME:
        return False
    try:
        iterations = int(parts[1])
        salt = bytes.fromhex(parts[2])
        expected = bytes.fromhex(parts[3])
    except (TypeError, ValueError):
        return False
    actual = hashlib.pbkdf2_hmac(
        "sha256",
        candidate.encode("utf-8"),
        salt,
        iterations,
    )
    return hmac.compare_digest(actual, expected)


def is_password_hashed(value: str | None) -> bool:
    if not value:
        return False
    parts = value.split("$")
    return len(parts) == 4 and parts[0] == _globals.PASSWORD_HASH_SCHEME


def is_valid_student_id(student_id: str) -> bool:
    return bool(re.fullmatch(r"[0-9A-Za-z]{6,20}", student_id.strip()))


def is_campus_email(email: str) -> bool:
    lower = email.lower().strip()
    return lower.endswith("@stu.xidian.edu.cn") or lower.endswith("@xidian.edu.cn")


def student_id_from_email(email: str) -> str:
    local = email.strip().split("@", 1)[0]
    return local.strip()


def sanitize_alias(value: str, *, fallback: str = "匿名同学") -> str:
    text = " ".join(value.strip().split())
    if not text:
        return fallback
    if len(text) > 24:
        return text[:24]
    return text


def normalize_avatar_url(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    lowered = text.lower()
    if lowered.startswith("/api/storage/") or lowered.startswith("http://") or lowered.startswith("https://"):
        return text
    return ""


def normalize_media_url(value: str) -> str:
    text = value.strip()
    if not text:
        return ""

    lowered = text.lower()
    if lowered.startswith("/api/storage/"):
        return text
    if lowered.startswith("api/storage/"):
        return f"/{text.lstrip('/')}"
    if lowered.startswith("//"):
        return text

    if lowered.startswith("http://") or lowered.startswith("https://"):
        try:
            parsed = urlsplit(text)
        except ValueError:
            return ""
        host = (parsed.hostname or "").strip().lower()
        if host in {"localhost", "127.0.0.1", "0.0.0.0", "::1"}:
            marker = "/api/storage/"
            path_lowered = parsed.path.lower()
            idx = path_lowered.find(marker)
            if idx >= 0:
                normalized_path = parsed.path[idx:]
                if not normalized_path.startswith("/api/storage/"):
                    normalized_path = marker + normalized_path.lstrip("/")
                return urlunsplit(("", "", normalized_path, parsed.query, ""))
        return text

    clean_text = text.lstrip("/")
    if not clean_text or ".." in clean_text:
        return ""
    return f"/api/storage/{clean_text}"


def extract_local_object_key_from_url(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    marker = "/api/storage/"
    idx = text.find(marker)
    if idx < 0:
        return ""
    key = text[idx + len(marker):].strip().lstrip("/")
    if not key or ".." in key:
        return ""
    return key


def parse_bool(value: str | None) -> bool | None:
    if value is None:
        return None
    lowered = value.strip().lower()
    if lowered in {"1", "true", "yes"}:
        return True
    if lowered in {"0", "false", "no"}:
        return False
    return None


def parse_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(x).strip() for x in value if str(x).strip()]
    if isinstance(value, str):
        return [x.strip() for x in value.split(",") if x.strip()]
    return []


def random_code() -> str:
    import random
    return "".join(random.choice("0123456789") for _ in range(6))


# Re-export password constants from _globals for the helpers/__init__.py barrel export
def __getattr__(name: str) -> Any:
    if name == "PASSWORD_HASH_SCHEME":
        return _globals.PASSWORD_HASH_SCHEME
    if name == "PASSWORD_SALT_BYTES":
        return _globals.PASSWORD_SALT_BYTES
    if name == "PASSWORD_HASH_ITERATIONS":
        return _globals.PASSWORD_HASH_ITERATIONS
    if name == "auth_user":
        return _globals.auth_user
    raise AttributeError(f"module '_auth_helpers' has no attribute '{name}'")
