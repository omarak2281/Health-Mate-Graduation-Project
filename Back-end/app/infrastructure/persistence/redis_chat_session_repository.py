"""Redis-backed active chat-session store for Phase 6."""
from __future__ import annotations

import json
import logging

import redis

from app.core.config import settings
from app.domain.interfaces.chat_session_repository import ChatSessionRepository

logger = logging.getLogger(__name__)


class RedisChatSessionRepository(ChatSessionRepository):
    def __init__(self, redis_url: str | None = None, key_prefix: str = "symptom_chat:session"):
        self._client = redis.Redis.from_url(
            redis_url or settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
        self._key_prefix = key_prefix

    def create(self, session_id: str, context: dict) -> None:
        self._client.set(self._key(session_id), json.dumps(context, ensure_ascii=False))

    def get(self, session_id: str) -> dict | None:
        raw = self._client.get(self._key(session_id))
        if raw is None:
            return None
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            logger.warning("Invalid JSON in Redis chat session %s", session_id)
            return None
        return data if isinstance(data, dict) else None

    def _key(self, session_id: str) -> str:
        return f"{self._key_prefix}:{session_id}"


_repo: RedisChatSessionRepository | None = None


def get_chat_session_repository() -> RedisChatSessionRepository:
    global _repo
    if _repo is None:
        _repo = RedisChatSessionRepository()
    return _repo
