from __future__ import annotations

import mimetypes
import os
import secrets
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol


@dataclass(frozen=True)
class StoredObject:
    key: str
    url: str
    size_bytes: int


class ObjectStorage(Protocol):
    backend_name: str

    def put_bytes(self, *, data: bytes, file_name: str, content_type: str) -> StoredObject:
        raise NotImplementedError

    def get_bytes(self, key: str) -> tuple[bytes, str] | None:
        raise NotImplementedError

    def delete(self, key: str) -> None:
        raise NotImplementedError

    def describe(self) -> str:
        raise NotImplementedError


class LocalObjectStorage:
    backend_name = "local"

    def __init__(self, *, root_dir: Path, public_prefix: str = "/api/storage") -> None:
        self.root_dir = root_dir
        self.public_prefix = public_prefix.rstrip("/")
        self.root_dir.mkdir(parents=True, exist_ok=True)

    def put_bytes(self, *, data: bytes, file_name: str, content_type: str) -> StoredObject:
        suffix = self._guess_suffix(file_name=file_name, content_type=content_type)
        folder = secrets.token_hex(2)
        key = f"{folder}/{secrets.token_hex(16)}{suffix}"
        path = self._safe_path_from_key(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return StoredObject(
            key=key,
            url=f"{self.public_prefix}/{key}",
            size_bytes=len(data),
        )

    def get_bytes(self, key: str) -> tuple[bytes, str] | None:
        path = self._safe_path_from_key(key)
        if not path.exists() or not path.is_file():
            return None
        guessed_type, _ = mimetypes.guess_type(path.name)
        content_type = guessed_type or "application/octet-stream"
        return path.read_bytes(), content_type

    def delete(self, key: str) -> None:
        path = self._safe_path_from_key(key)
        if path.exists():
            path.unlink()
            self._cleanup_empty_parents(path.parent)

    def _safe_path_from_key(self, key: str) -> Path:
        cleaned = key.strip().replace("\\", "/")
        if cleaned.startswith("/") or ".." in cleaned.split("/"):
            raise ValueError("Invalid object key")
        full = (self.root_dir / cleaned).resolve()
        if not str(full).startswith(str(self.root_dir.resolve())):
            raise ValueError("Invalid object key")
        return full

    def _cleanup_empty_parents(self, directory: Path) -> None:
        root = self.root_dir.resolve()
        current = directory.resolve()
        while current != root:
            try:
                current.rmdir()
            except OSError:
                break
            current = current.parent

    def _guess_suffix(self, *, file_name: str, content_type: str) -> str:
        by_type = mimetypes.guess_extension(content_type.lower().strip() or "")
        if by_type:
            return by_type
        by_name = Path(file_name).suffix.strip()
        if by_name and len(by_name) <= 10:
            if by_name.startswith("."):
                return by_name.lower()
            return f".{by_name.lower()}"
        return ".bin"

    def describe(self) -> str:
        return f"local(root={self.root_dir}, public_prefix={self.public_prefix})"


class S3ObjectStorage:
    backend_name = "s3"

    def __init__(
        self,
        *,
        bucket: str,
        prefix: str = "",
        region: str = "",
        endpoint_url: str | None = None,
        access_key_id: str | None = None,
        secret_access_key: str | None = None,
        session_token: str | None = None,
        public_base_url: str | None = None,
    ) -> None:
        try:
            import boto3
            from botocore.config import Config
        except Exception as exc:  # pragma: no cover - runtime guard
            raise RuntimeError(
                "S3 backend requires boto3. Install with: pip install boto3"
            ) from exc

        self.bucket = bucket
        self.prefix = prefix.strip().strip("/")
        self.region = region.strip()
        self.endpoint_url = endpoint_url.strip().rstrip("/") if endpoint_url else None
        self.public_base_url = public_base_url.strip().rstrip("/") if public_base_url else None

        config = Config(
            s3={
                "addressing_style": os.environ.get("BACKEND_S3_ADDRESSING_STYLE", "auto"),
            }
        )
        self._client = boto3.client(
            "s3",
            endpoint_url=self.endpoint_url,
            region_name=self.region or None,
            aws_access_key_id=access_key_id or None,
            aws_secret_access_key=secret_access_key or None,
            aws_session_token=session_token or None,
            config=config,
        )

    def put_bytes(self, *, data: bytes, file_name: str, content_type: str) -> StoredObject:
        suffix = self._guess_suffix(file_name=file_name, content_type=content_type)
        folder = secrets.token_hex(2)
        object_name = f"{folder}/{secrets.token_hex(16)}{suffix}"
        key = f"{self.prefix}/{object_name}" if self.prefix else object_name

        self._client.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=data,
            ContentType=content_type or "application/octet-stream",
        )

        return StoredObject(
            key=key,
            url=self._public_url(key),
            size_bytes=len(data),
        )

    def get_bytes(self, key: str) -> tuple[bytes, str] | None:
        clean_key = key.strip().strip("/")
        if not clean_key:
            return None
        try:
            result = self._client.get_object(Bucket=self.bucket, Key=clean_key)
            body = result.get("Body")
            if body is None:
                return None
            content_type = result.get("ContentType") or "application/octet-stream"
            return body.read(), content_type
        except Exception as exc:
            if _is_not_found_error(exc):
                return None
            raise

    def delete(self, key: str) -> None:
        clean_key = key.strip().strip("/")
        if not clean_key:
            return
        self._client.delete_object(Bucket=self.bucket, Key=clean_key)

    def describe(self) -> str:
        details = [
            f"bucket={self.bucket}",
            f"prefix={self.prefix or '-'}",
            f"endpoint={self.endpoint_url or 'aws-default'}",
            f"public_base={self.public_base_url or 'endpoint/bucket'}",
        ]
        return f"s3({', '.join(details)})"

    def _public_url(self, key: str) -> str:
        if self.public_base_url:
            return f"{self.public_base_url}/{key}"
        if self.endpoint_url:
            return f"{self.endpoint_url}/{self.bucket}/{key}"
        if self.region:
            return f"https://{self.bucket}.s3.{self.region}.amazonaws.com/{key}"
        return f"https://{self.bucket}.s3.amazonaws.com/{key}"

    def _guess_suffix(self, *, file_name: str, content_type: str) -> str:
        by_type = mimetypes.guess_extension(content_type.lower().strip() or "")
        if by_type:
            return by_type
        by_name = Path(file_name).suffix.strip()
        if by_name and len(by_name) <= 10:
            if by_name.startswith("."):
                return by_name.lower()
            return f".{by_name.lower()}"
        return ".bin"


