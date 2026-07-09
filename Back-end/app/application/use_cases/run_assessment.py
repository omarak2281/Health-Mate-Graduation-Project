"""Plan §6 Phase 5: POST /assessment's use case. Applies red-flag rules BEFORE exposing model
output, and red flags must still appear even if the ML call fails (§6.1 error contract) — the
classifier call is wrapped so a model-loading problem degrades to an empty `top_predictions`
list, never to a missing/incomplete `red_flags` list.
"""
from __future__ import annotations

import logging

from app.application.dto.assessment_dto import (
    DISCLAIMER,
    RECOMMENDED_ACTIONS,
    URGENCY_LABELS,
    AssessmentResultDTO,
    Lang,
    RedFlagDTO,
    TopPrediction,
)
from app.application.interfaces.assessment_phraser import AssessmentPhraser
from app.domain.entities.assessment import AssessmentInput
from app.domain.interfaces.disease_classifier import DiseaseClassifier
from app.domain.interfaces.taxonomy_repository import TaxonomyRepository
from app.domain.rules_engine.bp_rules import classify_bp_vitals
from app.domain.rules_engine.red_flag_rules import evaluate_red_flags
from app.domain.rules_engine.urgency_rules import determine_urgency
from app.domain.value_objects.urgency import Urgency, max_urgency

logger = logging.getLogger(__name__)

_URGENCY_TIERS: list[Urgency] = ["low", "moderate", "high", "critical"]


def _scale_urgency_by_severity(
    default_urgency: Urgency, assessment: AssessmentInput, why_ids: list[str]
) -> Urgency:
    """`disease.default_urgency` is a single static ceiling per disease (e.g. every
    depression case defaults to "high"), so a patient reporting mild symptoms got the same
    alarming urgency as one reporting severe ones. Scale it down using the reported severity
    (0-4) of the symptoms that actually drove this prediction -- never up, since
    `default_urgency` is the clinical ceiling for the disease and `max_urgency` composition
    with the (independent) rule engine still applies afterwards.
    """
    relevant = [s.severity for s in assessment.symptoms if s.id in why_ids]
    if not relevant:
        return default_urgency
    avg_severity = sum(relevant) / len(relevant)
    ceiling_rank = _URGENCY_TIERS.index(default_urgency)
    if avg_severity >= 3:
        scaled_rank = ceiling_rank
    elif avg_severity >= 2:
        scaled_rank = min(ceiling_rank, _URGENCY_TIERS.index("moderate"))
    else:
        scaled_rank = min(ceiling_rank, _URGENCY_TIERS.index("low"))
    return _URGENCY_TIERS[scaled_rank]

# "elevated_bp" is a synthetic why-reason (see below) representing the vitals-derived BP
# reading, not a taxonomy symptom -- it has no entry in taxonomy_repository, so it needs its
# own label here rather than a `taxonomy.get_symptom()` lookup.
_ELEVATED_BP_LABEL: dict[Lang, str] = {"en": "Elevated blood pressure", "ar": "ارتفاع ضغط الدم"}


def _symptom_label(symptom_id: str, taxonomy: TaxonomyRepository, lang: Lang) -> str:
    if symptom_id == "elevated_bp":
        return _ELEVATED_BP_LABEL[lang]
    symptom = taxonomy.get_symptom(symptom_id)
    if symptom is None:
        return symptom_id
    return (symptom.name_ar or symptom.name_en) if lang == "ar" else symptom.name_en


def _resolve_red_flags(assessment: AssessmentInput, taxonomy: TaxonomyRepository) -> None:
    """Mutates each SelectedSymptom.red_flag from the taxonomy — keeps the rule engine pure."""
    for selected in assessment.symptoms:
        symptom = taxonomy.get_symptom(selected.id)
        selected.red_flag = bool(symptom and symptom.red_flag)


def run_assessment(
    assessment: AssessmentInput,
    taxonomy: TaxonomyRepository,
    classifier: DiseaseClassifier,
    lang: Lang = "en",
    phraser: AssessmentPhraser | None = None,
) -> AssessmentResultDTO:
    _resolve_red_flags(assessment, taxonomy)
    red_flags = evaluate_red_flags(assessment.symptoms)
    rule_urgency = determine_urgency(assessment, red_flags)

    try:
        predictions = classifier.predict_top_k(assessment, k=3)
    except Exception:  # noqa: BLE001
        logger.exception("Disease classifier failed — degrading to rule-engine-only result")
        predictions = []

    ml_urgency = rule_urgency
    top_predictions: list[TopPrediction] = []
    selected_ids = {s.id for s in assessment.symptoms}
    for pred in predictions:
        disease = taxonomy.get_disease(pred.disease_id)
        if disease is None:
            continue
        why = sorted(selected_ids & set(disease.related_symptom_ids))
        if disease.category_id == "heart_bp" and classify_bp_vitals(assessment.vitals) in ("high", "critical"):
            why.append("elevated_bp")
        top_predictions.append(
            TopPrediction(
                disease_id=disease.id,
                name=disease.name_ar if lang == "ar" else disease.name_en,
                confidence=pred.confidence,
                why=why,
                why_names=[_symptom_label(sid, taxonomy, lang) for sid in why],
            )
        )
        if pred is predictions[0]:
            ml_urgency = _scale_urgency_by_severity(disease.default_urgency, assessment, why)

    final_urgency = max_urgency(rule_urgency, ml_urgency)
    action_code, action_en, action_ar = RECOMMENDED_ACTIONS[final_urgency]

    top_name = top_predictions[0].name if top_predictions else ("الحالة" if lang == "ar" else "the condition")
    if lang == "ar":
        patient_message = f"بناءً على الأعراض المُدخلة، الاحتمال الأكثر ترجيحًا هو {top_name}. مستوى الخطورة: {URGENCY_LABELS[final_urgency]['ar']}."
        # Include the predicted condition name here too -- caregivers previously
        # only saw an urgency level with no indication of what was actually found.
        caregiver_summary = f"تقييم أعراض جديد للحالة المحتملة: {top_name}، بمستوى خطورة {URGENCY_LABELS[final_urgency]['ar']}" + (
            f"، مع {len(red_flags)} علامة تحذيرية." if red_flags else "."
        )
    else:
        patient_message = f"Based on the reported symptoms, the most likely condition is {top_name}. Urgency level: {URGENCY_LABELS[final_urgency]['en']}."
        caregiver_summary = f"New symptom assessment for likely condition: {top_name}, urgency level {URGENCY_LABELS[final_urgency]['en']}" + (
            f", with {len(red_flags)} red flag(s) triggered." if red_flags else "."
        )

    result = AssessmentResultDTO(
        top_predictions=top_predictions,
        urgency=final_urgency,
        urgency_label=URGENCY_LABELS[final_urgency][lang],
        red_flags=[
            RedFlagDTO(code=rf.code, name=_symptom_label(rf.code, taxonomy, lang), severity=rf.severity)
            for rf in red_flags
        ],
        patient_message=patient_message,
        recommended_action_code=action_code,
        recommended_action_text=action_ar if lang == "ar" else action_en,
        caregiver_summary=caregiver_summary,
        should_notify_caregiver=final_urgency in ("high", "critical"),
        disclaimer=DISCLAIMER[lang],
    )
    if phraser is None:
        return result
    return phraser.phrase(assessment, result, lang=lang)
