"""
handlers/_ai_handler.py

AI Assistant endpoints:
  GET  /api/ai/models
  POST /api/ai/chat
"""
from __future__ import annotations

import json
import re
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from helpers import json_error, read_json_body, send_json
from services import auth_user as auth_user_helper, list_posts
from services._user_service import is_post_private


DEFAULT_MODEL = "gpt-4o-mini"
MAX_CONTEXT_ITEMS = 8
MAX_KNOWLEDGE_ITEMS = 4
MAX_POST_ITEMS = 4


def _require_auth(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> dict[str, Any] | None:
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None
    return user


def _clean_text(value: Any, max_len: int = 4000) -> str:
    text = str(value or "").replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\s+", " ", text).strip()
    return text[:max_len]


def _normalize_base_url(value: Any) -> str:
    url = str(value or "").strip().rstrip("/")
    if not url:
        return ""
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return ""
    if url.endswith("/v1"):
        return url
    return f"{url}/v1"


def _auth_headers(api_key: str) -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }


def _read_openai_json(request: Request, timeout: int = 25) -> dict[str, Any]:
    try:
        with urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
    except HTTPError as error:
        detail = ""
        try:
            detail = error.read().decode("utf-8")
        except Exception:
            detail = str(error)
        raise RuntimeError(f"模型接口返回 {error.code}: {detail[:240]}") from error
    except URLError as error:
        raise RuntimeError(f"无法连接模型接口: {error.reason}") from error
    except TimeoutError as error:
        raise RuntimeError("模型接口响应超时") from error

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        raise RuntimeError("模型接口返回了无法解析的 JSON") from error
    if not isinstance(payload, dict):
        raise RuntimeError("模型接口返回格式异常")
    return payload


def _score_text(query_terms: list[str], text: str) -> int:
    normalized = text.lower()
    score = 0
    for term in query_terms:
        if term and term in normalized:
            score += max(1, min(6, len(term)))
    return score


def _score_knowledge_item(query_terms: list[str], item: dict[str, str]) -> int:
    title = item.get("title", "")
    content = item.get("content", "")
    score = _score_text(query_terms, title) * 3 + _score_text(query_terms, content)
    return score


def _score_post_item(query_terms: list[str], post: dict[str, Any]) -> int:
    title = _clean_text(post.get("title", ""), 120)
    content = _clean_text(post.get("content", ""), 800)
    tags = " ".join(str(tag) for tag in post.get("tags", []) if tag)
    channel = str(post.get("channel", ""))
    score = _score_text(query_terms, title) * 3
    score += _score_text(query_terms, tags) * 2
    score += _score_text(query_terms, f"{content} {channel}")
    return score


def _query_terms(question: str) -> list[str]:
    text = question.lower()
    chunks = re.findall(r"[\w\u4e00-\u9fff]{2,}", text)
    terms: list[str] = []
    for chunk in chunks:
        if chunk not in terms:
            terms.append(chunk)
        if re.search(r"[\u4e00-\u9fff]", chunk):
            for size in (2, 3, 4):
                if len(chunk) <= size:
                    continue
                for start in range(0, len(chunk) - size + 1):
                    term = chunk[start:start + size]
                    if term not in terms:
                        terms.append(term)
    return terms[:24]


