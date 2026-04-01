from __future__ import annotations

import email.utils
import os
import smtplib
from email.message import EmailMessage


def verification_send_error_message(error: Exception) -> str:
    if _is_email_not_found_error(error):
        return "该校园邮箱不存在或不可达，请检查邮箱是否真实有效"
    return "验证码邮件发送失败，请稍后重试"


def _is_email_not_found_error(error: Exception) -> bool:
    if isinstance(error, smtplib.SMTPRecipientsRefused):
        return True
    if isinstance(error, smtplib.SMTPResponseException):
        code = int(getattr(error, "smtp_code", 0) or 0)
        raw = getattr(error, "smtp_error", b"")
        if isinstance(raw, bytes):
            msg = raw.decode("utf-8", errors="ignore").lower()
        else:
            msg = str(raw).lower()
        if code in {550, 551, 553, 554}:
            markers = (
                "user unknown", "unknown user", "no such user",
                "recipient address rejected", "mailbox unavailable",
                "not found", "invalid recipient",
            )
            if any(marker in msg for marker in markers):
                return True
    text = str(error).lower()
    return "user unknown" in text or "recipient address rejected" in text or "no such user" in text


def send_verification_email(
    *,
    to_email: str,
    code: str,
    expires_in_minutes: int = 10,
) -> None:
    import _globals
    if not _globals.smtp_configured():
        raise RuntimeError("邮件服务未配置，请设置 BACKEND_SMTP_* 环境变量")
    msg = EmailMessage()
    msg["Subject"] = "西电树洞邮箱验证码"
    msg["From"] = email.utils.formataddr((_globals.SMTP_FROM_NAME, _globals.SMTP_FROM_EMAIL))
    msg["To"] = to_email
    msg.set_content(
        "你好，\n\n"
        "你的西电树洞验证码为："
        f"{code}\n"
        f"该验证码将在 {expires_in_minutes} 分钟后过期。\n\n"
        "如果这不是你的操作，请忽略本邮件。"
    )
    timeout_seconds = 10
    if _globals.SMTP_USE_SSL:
        with smtplib.SMTP_SSL(_globals.SMTP_HOST, _globals.SMTP_PORT, timeout=timeout_seconds) as server:
            if _globals.SMTP_USERNAME:
                server.login(_globals.SMTP_USERNAME, _globals.SMTP_PASSWORD)
            server.send_message(msg)
        return
    with smtplib.SMTP(_globals.SMTP_HOST, _globals.SMTP_PORT, timeout=timeout_seconds) as server:
        server.ehlo()
        if _globals.SMTP_USE_STARTTLS:
            server.starttls()
            server.ehlo()
        if _globals.SMTP_USERNAME:
            server.login(_globals.SMTP_USERNAME, _globals.SMTP_PASSWORD)
        server.send_message(msg)


def send_password_reset_email(
    *,
    to_email: str,
    code: str,
    expires_in_minutes: int = 10,
) -> None:
    import _globals
    if not _globals.smtp_configured():
        raise RuntimeError("邮件服务未配置，请设置 BACKEND_SMTP_* 环境变量")
    msg = EmailMessage()
    msg["Subject"] = "西电树洞密码重置验证码"
    msg["From"] = email.utils.formataddr((_globals.SMTP_FROM_NAME, _globals.SMTP_FROM_EMAIL))
    msg["To"] = to_email
    msg.set_content(
        "你好，\n\n"
        "你正在进行西电树洞密码重置，验证码为："
        f"{code}\n"
        f"该验证码将在 {expires_in_minutes} 分钟后过期。\n\n"
        "如果这不是你的操作，请忽略本邮件。"
    )
    timeout_seconds = 10
    if _globals.SMTP_USE_SSL:
        with smtplib.SMTP_SSL(_globals.SMTP_HOST, _globals.SMTP_PORT, timeout=timeout_seconds) as server:
            if _globals.SMTP_USERNAME:
                server.login(_globals.SMTP_USERNAME, _globals.SMTP_PASSWORD)
            server.send_message(msg)
        return
    with smtplib.SMTP(_globals.SMTP_HOST, _globals.SMTP_PORT, timeout=timeout_seconds) as server:
        server.ehlo()
        if _globals.SMTP_USE_STARTTLS:
            server.starttls()
            server.ehlo()
        if _globals.SMTP_USERNAME:
            server.login(_globals.SMTP_USERNAME, _globals.SMTP_PASSWORD)
        server.send_message(msg)
