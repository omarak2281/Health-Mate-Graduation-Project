"""Plan §6.1 API contract DTOs + the static templated text (urgency labels, action text,
disclaimer, patient/caregiver messages) that backs them. This is deliberately the "static
templated text" fallback plan §6 Phase 9 describes — the optional LLM phrasing layer is meant
to enhance these strings later, not replace a missing baseline; Phase 5 must ship a complete,
correctly-localized response without it.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

from app.domain.value_objects.urgency import Urgency

Lang = Literal["en", "ar"]

URGENCY_LABELS: dict[Urgency, dict[Lang, str]] = {
    "low": {"en": "Low", "ar": "منخفض"},
    "moderate": {"en": "Moderate", "ar": "متوسط"},
    "high": {"en": "High", "ar": "مرتفع"},
    "critical": {"en": "Critical", "ar": "حرج"},
}

# (code, text_en, text_ar) per urgency tier — plan §6.1's own worked example uses
# "remeasure_after_rest" for a heart_bp-category high-urgency case; run_bp_triage.py overrides
# this specifically for vitals-driven assessments, per BP_FLOW_CALIBRATION_HANDOFF.md's
# "borderline high -> re-measure, confirmed critical -> notify caregiver immediately" rule.
RECOMMENDED_ACTIONS: dict[Urgency, tuple[str, str, str]] = {
    "critical": ("seek_emergency_care", "Seek emergency medical care immediately.", "اطلب رعاية طبية عاجلة فورًا."),
    "high": ("seek_medical_attention_soon", "Seek medical attention soon.", "يرجى طلب رعاية طبية قريبًا."),
    "moderate": ("schedule_doctor_visit", "Schedule a doctor visit.", "يرجى حجز موعد مع طبيب."),
    "low": ("self_care_monitor", "Rest and monitor your symptoms.", "يرجى الراحة ومراقبة الأعراض."),
}

DISCLAIMER: dict[Lang, str] = {
    "en": "This is a preliminary assessment, not a final diagnosis.",
    "ar": "هذا تقييم مبدئي وليس تشخيصًا نهائيًا.",
}


class TopPrediction(BaseModel):
    disease_id: str
    name: str
    confidence: float
    why: list[str] = Field(default_factory=list)
    why_names: list[str] = Field(default_factory=list)


class RedFlagDTO(BaseModel):
    code: str
    name: str
    severity: int


class AssessmentResultDTO(BaseModel):
    top_predictions: list[TopPrediction]
    urgency: Urgency
    urgency_label: str
    red_flags: list[RedFlagDTO]
    patient_message: str
    recommended_action_code: str
    recommended_action_text: str
    caregiver_summary: str
    should_notify_caregiver: bool
    should_remeasure: bool = False
    disclaimer: str
