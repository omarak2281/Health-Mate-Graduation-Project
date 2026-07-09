"""Plan §6 Phase 2: evaluate_red_flags. Pure function — no I/O, no taxonomy lookups.
Callers (Phase 5 use cases) resolve `SelectedSymptom.red_flag` from the taxonomy repository
before calling this.
"""
from __future__ import annotations

from app.domain.entities.assessment import SelectedSymptom
from app.domain.entities.red_flag import RedFlag

DEFAULT_SEVERITY_THRESHOLD = 2
ANY_SEVERITY_THRESHOLD = 1

# Plan §6 Phase 2, verbatim: "except syncope/loss_of_consciousness which trigger at any
# severity >= 1". `sudden_loss_of_consciousness` is included too — same clinical concept,
# already flagged red_flag=true during Phase 1 migration (see migration_report.md).
LOW_THRESHOLD_SYMPTOM_IDS = frozenset({
    "syncope",
    "loss_of_consciousness",
    "sudden_loss_of_consciousness",
})


def evaluate_red_flags(selected_symptoms: list[SelectedSymptom]) -> list[RedFlag]:
    flags: list[RedFlag] = []
    for symptom in selected_symptoms:
        if not symptom.red_flag:
            continue
        threshold = (
            ANY_SEVERITY_THRESHOLD
            if symptom.id in LOW_THRESHOLD_SYMPTOM_IDS
            else DEFAULT_SEVERITY_THRESHOLD
        )
        if symptom.severity >= threshold:
            flags.append(RedFlag(code=symptom.id, symptom_id=symptom.id, severity=symptom.severity))
    return flags
