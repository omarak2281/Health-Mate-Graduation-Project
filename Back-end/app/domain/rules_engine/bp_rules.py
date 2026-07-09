"""Shared BP thresholds. Single source of truth for both the symptom-checker rule engine
(Phase 2, this module) and the BP feature's own alert logic (Phase 8) — plan §6 Phase 2
explicitly forbids duplicating these numbers in two files.

Critical/High/SpO2 numbers are sourced verbatim from BP_FLOW_CALIBRATION_HANDOFF.md's
"Alert Logic" section, which the symptom-checker plan's own urgency_rules spec (§6 Phase 2)
matches number-for-number.
"""
from __future__ import annotations

from app.domain.entities.assessment import Vitals
from app.domain.value_objects.urgency import Urgency

SBP_CRITICAL = 180
DBP_CRITICAL = 120
SPO2_CRITICAL = 90  # SpO2 < 90

SBP_HIGH = 140
DBP_HIGH = 90
SBP_HYPOTENSION_HIGH = 90  # SBP < 90 is also "high" per the handoff doc (hypotension risk)
SPO2_HIGH = 94  # SpO2 < 94

# Named per the handoff doc's "Medium: HR > 100, HR < 50" tier. Not currently consumed by
# urgency_rules.determine_urgency — the symptom-checker plan's own Phase 2 spec only defines
# the moderate tier as "≥2 symptoms severity≥2 OR known hypertension + elevated BP" and does
# not mention heart rate. Kept here for Phase 8's direct BP alert logic, which does need it.
# This is a documented gap between the two source docs, not an oversight — see
# Plans/SYMPTOM_CHECKER_PROGRESS.md Phase 2.
HR_HIGH = 100
HR_LOW = 50

# NOT sourced from either source doc — neither the plan nor the handoff doc gives a numeric
# "elevated BP range" (the handoff doc only names the tier "elevated BP range" without bounds).
# These follow the standard AHA Elevated/Stage-1-hypertension boundary as the most defensible
# public clinical reference available, and are required to evaluate the plan's own
# "known hypertension + elevated BP -> moderate" rule. Needs explicit clinical/product sign-off
# before this ships — flagged, not silently assumed. See Plans/SYMPTOM_CHECKER_PROGRESS.md Phase 2.
SBP_ELEVATED = 130
DBP_ELEVATED = 80


def classify_bp_vitals(vitals: Vitals | None) -> Urgency | None:
    """Urgency implied by vitals alone, or None if vitals don't cross a high/critical threshold."""
    if vitals is None:
        return None
    sbp, dbp, spo2 = vitals.systolic, vitals.diastolic, vitals.spo2
    if (
        (sbp is not None and sbp >= SBP_CRITICAL)
        or (dbp is not None and dbp >= DBP_CRITICAL)
        or (spo2 is not None and spo2 < SPO2_CRITICAL)
    ):
        return "critical"
    if (
        (sbp is not None and (sbp >= SBP_HIGH or sbp < SBP_HYPOTENSION_HIGH))
        or (dbp is not None and dbp >= DBP_HIGH)
        or (spo2 is not None and spo2 < SPO2_HIGH)
    ):
        return "high"
    return None


def is_bp_elevated(vitals: Vitals | None) -> bool:
    if vitals is None:
        return False
    sbp, dbp = vitals.systolic, vitals.diastolic
    return (sbp is not None and sbp >= SBP_ELEVATED) or (dbp is not None and dbp >= DBP_ELEVATED)
