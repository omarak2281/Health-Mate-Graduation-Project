"""Plan §6 Phase 2: urgency_rules — combines red flags + vitals into a single Urgency.

This is the "urgency floor" the Phase 5 assessment aggregator will take the max() of
against the ML classifier's output (plan §2.1: the rule engine can only escalate urgency,
never suppress it).
"""
from __future__ import annotations

from app.domain.entities.assessment import AssessmentInput
from app.domain.entities.red_flag import RedFlag
from app.domain.rules_engine.bp_rules import classify_bp_vitals, is_bp_elevated
from app.domain.value_objects.urgency import Urgency

MODERATE_SYMPTOM_SEVERITY_THRESHOLD = 2
MODERATE_SYMPTOM_COUNT_THRESHOLD = 2
CRITICAL_RED_FLAG_SEVERITY_THRESHOLD = 3


def determine_urgency(assessment: AssessmentInput, red_flags: list[RedFlag]) -> Urgency:
    vitals_urgency = classify_bp_vitals(assessment.vitals)

    if any(rf.severity >= CRITICAL_RED_FLAG_SEVERITY_THRESHOLD for rf in red_flags) or vitals_urgency == "critical":
        return "critical"

    if red_flags or vitals_urgency == "high":
        return "high"

    moderate_symptom_count = sum(
        1 for s in assessment.symptoms if s.severity >= MODERATE_SYMPTOM_SEVERITY_THRESHOLD
    )
    has_known_hypertension = "hypertension" in {c.lower() for c in assessment.known_conditions}
    if moderate_symptom_count >= MODERATE_SYMPTOM_COUNT_THRESHOLD or (
        has_known_hypertension and is_bp_elevated(assessment.vitals)
    ):
        return "moderate"

    return "low"
