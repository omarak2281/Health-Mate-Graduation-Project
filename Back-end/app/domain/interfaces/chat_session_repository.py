"""Interface only — Phase 5 scope. The Redis-backed implementation is Phase 6 work; Phase 5's
`start_chat_from_assessment` use case uses an in-memory implementation of this interface as a
stopgap (same in-memory pattern the old `ai.py` already used for chat sessions, so this is not
a regression — persistence across restarts was already broken per plan §1.6 item 4, and stays
broken until Phase 6, tracked explicitly rather than silently carried forward).
"""
from __future__ import annotations

from abc import ABC, abstractmethod


class ChatSessionRepository(ABC):
    @abstractmethod
    def create(self, session_id: str, context: dict) -> None: ...

    @abstractmethod
    def get(self, session_id: str) -> dict | None: ...