def build_object_storage_from_env(
    *,
    local_root_dir: Path,
    local_public_prefix: str = "/api/storage",
) -> ObjectStorage:
    backend = os.environ.get("BACKEND_OBJECT_STORAGE_BACKEND", "local").strip().lower()
    if backend in {"", "local", "fs", "file"}:
        return LocalObjectStorage(
            root_dir=local_root_dir,
            public_prefix=local_public_prefix,
        )

    if backend in {"s3", "oss", "s3_compat"}:
        bucket = os.environ.get("BACKEND_S3_BUCKET", "").strip()
        if not bucket:
            raise RuntimeError("BACKEND_S3_BUCKET is required when using s3 backend")
        return S3ObjectStorage(
            bucket=bucket,
            prefix=os.environ.get("BACKEND_S3_PREFIX", ""),
            region=os.environ.get("BACKEND_S3_REGION", ""),
            endpoint_url=os.environ.get("BACKEND_S3_ENDPOINT"),
            access_key_id=os.environ.get("BACKEND_S3_ACCESS_KEY_ID"),
            secret_access_key=os.environ.get("BACKEND_S3_SECRET_ACCESS_KEY"),
            session_token=os.environ.get("BACKEND_S3_SESSION_TOKEN"),
            public_base_url=os.environ.get("BACKEND_S3_PUBLIC_BASE_URL"),
        )

    raise RuntimeError(
        "Unsupported BACKEND_OBJECT_STORAGE_BACKEND. Expected local|s3|oss|s3_compat"
    )


def _is_not_found_error(error: Exception) -> bool:
    code = None
    response = getattr(error, "response", None)
    if isinstance(response, dict):
        code = str(response.get("Error", {}).get("Code", "")).strip()
    if not code:
        return False
    return code in {"NoSuchKey", "404", "NotFound"}
