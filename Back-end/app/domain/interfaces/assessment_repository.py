"""Interface only — Phase 5 scope per plan §5 dependency table (Phase 6 depends on Phase 5,
not the other way around). The concrete Postgres-backed implementation is Phase 6 work; until
then, `run_assessment`'s use case does not persist anything (documented in Phase 5's progress
log entry, not a silent omission).
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from uuid import UUID


class AssessmentRepository(ABC):
    @abstractmethod
    async def save(self, assessment_id: UUID, payload: dict) -> None: ...

    @abstractmethod
    async def get(self, assessment_id: UUID) -> dict | None: ...

    @abstractmethod
    async def save_chat_seed(self, session_id: UUID, payload: dict) -> None: ...
