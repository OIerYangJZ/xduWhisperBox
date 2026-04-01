#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from sqlalchemy import create_engine, text
except ModuleNotFoundError as exc:  # pragma: no cover - runtime dependency guard
    raise SystemExit(
        "Missing dependency: SQLAlchemy. Run: pip install -r backend/requirements-db.txt"
    ) from exc

ROOT_DIR = Path(__file__).resolve().parent
DEFAULT_JSON_FILE = ROOT_DIR / "data" / "db.json"

TABLES_IN_DEP_ORDER = [
    "users",
    "sessions",
    "email_codes",
    "channels",
    "tags",
    "sensitive_words",
    "settings",
    "meta_seq",
    "posts",
    "post_tags",
    "comments",
    "likes",
    "favorites",
    "reports",
    "dm_requests",
    "conversations",
    "audit_logs",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Migrate backend/data/db.json into MySQL/PostgreSQL."
    )
    parser.add_argument(
        "--dialect",
        choices=["postgres", "mysql"],
        required=True,
        help="Target SQL dialect.",
    )
    parser.add_argument(
        "--database-url",
        required=True,
        help="SQLAlchemy database URL, e.g. postgresql+psycopg://... or mysql+pymysql://...",
    )
    parser.add_argument(
        "--json-file",
        default=str(DEFAULT_JSON_FILE),
        help=f"Source JSON file path. Default: {DEFAULT_JSON_FILE}",
    )
    parser.add_argument(
        "--schema-file",
        default="",
        help="Optional schema file path. Defaults to backend/sql/schema_postgresql.sql or schema_mysql.sql.",
    )
    parser.add_argument(
        "--truncate",
        action="store_true",
        help="Delete all rows in target tables before import.",
    )
    return parser.parse_args()


def parse_iso_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    raw = str(value).strip()
    if not raw:
        return None
    if raw.endswith("Z"):
        raw = f"{raw[:-1]}+00:00"
    try:
        return datetime.fromisoformat(raw)
    except ValueError:
        return None


def to_sql_datetime(value: Any, dialect: str) -> datetime | None:
    parsed = parse_iso_datetime(value)
    if parsed is None:
        return None

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    else:
        parsed = parsed.astimezone(timezone.utc)

    if dialect == "mysql":
        # DATETIME has no timezone; store in UTC.
        return parsed.replace(tzinfo=None)
    return parsed


def now_for_dialect(dialect: str) -> datetime:
    current = datetime.now(timezone.utc)
    if dialect == "mysql":
        return current.replace(tzinfo=None)
    return current


def parse_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"1", "true", "yes", "on"}:
            return True
        if lowered in {"0", "false", "no", "off"}:
            return False
    return default


def parse_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def parse_string_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(x).strip() for x in value if str(x).strip()]
    if isinstance(value, str):
        return [x.strip() for x in value.split(",") if x.strip()]
    return []


def iter_sql_statements(sql: str) -> list[str]:
    statements: list[str] = []
    buffer: list[str] = []

    for line in sql.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("--"):
            continue
        buffer.append(line)
        if stripped.endswith(";"):
            statement = "\n".join(buffer).strip()
            if statement.endswith(";"):
                statement = statement[:-1]
            if statement:
                statements.append(statement)
            buffer = []

    if buffer:
        statement = "\n".join(buffer).strip()
        if statement:
            statements.append(statement)
    return statements


def apply_schema(conn: Any, schema_file: Path) -> None:
    if not schema_file.exists():
        raise FileNotFoundError(f"Schema file does not exist: {schema_file}")
    sql = schema_file.read_text(encoding="utf-8")
    for statement in iter_sql_statements(sql):
        conn.execute(text(statement))


def truncate_all_tables(conn: Any) -> None:
    for table in reversed(TABLES_IN_DEP_ORDER):
        conn.execute(text(f"DELETE FROM {table}"))


def assert_target_is_empty(conn: Any) -> None:
    checks = ["users", "posts", "comments", "reports", "audit_logs"]
    for table in checks:
        count = int(conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar_one())
        if count > 0:
            raise RuntimeError(
                f"Target database is not empty (table `{table}` has {count} rows). "
                "Use --truncate to clear and retry."
            )


