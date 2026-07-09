"""Phase 5 stopgap implementation of ChatSessionRepository — same in-memory pattern the old
`ai.py` already used (`CHAT_SESSIONS = {}` at module scope), so this does not regress anything;
persistence across restarts was already broken per plan §1.6 item 4 and stays broken until
Phase 6's Redis-backed implementation replaces this one behind the same interface.
"""
from __future__ import annotations

from app.domain.interfaces.chat_session_repository import ChatSessionRepository


class InMemoryChatSessionRepository(ChatSessionRepository):
    def __init__(self) -> None:
        self._sessions: dict[str, dict] = {}

    def create(self, session_id: str, context: dict) -> None:
        self._sessions[session_id] = context

    def get(self, session_id: str) -> dict | None:
        return self._sessions.get(session_id)


_repo = InMemoryChatSessionRepository()


def get_chat_session_repository() -> InMemoryChatSessionRepository:
    return _repo
