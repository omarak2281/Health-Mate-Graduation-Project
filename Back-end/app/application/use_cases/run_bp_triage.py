"""Plan §6 Phase 5 / §6.1: POST /bp-triage — same response shape as /assessment plus
`should_remeasure`. BP_FLOW_CALIBRATION_HANDOFF.md's alert-logic rule: "for borderline high
readings, ask patient to re-measure; for confirmed critical readings, notify caregiver
immediately" — implemented here as an override of the generic urgency->action mapping only for
this vitals-driven entry point, not for the general /assessment endpoint (which doesn't always
carry vitals and shouldn't default to a BP-specific action).
"""
from __future__ import annotations

from app.application.dto.assessment_dto import RECOMMENDED_ACTIONS, AssessmentResultDTO, Lang
from app.application.interfaces.assessment_phraser import AssessmentPhraser
from app.application.use_cases.run_assessment import run_assessment
from app.domain.entities.assessment import AssessmentInput
from app.domain.interfaces.disease_classifier import DiseaseClassifier
from app.domain.interfaces.taxonomy_repository import TaxonomyRepository

REMEASURE_ACTION = ("remeasure_after_rest", "Rest for 5 minutes, then re-measure.", "استرح لمدة 5 دقائق ثم أعد القياس.")


def run_bp_triage(
    assessment: AssessmentInput,
    taxonomy: TaxonomyRepository,
    classifier: DiseaseClassifier,
    lang: Lang = "en",
    phraser: AssessmentPhraser | None = None,
) -> AssessmentResultDTO:
    result = run_assessment(assessment, taxonomy, classifier, lang=lang)

    should_remeasure = assessment.vitals is not None and result.urgency in ("moderate", "high")
    if should_remeasure:
        code, text_en, text_ar = REMEASURE_ACTION
        result = result.model_copy(
            update={
                "recommended_action_code": code,
                "recommended_action_text": text_ar if lang == "ar" else text_en,
                "should_remeasure": True,
            }
        )
    if phraser is None:
        return result
    return phraser.phrase(assessment, result, lang=lang)
