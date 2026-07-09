"""Postgres-backed assessment repository for Phase 6 persistence."""
from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domain.interfaces.assessment_repository import AssessmentRepository
from app.models.symptom_assessment import (
    Assessment,
    AssessmentSymptom,
    RedFlagTriggered,
    SymptomChatMessage,
    SymptomChatSession,
)


class PostgresAssessmentRepository(AssessmentRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    async def save(self, assessment_id: UUID, payload: dict) -> None:
        request = payload["request"]
        result = payload["result"]

        assessment = Assessment(
            id=assessment_id,
            user_id=payload.get("user_id"),
            source_vital_id=request.get("source_vital_id"),
            assessment_type=payload.get("assessment_type", "symptom_checker"),
            category_id=request.get("category_id"),
            duration_days=request.get("duration_days"),
            age_group=request.get("age_group"),
            known_conditions=request.get("known_conditions", []),
            vitals=request.get("vitals"),
            top_predictions=result.get("top_predictions", []),
            urgency=result["urgency"],
            urgency_label=result["urgency_label"],
            recommended_action_code=result["recommended_action_code"],
            recommended_action_text=result["recommended_action_text"],
            patient_message=result["patient_message"],
            caregiver_summary=result["caregiver_summary"],
            should_notify_caregiver=result["should_notify_caregiver"],
            should_remeasure=result.get("should_remeasure", False),
            disclaimer=result["disclaimer"],
            lang=payload.get("lang", "en"),
        )
        assessment.symptoms = [
            AssessmentSymptom(symptom_id=symptom["id"], severity=symptom["severity"])
            for symptom in request.get("symptoms", [])
        ]
        assessment.red_flags = [
            RedFlagTriggered(code=red_flag["code"], severity=red_flag["severity"])
            for red_flag in result.get("red_flags", [])
        ]
        self._session.add(assessment)

    async def get(self, assessment_id: UUID) -> dict | None:
        stmt = (
            select(Assessment)
            .options(selectinload(Assessment.symptoms), selectinload(Assessment.red_flags))
            .where(Assessment.id == assessment_id)
        )
        assessment = (await self._session.execute(stmt)).scalar_one_or_none()
        if assessment is None:
            return None
        return {
            "id": str(assessment.id),
            "user_id": str(assessment.user_id) if assessment.user_id else None,
            "source_vital_id": str(assessment.source_vital_id) if assessment.source_vital_id else None,
            "assessment_type": assessment.assessment_type,
            "category_id": assessment.category_id,
            "duration_days": assessment.duration_days,
            "age_group": assessment.age_group,
            "known_conditions": assessment.known_conditions,
            "vitals": assessment.vitals,
            "symptoms": [
                {"id": symptom.symptom_id, "severity": symptom.severity}
                for symptom in assessment.symptoms
            ],
            "top_predictions": assessment.top_predictions,
            "urgency": assessment.urgency,
            "urgency_label": assessment.urgency_label,
            "red_flags": [
                {"code": red_flag.code, "severity": red_flag.severity}
                for red_flag in assessment.red_flags
            ],
            "recommended_action_code": assessment.recommended_action_code,
            "recommended_action_text": assessment.recommended_action_text,
            "patient_message": assessment.patient_message,
            "caregiver_summary": assessment.caregiver_summary,
            "should_notify_caregiver": assessment.should_notify_caregiver,
            "should_remeasure": assessment.should_remeasure,
            "disclaimer": assessment.disclaimer,
            "lang": assessment.lang,
            "created_at": assessment.created_at.isoformat(),
        }

    async def save_chat_seed(self, session_id: UUID, payload: dict) -> None:
        context = payload.get("context", {})
        seed_context = context.get("seed_context", {})
        seed_message = seed_context.get("patient_message") or "Chat seeded from symptom assessment."
        message_payload = {
            "assessment_id": str(payload.get("assessment_id")) if payload.get("assessment_id") else None,
            "seed_context": seed_context,
        }
        self._session.add(
            SymptomChatSession(
                id=session_id,
                user_id=payload.get("user_id"),
                assessment_id=payload.get("assessment_id"),
                state=payload.get("state", "INITIAL"),
                seeded_from_assessment=payload.get("seeded_from_assessment", False),
                lang=payload.get("lang", "en"),
                context=context,
                messages=[
                    SymptomChatMessage(
                        role="assistant",
                        message=seed_message,
                        payload=message_payload,
                    )
                ],
            )
        )