def _split_knowledge_text(text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    source = str(text or "").replace("\r\n", "\n").replace("\r", "\n")
    for index, block in enumerate(re.split(r"\n\s*\n+", source), start=1):
        clean = block.strip()
        if not clean:
            continue
        title = ""
        body = clean
        if "\n" in clean:
            first, rest = clean.split("\n", 1)
            if len(first.strip()) <= 60:
                title = first.strip(" #：:")
                body = rest.strip()
        rows.append({
            "type": "knowledge",
            "id": f"knowledge-{index}",
            "title": title or f"基础资料 {index}",
            "content": _clean_text(body, 1200),
        })
    return rows


def _extract_custom_knowledge(body: dict[str, Any]) -> str:
    for key in ("knowledgeBase", "knowledge", "baseKnowledge", "schoolInfo"):
        value = body.get(key)
        if isinstance(value, str):
            return value
    return ""


def _can_use_post_for_context(post: dict[str, Any], viewer_user_id: str) -> bool:
    if post.get("deleted"):
        return False
    if post.get("reviewStatus") not in ("approved", "resolved"):
        return False
    if is_post_private(post):
        return False
    return True


def _build_post_items(db: dict[str, Any], question: str, viewer_user_id: str) -> list[dict[str, str]]:
    terms = _query_terms(question)
    rows: list[tuple[int, str, dict[str, str]]] = []
    for post in list_posts(db, sort_by="latest"):
        if not _can_use_post_for_context(post, viewer_user_id):
            continue
        title = _clean_text(post.get("title", ""), 120)
        content = _clean_text(post.get("content", ""), 800)
        score = _score_post_item(terms, post)
        if score <= 0 and terms:
            continue
        rows.append((
            score,
            str(post.get("createdAt", "")),
            {
                "type": "post",
                "id": str(post.get("id", "")),
                "title": title or "无标题帖子",
                "content": content,
                "channel": str(post.get("channel", "")),
                "createdAt": str(post.get("createdAt", "")),
            },
        ))
    rows.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [item[2] for item in rows[:MAX_POST_ITEMS]]


def _build_context_items(db: dict[str, Any], body: dict[str, Any], question: str, viewer_user_id: str) -> list[dict[str, str]]:
    terms = _query_terms(question)
    knowledge_rows: list[tuple[int, str, dict[str, str]]] = []
    post_rows: list[tuple[int, str, dict[str, str]]] = []

    for item in _split_knowledge_text(_extract_custom_knowledge(body)):
        score = _score_knowledge_item(terms, item)
        if score > 0 or not terms:
            knowledge_rows.append((score + 4, item["id"], item))

    if body.get("includePosts", True) is not False:
        for item in _build_post_items(db, question, viewer_user_id):
            score = _score_post_item(terms, item)
            post_rows.append((score, item.get("createdAt", ""), item))

    knowledge_rows.sort(key=lambda item: (item[0], item[1]), reverse=True)
    post_rows.sort(key=lambda item: (item[0], item[1]), reverse=True)

    merged: list[tuple[int, str, dict[str, str]]] = []
    merged.extend(knowledge_rows[:MAX_KNOWLEDGE_ITEMS])
    merged.extend(post_rows[:MAX_POST_ITEMS])
    merged.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [item[2] for item in merged[:MAX_CONTEXT_ITEMS]]


def _context_text(items: list[dict[str, str]]) -> str:
    if not items:
        return "暂无可用检索资料。"
    lines: list[str] = []
    for index, item in enumerate(items, start=1):
        if item.get("type") == "post":
            lines.append(
                f"[{index}] 帖子《{item.get('title', '')}》"
                f" 频道:{item.get('channel', '')} 时间:{item.get('createdAt', '')}\n"
                f"{item.get('content', '')}"
            )
        else:
            lines.append(f"[{index}] {item.get('title', '')}\n{item.get('content', '')}")
    return "\n\n".join(lines)


def _call_chat_completion(
    *,
    base_url: str,
    api_key: str,
    model: str,
    question: str,
    messages: list[dict[str, str]],
    context_items: list[dict[str, str]],
) -> str:
    system_prompt = (
        "你是西电树洞的校园 AI 助手。请优先依据给定资料回答西安电子科技大学相关问题。"
        "资料不足时要明确说明不确定，并给出下一步查询建议。"
        "可以引用帖子中的公开讨论作为线索，但不要编造政策、时间、地点或联系人。"
        "回答使用简洁中文。"
    )
    payload_messages: list[dict[str, str]] = [
        {"role": "system", "content": system_prompt},
        {"role": "system", "content": f"检索资料:\n{_context_text(context_items)}"},
    ]
    for message in messages[-8:]:
        role = "assistant" if message.get("role") == "assistant" else "user"
        content = _clean_text(message.get("content", ""), 1600)
        if content:
            payload_messages.append({"role": role, "content": content})
    payload_messages.append({"role": "user", "content": question})

    payload = {
        "model": model,
        "messages": payload_messages,
        "temperature": 0.3,
        "stream": False,
    }
    request = Request(
        f"{base_url}/chat/completions",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=_auth_headers(api_key),
        method="POST",
    )
    data = _read_openai_json(request, timeout=45)
    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        raise RuntimeError("模型接口没有返回回答")
    message = choices[0].get("message") if isinstance(choices[0], dict) else {}
    content = message.get("content") if isinstance(message, dict) else ""
    reply = _clean_text(content, 6000)
    if not reply:
        raise RuntimeError("模型接口返回了空回答")
    return reply


def handle_ai_models(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    """GET /api/ai/models?baseUrl=...&apiKey=..."""
    if _require_auth(handler, db) is None:
        return

    if handler.command.upper() == "POST":
        body = read_json_body(handler)
        base_url = _normalize_base_url(body.get("baseUrl"))
        api_key = str(body.get("apiKey", "")).strip()
    else:
        parsed = urlparse(handler.path)
        from urllib.parse import parse_qs

        query = parse_qs(parsed.query)
        base_url = _normalize_base_url((query.get("baseUrl") or [""])[0])
        api_key = str((query.get("apiKey") or [""])[0]).strip()
    if not base_url or not api_key:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请先填写 API Key 和 URL")
        return

    request = Request(f"{base_url}/models", headers=_auth_headers(api_key), method="GET")
    try:
        data = _read_openai_json(request, timeout=20)
    except RuntimeError as error:
        json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
        return

    model_rows = data.get("data", [])
    models = []
    if isinstance(model_rows, list):
        for row in model_rows:
            if isinstance(row, dict):
                model_id = str(row.get("id", "")).strip()
            else:
                model_id = str(row or "").strip()
            if model_id:
                models.append(model_id)
    models = sorted(dict.fromkeys(models))
    send_json(handler, HTTPStatus.OK, {"data": {"models": models}})


def handle_ai_chat(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    """POST /api/ai/chat"""
    user = _require_auth(handler, db)
    if user is None:
        return

    body = read_json_body(handler)
    if not body:
        json_error(handler, HTTPStatus.BAD_REQUEST, "Invalid JSON body")
        return

    question = _clean_text(body.get("content") or body.get("question"), 2000)
    api_key = str(body.get("apiKey", "")).strip()
    base_url = _normalize_base_url(body.get("baseUrl"))
    model = str(body.get("model") or DEFAULT_MODEL).strip() or DEFAULT_MODEL
    if not question:
        json_error(handler, HTTPStatus.BAD_REQUEST, "Content is required")
        return
    if not base_url or not api_key:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请先在设置页配置 AI 接口")
        return

    raw_messages = body.get("messages", [])
    messages = raw_messages if isinstance(raw_messages, list) else []
    context_items = _build_context_items(db, body, question, str(user.get("id", "")).strip())

    try:
        reply = _call_chat_completion(
            base_url=base_url,
            api_key=api_key,
            model=model,
            question=question,
            messages=messages,
            context_items=context_items,
        )
    except RuntimeError as error:
        json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
        return

    send_json(handler, HTTPStatus.OK, {
        "data": {
            "reply": reply,
            "role": "assistant",
            "model": model,
            "references": [
                {
                    "type": item.get("type", ""),
                    "id": item.get("id", ""),
                    "title": item.get("title", ""),
                    "channel": item.get("channel", ""),
                    "createdAt": item.get("createdAt", ""),
                }
                for item in context_items
            ],
        }
    })
