from __future__ import annotations

from pydantic import BaseModel, Field

from app.domain.value_objects.age_group import AgeGroup


class SelectedSymptom(BaseModel):
    """A symptom the patient picked during the assessment wizard.

    `red_flag` is resolved by the caller (a use case backed by the taxonomy repository,
    Phase 5) from the symptom's own taxonomy record — the rule engine stays a pure
    function and never reads the taxonomy itself.
    """

    id: str
    severity: int = Field(ge=0, le=4)
    red_flag: bool = False


class Vitals(BaseModel):
    systolic: int | None = None
    diastolic: int | None = None
    heart_rate: int | None = None
    spo2: float | None = None


class AssessmentInput(BaseModel):
    category_id: str | None = None
    symptoms: list[SelectedSymptom] = Field(default_factory=list)
    duration_days: int | None = None
    age_group: AgeGroup | None = None
    known_conditions: list[str] = Field(default_factory=list)
    vitals: Vitals | None = None