def fetch_name_id_map(conn: Any, table: str) -> dict[str, int]:
    rows = conn.execute(text(f"SELECT id, name FROM {table}"))
    return {str(row[1]): int(row[0]) for row in rows}


def ensure_named_entity(
    conn: Any,
    *,
    table: str,
    name_field: str,
    name: str,
    sort_order: int,
    now_dt: datetime,
    cache: dict[str, int],
) -> int | None:
    clean_name = name.strip()
    if not clean_name:
        return None
    if clean_name in cache:
        return cache[clean_name]

    conn.execute(
        text(
            f"INSERT INTO {table} ({name_field}, sort_order, created_at) "
            f"VALUES (:name, :sort_order, :created_at)"
        ),
        {"name": clean_name, "sort_order": sort_order, "created_at": now_dt},
    )
    row = conn.execute(
        text(f"SELECT id FROM {table} WHERE {name_field} = :name"),
        {"name": clean_name},
    ).first()
    if row is None:
        return None
    cache[clean_name] = int(row[0])
    return cache[clean_name]


def migrate_data(conn: Any, db: dict[str, Any], dialect: str) -> dict[str, int]:
    stats: dict[str, int] = {table: 0 for table in TABLES_IN_DEP_ORDER}
    now_dt = now_for_dialect(dialect)

    users = db.get("users", [])
    seen_user_ids: set[str] = set()
    for user in users:
        if not isinstance(user, dict):
            continue
        user_id = str(user.get("id", "")).strip()
        email = str(user.get("email", "")).strip().lower()
        if not user_id or not email or user_id in seen_user_ids:
            continue
        seen_user_ids.add(user_id)

        conn.execute(
            text(
                "INSERT INTO users ("
                "id, email, password, alias, verified, verified_at, allow_stranger_dm, "
                "show_contactable, created_at, deleted, is_admin, banned, muted"
                ") VALUES ("
                ":id, :email, :password, :alias, :verified, :verified_at, :allow_stranger_dm, "
                ":show_contactable, :created_at, :deleted, :is_admin, :banned, :muted"
                ")"
            ),
            {
                "id": user_id,
                "email": email,
                "password": str(user.get("password", "")),
                "alias": str(user.get("alias", "anonymous")) or "anonymous",
                "verified": parse_bool(user.get("verified"), False),
                "verified_at": to_sql_datetime(user.get("verifiedAt"), dialect),
                "allow_stranger_dm": parse_bool(user.get("allowStrangerDm"), True),
                "show_contactable": parse_bool(user.get("showContactable"), True),
                "created_at": to_sql_datetime(user.get("createdAt"), dialect) or now_dt,
                "deleted": parse_bool(user.get("deleted"), False),
                "is_admin": parse_bool(user.get("isAdmin"), False),
                "banned": parse_bool(user.get("banned"), False),
                "muted": parse_bool(user.get("muted"), False),
            },
        )
        stats["users"] += 1

    channels = parse_string_list(db.get("channels", []))
    seen_channels: set[str] = set()
    for index, channel_name in enumerate(channels, start=1):
        if channel_name in seen_channels:
            continue
        seen_channels.add(channel_name)
        conn.execute(
            text(
                "INSERT INTO channels (name, sort_order, created_at) "
                "VALUES (:name, :sort_order, :created_at)"
            ),
            {"name": channel_name, "sort_order": index, "created_at": now_dt},
        )
        stats["channels"] += 1
    channel_id_map = fetch_name_id_map(conn, "channels")

    tags = parse_string_list(db.get("tags", []))
    seen_tags: set[str] = set()
    for index, tag_name in enumerate(tags, start=1):
        if tag_name in seen_tags:
            continue
        seen_tags.add(tag_name)
        conn.execute(
            text(
                "INSERT INTO tags (name, sort_order, created_at) "
                "VALUES (:name, :sort_order, :created_at)"
            ),
            {"name": tag_name, "sort_order": index, "created_at": now_dt},
        )
        stats["tags"] += 1
    tag_id_map = fetch_name_id_map(conn, "tags")

    sensitive_words = parse_string_list(db.get("sensitiveWords", []))
    seen_words: set[str] = set()
    for word in sensitive_words:
        clean_word = word.strip()
        if not clean_word or clean_word in seen_words:
            continue
        seen_words.add(clean_word)
        conn.execute(
            text(
                "INSERT INTO sensitive_words (word, created_at) "
                "VALUES (:word, :created_at)"
            ),
            {"word": clean_word, "created_at": now_dt},
        )
        stats["sensitive_words"] += 1

    settings = db.get("settings", {})
    if isinstance(settings, dict):
        for key, value in settings.items():
            setting_key = str(key).strip()
            if not setting_key:
                continue
            value_int: int | None = None
            value_text: str | None = None
            if isinstance(value, (int, float, bool, str)):
                try:
                    value_int = int(value)
                except (TypeError, ValueError):
                    value_text = str(value)
            elif value is not None:
                value_text = json.dumps(value, ensure_ascii=False)
            conn.execute(
                text(
                    "INSERT INTO settings (setting_key, value_int, value_text, updated_at) "
                    "VALUES (:setting_key, :value_int, :value_text, :updated_at)"
                ),
                {
                    "setting_key": setting_key,
                    "value_int": value_int,
                    "value_text": value_text,
                    "updated_at": now_dt,
                },
            )
            stats["settings"] += 1

    seq = db.get("seq", {})
    if isinstance(seq, dict):
        for key, value in seq.items():
            seq_key = str(key).strip()
            if not seq_key:
                continue
            conn.execute(
                text(
                    "INSERT INTO meta_seq (seq_key, seq_value) "
                    "VALUES (:seq_key, :seq_value)"
                ),
                {"seq_key": seq_key, "seq_value": parse_int(value, 0)},
            )
            stats["meta_seq"] += 1

    posts = db.get("posts", [])
    post_ids: set[str] = set()
    for post in posts:
        if not isinstance(post, dict):
            continue
        post_id = str(post.get("id", "")).strip()
        if not post_id or post_id in post_ids:
            continue
        post_ids.add(post_id)

        channel_name = str(post.get("channel", "")).strip()
        channel_id = ensure_named_entity(
            conn,
            table="channels",
            name_field="name",
            name=channel_name,
            sort_order=len(channel_id_map) + 1,
            now_dt=now_dt,
            cache=channel_id_map,
        )
        if channel_id is not None and channel_name not in seen_channels:
            seen_channels.add(channel_name)
            stats["channels"] += 1

        author_id_raw = str(post.get("authorId", "")).strip()
        author_id = author_id_raw if author_id_raw in seen_user_ids else None

        created_at = to_sql_datetime(post.get("createdAt"), dialect) or now_dt
        updated_at = to_sql_datetime(post.get("updatedAt"), dialect) or created_at

        conn.execute(
            text(
                "INSERT INTO posts ("
                "id, title, content, channel_id, has_image, status, allow_comment, allow_dm, "
                "author_alias, author_id, created_at, updated_at, deleted, review_status, risk_marked"
                ") VALUES ("
                ":id, :title, :content, :channel_id, :has_image, :status, :allow_comment, :allow_dm, "
                ":author_alias, :author_id, :created_at, :updated_at, :deleted, :review_status, :risk_marked"
                ")"
            ),
            {
                "id": post_id,
                "title": str(post.get("title", "")).strip() or "(untitled)",
                "content": str(post.get("content", "")),
                "channel_id": channel_id,
                "has_image": parse_bool(post.get("hasImage"), False),
                "status": str(post.get("status", "ongoing")).strip() or "ongoing",
                "allow_comment": parse_bool(post.get("allowComment"), True),
                "allow_dm": parse_bool(post.get("allowDm"), False),
                "author_alias": str(post.get("authorAlias", "anonymous")) or "anonymous",
                "author_id": author_id,
                "created_at": created_at,
                "updated_at": updated_at,
                "deleted": parse_bool(post.get("deleted"), False),
                "review_status": str(post.get("reviewStatus", "pending")).strip() or "pending",
                "risk_marked": parse_bool(post.get("riskMarked"), False),
            },
        )
        stats["posts"] += 1

    seen_post_tags: set[tuple[str, int]] = set()
    for post in posts:
        if not isinstance(post, dict):
            continue
        post_id = str(post.get("id", "")).strip()
        if post_id not in post_ids:
            continue
        for tag_name in parse_string_list(post.get("tags", [])):
            tag_id = ensure_named_entity(
                conn,
                table="tags",
                name_field="name",
                name=tag_name,
                sort_order=len(tag_id_map) + 1,
                now_dt=now_dt,
                cache=tag_id_map,
            )
            if tag_id is None:
                continue
            if tag_name not in seen_tags:
                seen_tags.add(tag_name)
                stats["tags"] += 1
            key = (post_id, tag_id)
            if key in seen_post_tags:
                continue
            seen_post_tags.add(key)
            conn.execute(
                text(
                    "INSERT INTO post_tags (post_id, tag_id) "
                    "VALUES (:post_id, :tag_id)"
                ),
                {"post_id": post_id, "tag_id": tag_id},
            )
            stats["post_tags"] += 1

    comments = db.get("comments", [])
    comment_ids: set[str] = set()
    pending_parent_links: list[tuple[str, str]] = []
    for comment in comments:
        if not isinstance(comment, dict):
            continue
        comment_id = str(comment.get("id", "")).strip()
        if not comment_id or comment_id in comment_ids:
            continue

        post_id = str(comment.get("postId", "")).strip()
        if post_id not in post_ids:
            continue
        comment_ids.add(comment_id)

        user_id_raw = str(comment.get("userId", "")).strip()
        user_id = user_id_raw if user_id_raw in seen_user_ids else None

        parent_id_raw = str(comment.get("parentId", "")).strip()
        if parent_id_raw:
            pending_parent_links.append((comment_id, parent_id_raw))

        conn.execute(
            text(
                "INSERT INTO comments ("
                "id, post_id, user_id, author_alias, content, created_at, deleted, "
                "like_count, review_status, risk_marked, parent_id"
                ") VALUES ("
                ":id, :post_id, :user_id, :author_alias, :content, :created_at, :deleted, "
                ":like_count, :review_status, :risk_marked, :parent_id"
                ")"
            ),
            {
                "id": comment_id,
                "post_id": post_id,
                "user_id": user_id,
                "author_alias": str(comment.get("authorAlias", "anonymous")) or "anonymous",
                "content": str(comment.get("content", "")),
                "created_at": to_sql_datetime(comment.get("createdAt"), dialect) or now_dt,
                "deleted": parse_bool(comment.get("deleted"), False),
                "like_count": parse_int(comment.get("likeCount"), 0),
                "review_status": str(comment.get("reviewStatus", "pending")).strip() or "pending",
                "risk_marked": parse_bool(comment.get("riskMarked"), False),
                "parent_id": None,
            },
        )
        stats["comments"] += 1

    for comment_id, parent_id in pending_parent_links:
        if comment_id in comment_ids and parent_id in comment_ids and comment_id != parent_id:
            conn.execute(
                text(
                    "UPDATE comments SET parent_id = :parent_id "
                    "WHERE id = :id"
                ),
                {"id": comment_id, "parent_id": parent_id},
            )

    likes = db.get("likes", [])
    seen_likes: set[tuple[str, str]] = set()
    for row in likes:
        if not isinstance(row, dict):
            continue
        user_id = str(row.get("userId", "")).strip()
        post_id = str(row.get("postId", "")).strip()
        key = (user_id, post_id)
        if user_id not in seen_user_ids or post_id not in post_ids or key in seen_likes:
            continue
        seen_likes.add(key)
        conn.execute(
            text(
                "INSERT INTO likes (user_id, post_id, created_at) "
                "VALUES (:user_id, :post_id, :created_at)"
            ),
            {"user_id": user_id, "post_id": post_id, "created_at": now_dt},
        )
        stats["likes"] += 1

    favorites = db.get("favorites", [])
    seen_favorites: set[tuple[str, str]] = set()
    for row in favorites:
        if not isinstance(row, dict):
            continue
        user_id = str(row.get("userId", "")).strip()
        post_id = str(row.get("postId", "")).strip()
        key = (user_id, post_id)
        if user_id not in seen_user_ids or post_id not in post_ids or key in seen_favorites:
            continue
        seen_favorites.add(key)
        conn.execute(
            text(
                "INSERT INTO favorites (user_id, post_id, created_at) "
                "VALUES (:user_id, :post_id, :created_at)"
            ),
            {"user_id": user_id, "post_id": post_id, "created_at": now_dt},
        )
        stats["favorites"] += 1

    reports = db.get("reports", [])
    seen_report_ids: set[str] = set()
    for report in reports:
        if not isinstance(report, dict):
            continue
        report_id = str(report.get("id", "")).strip()
        if not report_id or report_id in seen_report_ids:
            continue
        seen_report_ids.add(report_id)

        user_id_raw = str(report.get("userId", "")).strip()
        user_id = user_id_raw if user_id_raw in seen_user_ids else None
        handled_by_raw = str(report.get("handledBy", "")).strip()
        handled_by = handled_by_raw if handled_by_raw in seen_user_ids else None

        conn.execute(
            text(
                "INSERT INTO reports ("
                "id, user_id, reporter_alias, target_type, target_id, reason, description, status, "
                "result, created_at, handled_at, handled_by"
                ") VALUES ("
                ":id, :user_id, :reporter_alias, :target_type, :target_id, :reason, :description, :status, "
                ":result, :created_at, :handled_at, :handled_by"
                ")"
            ),
            {
                "id": report_id,
                "user_id": user_id,
                "reporter_alias": str(report.get("reporterAlias", "anonymous")) or "anonymous",
                "target_type": str(report.get("targetType", "other")).strip() or "other",
                "target_id": str(report.get("targetId", "unknown")).strip() or "unknown",
                "reason": str(report.get("reason", "other")).strip() or "other",
                "description": str(report.get("description", "")),
                "status": str(report.get("status", "pending")).strip() or "pending",
                "result": str(report.get("result", "")),
                "created_at": to_sql_datetime(report.get("createdAt"), dialect) or now_dt,
                "handled_at": to_sql_datetime(report.get("handledAt"), dialect),
                "handled_by": handled_by,
            },
        )
        stats["reports"] += 1

    dm_requests = db.get("dmRequests", [])
    seen_request_ids: set[str] = set()
    for dm_request in dm_requests:
        if not isinstance(dm_request, dict):
            continue
        request_id = str(dm_request.get("id", "")).strip()
        if not request_id or request_id in seen_request_ids:
            continue
        seen_request_ids.add(request_id)

        to_user_id_raw = str(dm_request.get("toUserId", "")).strip()
        to_user_id = to_user_id_raw if to_user_id_raw in seen_user_ids else None
        created_at = to_sql_datetime(dm_request.get("createdAt"), dialect) or now_dt
        updated_at = to_sql_datetime(dm_request.get("updatedAt"), dialect)

        conn.execute(
            text(
                "INSERT INTO dm_requests ("
                "id, to_user_id, from_alias, reason, status, created_at, updated_at"
                ") VALUES ("
                ":id, :to_user_id, :from_alias, :reason, :status, :created_at, :updated_at"
                ")"
            ),
            {
                "id": request_id,
                "to_user_id": to_user_id,
                "from_alias": str(dm_request.get("fromAlias", "anonymous")) or "anonymous",
                "reason": str(dm_request.get("reason", "")),
                "status": str(dm_request.get("status", "pending")).strip() or "pending",
                "created_at": created_at,
                "updated_at": updated_at,
            },
        )
        stats["dm_requests"] += 1

    conversations = db.get("conversations", [])
    seen_conversation_ids: set[str] = set()
    for conversation in conversations:
        if not isinstance(conversation, dict):
            continue
        conversation_id = str(conversation.get("id", "")).strip()
        if not conversation_id or conversation_id in seen_conversation_ids:
            continue
        seen_conversation_ids.add(conversation_id)

        user_id_raw = str(conversation.get("userId", "")).strip()
        user_id = user_id_raw if user_id_raw in seen_user_ids else None

        conn.execute(
            text(
                "INSERT INTO conversations (id, user_id, name, last_message, updated_at) "
                "VALUES (:id, :user_id, :name, :last_message, :updated_at)"
            ),
            {
                "id": conversation_id,
                "user_id": user_id,
                "name": str(conversation.get("name", "conversation")) or "conversation",
                "last_message": str(conversation.get("lastMessage", "")),
                "updated_at": to_sql_datetime(conversation.get("updatedAt"), dialect) or now_dt,
            },
        )
        stats["conversations"] += 1

    audit_logs = db.get("auditLogs", [])
    seen_audit_ids: set[str] = set()
    for audit_log in audit_logs:
        if not isinstance(audit_log, dict):
            continue
        audit_id = str(audit_log.get("id", "")).strip()
        if not audit_id or audit_id in seen_audit_ids:
            continue
        seen_audit_ids.add(audit_id)

        actor_id_raw = str(audit_log.get("actorId", "")).strip()
        actor_id = actor_id_raw if actor_id_raw in seen_user_ids else None

        conn.execute(
            text(
                "INSERT INTO audit_logs (id, actor_id, action, detail, created_at) "
                "VALUES (:id, :actor_id, :action, :detail, :created_at)"
            ),
            {
                "id": audit_id,
                "actor_id": actor_id,
                "action": str(audit_log.get("action", "action")) or "action",
                "detail": str(audit_log.get("detail", "")),
                "created_at": to_sql_datetime(audit_log.get("createdAt"), dialect) or now_dt,
            },
        )
        stats["audit_logs"] += 1

    sessions = db.get("sessions", {})
    if isinstance(sessions, dict):
        seen_tokens: set[str] = set()
        for token, user_id_raw in sessions.items():
            token_str = str(token).strip()
            user_id = str(user_id_raw).strip()
            if not token_str or token_str in seen_tokens or user_id not in seen_user_ids:
                continue
            seen_tokens.add(token_str)
            conn.execute(
                text(
                    "INSERT INTO sessions (token, user_id, created_at) "
                    "VALUES (:token, :user_id, :created_at)"
                ),
                {"token": token_str, "user_id": user_id, "created_at": now_dt},
            )
            stats["sessions"] += 1

    email_codes = db.get("emailCodes", {})
    if isinstance(email_codes, dict):
        seen_emails: set[str] = set()
        for email, row in email_codes.items():
            email_str = str(email).strip().lower()
            if not email_str or email_str in seen_emails:
                continue
            seen_emails.add(email_str)
            if isinstance(row, dict):
                code = str(row.get("code", "")).strip() or "000000"
                expires_at = to_sql_datetime(row.get("expiresAt"), dialect) or now_dt
            else:
                code = "000000"
                expires_at = now_dt
            conn.execute(
                text(
                    "INSERT INTO email_codes (email, code, expires_at, created_at) "
                    "VALUES (:email, :code, :expires_at, :created_at)"
                ),
                {
                    "email": email_str,
                    "code": code,
                    "expires_at": expires_at,
                    "created_at": now_dt,
                },
            )
            stats["email_codes"] += 1

    return stats


