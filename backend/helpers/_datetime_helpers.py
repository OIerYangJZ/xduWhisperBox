from __future__ import annotations

from datetime import datetime, timedelta, timezone

CHINA_TZ = timezone(timedelta(hours=8))


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def now_iso() -> str:
    return now_utc().isoformat()


def date_to_timestamp(date_str: str) -> float:
    try:
        return datetime.fromisoformat(date_str.replace("Z", "+00:00")).timestamp()
    except Exception:
        return 0.0


def parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def is_today_iso(value: str | None) -> bool:
    dt = parse_iso(value)
    if dt is None:
        return False
    return dt.astimezone(timezone.utc).date() == now_utc().date()
