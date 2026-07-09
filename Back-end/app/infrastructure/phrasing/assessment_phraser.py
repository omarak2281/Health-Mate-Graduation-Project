"""Phase 9 optional LLM phrasing.

The static DTO text remains the source of truth. The LLM adapter is deliberately additive:
disabled by default, bounded by a small JSON schema, and allowed to update only text fields.
"""
from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from app.application.dto.assessment_dto import AssessmentResultDTO, Lang
from app.application.interfaces.assessment_phraser import AssessmentPhraser
from app.core.config import settings
from app.domain.entities.assessment import AssessmentInput

logger = logging.getLogger(__name__)

PHRASABLE_FIELDS = ("patient_message", "caregiver_summary")


class StaticAssessmentPhraser:
    """No-op phraser used when Phase 9's optional LLM layer is disabled or unavailable."""

    def phrase(
        self,
        assessment: AssessmentInput,
        result: AssessmentResultDTO,
        *,
        lang: Lang,
    ) -> AssessmentResultDTO:
        return result


class OpenAICompatibleAssessmentPhraser:
    """Small OpenAI-compatible chat-completions adapter.

    It asks for JSON containing only `patient_message` and `caregiver_summary`. Any malformed
    response, missing field, or client error returns the static result unchanged.
    """

    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        base_url: str,
        timeout_seconds: float,
    ) -> None:
        self._api_key = api_key
        self._model = model
        self._base_url = base_url.rstrip("/")
        self._timeout_seconds = timeout_seconds

    def phrase(
        self,
        assessment: AssessmentInput,
        result: AssessmentResultDTO,
        *,
        lang: Lang,
    ) -> AssessmentResultDTO:
        if not self._api_key:
            return result

        try:
            payload = self._build_payload(assessment, result, lang)
            with httpx.Client(timeout=self._timeout_seconds) as client:
                response = client.post(
                    f"{self._base_url}/chat/completions",
                    headers={"Authorization": f"Bearer {self._api_key}"},
                    json=payload,
                )
                response.raise_for_status()
            phrased = self._parse_content(response.json())
        except Exception:  # noqa: BLE001
            logger.exception("Optional assessment phrasing failed; using static text")
            return result

        updates = {
            field: value.strip()
            for field, value in phrased.items()
            if field in PHRASABLE_FIELDS and isinstance(value, str) and value.strip()
        }
        if set(updates) != set(PHRASABLE_FIELDS):
            logger.warning("Optional assessment phrasing returned incomplete text; using static text")
            return result
        return result.model_copy(update=updates)

    def _build_payload(self, assessment: AssessmentInput, result: AssessmentResultDTO, lang: Lang) -> dict[str, Any]:
        structured_context = {
            "language": lang,
            "symptoms": [symptom.model_dump() for symptom in assessment.symptoms],
            "duration_days": assessment.duration_days,
            "age_group": assessment.age_group,
            "known_conditions": assessment.known_conditions,
            "vitals": assessment.vitals.model_dump() if assessment.vitals else None,
            "top_predictions": [prediction.model_dump() for prediction in result.top_predictions],
            "urgency": result.urgency,
            "urgency_label": result.urgency_label,
            "red_flags": [flag.model_dump() for flag in result.red_flags],
            "recommended_action_code": result.recommended_action_code,
            "recommended_action_text": result.recommended_action_text,
            "should_notify_caregiver": result.should_notify_caregiver,
            "should_remeasure": result.should_remeasure,
            "disclaimer": result.disclaimer,
            "static_patient_message": result.patient_message,
            "static_caregiver_summary": result.caregiver_summary,
        }
        return {
            "model": self._model,
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "You rewrite only the wording of a symptom-checker result. "
                        "Do not add diagnoses, urgency, recommendations, red flags, medications, "
                        "or thresholds. Return JSON with exactly patient_message and caregiver_summary."
                    ),
                },
                {"role": "user", "content": json.dumps(structured_context, ensure_ascii=False)},
            ],
        }

    @staticmethod
    def _parse_content(response_json: dict[str, Any]) -> dict[str, Any]:
        content = response_json["choices"][0]["message"]["content"]
        parsed = json.loads(content)
        if not isinstance(parsed, dict):
            raise ValueError("LLM phrasing response must be a JSON object")
        return parsed


def build_assessment_phraser() -> AssessmentPhraser:
    if not settings.symptom_checker_llm_phrasing_enabled:
        return StaticAssessmentPhraser()
    if not settings.symptom_checker_llm_api_key:
        logger.warning("Symptom-checker LLM phrasing enabled without an API key; using static text")
        return StaticAssessmentPhraser()
    return OpenAICompatibleAssessmentPhraser(
        api_key=settings.symptom_checker_llm_api_key,
        model=settings.symptom_checker_llm_model,
        base_url=settings.symptom_checker_llm_base_url,
        timeout_seconds=settings.symptom_checker_llm_timeout_seconds,
    )
