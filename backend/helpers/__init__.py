"""
helpers/__init__.py

Re-exports helpers from sub-modules and re-exports services for convenience.
"""
from helpers._auth_helpers import (
    decode_base64_payload,
    detect_image_type,
    calc_sha256_hex,
    hash_password,
    is_password_hashed,
    is_valid_student_id,
    is_campus_email,
    normalize_media_url,
    normalize_avatar_url,
    extract_local_object_key_from_url,
    parse_bool,
    parse_list,
    PASSWORD_HASH_SCHEME,
    PASSWORD_SALT_BYTES,
    PASSWORD_HASH_ITERATIONS,
    random_code,
    sanitize_alias,
    student_id_from_email,
    verify_password,
)
from helpers._datetime_helpers import (
    CHINA_TZ,
    date_to_timestamp,
    is_today_iso,
    now_iso,
    now_utc,
    parse_iso,
)
from helpers._mailer import (
    send_verification_email,
    send_password_reset_email,
    verification_send_error_message,
)
from helpers._rate_limit import (
    assess_text_risk,
    check_duplicate_image_hash,
    check_ip_rate_limit,
    consume_rate_limit,
    get_client_ip,
    get_setting_int,
    send_rate_limit_error,
)
from helpers._http_helpers import (
    json_error,
    read_json_body,
    resolve_web_asset_path,
    send_binary,
    send_json,
    send_static_file,
    should_fallback_to_spa,
)

__all__ = [
    # auth helpers
    "decode_base64_payload",
    "detect_image_type",
    "calc_sha256_hex",
    "hash_password",
    "is_password_hashed",
    "is_valid_student_id",
    "is_campus_email",
    "normalize_media_url",
    "normalize_avatar_url",
    "extract_local_object_key_from_url",
    "parse_bool",
    "parse_list",
    "PASSWORD_HASH_SCHEME",
    "PASSWORD_SALT_BYTES",
    "PASSWORD_HASH_ITERATIONS",
    "random_code",
    "sanitize_alias",
    "student_id_from_email",
    "verify_password",
    # datetime helpers
    "CHINA_TZ",
    "date_to_timestamp",
    "is_today_iso",
    "now_iso",
    "now_utc",
    "parse_iso",
    # mailer helpers
    "send_verification_email",
    "send_password_reset_email",
    "verification_send_error_message",
    # rate_limit helpers
    "assess_text_risk",
    "check_duplicate_image_hash",
    "check_ip_rate_limit",
    "consume_rate_limit",
    "get_client_ip",
    "get_setting_int",
    "send_rate_limit_error",
    # http helpers
    "json_error",
    "read_json_body",
    "resolve_web_asset_path",
    "send_binary",
    "send_json",
    "send_static_file",
    "should_fallback_to_spa",
]