def resolve_schema_file(dialect: str, schema_file_arg: str) -> Path:
    if schema_file_arg.strip():
        path = Path(schema_file_arg).expanduser()
        return path if path.is_absolute() else (Path.cwd() / path).resolve()
    file_name = "schema_postgresql.sql" if dialect == "postgres" else "schema_mysql.sql"
    return ROOT_DIR / "sql" / file_name


def resolve_json_file(json_file_arg: str) -> Path:
    path = Path(json_file_arg).expanduser()
    return path if path.is_absolute() else (Path.cwd() / path).resolve()


def main() -> None:
    args = parse_args()
    json_file = resolve_json_file(args.json_file)
    schema_file = resolve_schema_file(args.dialect, args.schema_file)

    if not json_file.exists():
        raise FileNotFoundError(f"JSON file does not exist: {json_file}")

    source = json.loads(json_file.read_text(encoding="utf-8"))
    if not isinstance(source, dict):
        raise ValueError(f"JSON root must be an object: {json_file}")

    engine = create_engine(args.database_url, future=True)
    try:
        with engine.begin() as conn:
            apply_schema(conn, schema_file)
            if args.truncate:
                truncate_all_tables(conn)
            else:
                assert_target_is_empty(conn)
            stats = migrate_data(conn, source, args.dialect)
    finally:
        engine.dispose()

    print("Migration completed.")
    print(f"Source JSON: {json_file}")
    print(f"Schema file: {schema_file}")
    for table in TABLES_IN_DEP_ORDER:
        print(f"- {table}: {stats.get(table, 0)}")


if __name__ == "__main__":
    main()
