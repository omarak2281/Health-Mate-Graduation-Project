"""Plan §6 Phase 5: POST /chat/from-assessment. Seeds a chat session with the assessment
result instead of starting empty (plan §3.2/BP_FLOW_CALIBRATION_HANDOFF.md's "do not start an
empty chat" rule) so `AiSymptomChatPage` (kept as-is per plan §3.2) can open pre-loaded with
context. The actual conversational free-text handling stays in the existing `ai.py`
`/chat` endpoint / `SymptomCheckerService.extract_symptoms` — this use case only creates the
seed context and hands back a session id, per the plan's own `{"assessment_id": "..."}`
response shape (§6.1).
"""
from __future__ import annotations

import uuid

from app.application.dto.assessment_dto import AssessmentResultDTO, Lang
from app.domain.interfaces.chat_session_repository import ChatSessionRepository


def start_chat_from_assessment(
    assessment_result: AssessmentResultDTO,
    chat_sessions: ChatSessionRepository,
    lang: Lang = "en",
    assessment_id: str | None = None,
) -> str:
    assessment_id = assessment_id or str(uuid.uuid4())
    chat_sessions.create(
        assessment_id,
        {
            "symptoms": [],
            "state": "INITIAL",
            "seeded_from_assessment": True,
            "seed_context": assessment_result.model_dump(),
            "lang": lang,
        },
    )
    return assessment_id
