"""Optional phrasing boundary for Phase 9.

Implementations may rewrite only patient/caregiver text that is already derived from the
structured assessment result. They must never change diagnosis, urgency, red flags, action codes,
or notification decisions.
"""
from __future__ import annotations

from typing import Protocol

from app.application.dto.assessment_dto import AssessmentResultDTO, Lang
from app.domain.entities.assessment import AssessmentInput


class AssessmentPhraser(Protocol):
    def phrase(
        self,
        assessment: AssessmentInput,
        result: AssessmentResultDTO,
        *,
        lang: Lang,
    ) -> AssessmentResultDTO:
        """Return `result` with phrased text fields, or the original result on failure."""
