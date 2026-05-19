"""
handlers/_ai_handler.py

AI Assistant endpoints:
  POST /api/ai/chat
"""
from __future__ import annotations

import random
from typing import Any
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

from helpers import (
    json_error,
    read_json_body,
    send_json,
)

# A simple knowledge base for XDU (Placeholder for real RAG)
XDU_KNOWLEDGE = {
    "选课": "西电选课通常在教务系统中进行，分为预选、正选和补退选阶段。详情请关注教务处通知。",
    "班车": "南校区与北校区之间的班车时刻表可以在‘西电导航’小程序或学校官网查询。记得提前到场。",
    "奖学金": "学校设有国家奖学金、校一二三等奖学金等。评定通常在秋季进行，综合考量成绩与表现。",
    "树洞": "西电树洞是大家匿名交流的平台。在这里你可以分享生活、吐槽或求助，但请务必遵守社区准则。",
    "食堂": "南校区有海棠、丁香、竹园等食堂，各有特色。海棠的面食和丁香的小吃都很受欢迎。",
    "图书馆": "南校区图书馆环境优美，北校区图书馆历史悠久。进入需要刷校园卡或扫码。",
    "辅导员": "辅导员是同学们大学生活的指路人，如果你在学习或生活上遇到困难，可以随时联系你的辅导员。",
    "学费": "学费缴纳通常在学年开始前进行，可以通过学校财务处的官方平台在线缴纳。",
    "体测": "体测是每学年的必修项，通常在春秋两季进行，请关注体育部的通知，合理安排锻炼时间。",
    "放假": "学校的放假安排会根据校历进行，通常会在教务处或学校官网提前公示。",
}

def handle_ai_chat(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    """POST /api/ai/chat"""
    body = read_json_body(handler)
    if not body:
        return json_error(handler, HTTPStatus.BAD_REQUEST, "Invalid JSON body")

    content = str(body.get("content", "")).strip()
    if not content:
        return json_error(handler, HTTPStatus.BAD_REQUEST, "Content is required")

    # Simple keyword-based matching (Simulating RAG)
    reply = None
    for key, value in XDU_KNOWLEDGE.items():
        if key in content:
            reply = value
            break
    
    if not reply:
        fallback_replies = [
            "这是一个好问题！我正在努力学习更多关于西电的知识。目前我主要了解选课、班车、奖学金、食堂和图书馆等话题。",
            "抱歉，我目前对这个话题了解不多。也许你可以在树洞发个帖问问其他同学？",
            "西电的校园生活很丰富，如果你问关于校园生活的问题，我会尽量回答你。",
            "你好！我是西电 AI 助手。你可以问我关于学校政策、校园生活等方面的问题。",
        ]
        reply = random.choice(fallback_replies)

    send_json(handler, HTTPStatus.OK, {
        "data": {
            "reply": reply,
            "role": "assistant"
        }
    })
