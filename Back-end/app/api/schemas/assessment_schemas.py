"""Plan §6.1 request/response wire shapes for the new structured assessment endpoints."""
from __future__ import annotations

from pydantic import BaseModel, Field
from uuid import UUID

from app.domain.value_objects.age_group import AgeGroup


class SelectedSymptomSchema(BaseModel):
    id: str
    severity: int = Field(ge=0, le=4)


class VitalsSchema(BaseModel):
    systolic: int | None = None
    diastolic: int | None = None
    heart_rate: int | None = None
    spo2: float | None = None


class AssessmentRequestSchema(BaseModel):
    source_vital_id: UUID | None = None
    category_id: str | None = None
    symptoms: list[SelectedSymptomSchema] = Field(default_factory=list)
    duration_days: int | None = None
    age_group: AgeGroup | None = None
    known_conditions: list[str] = Field(default_factory=list)
    vitals: VitalsSchema | None = None


class ErrorResponse(BaseModel):
    """Plan §6.1 error contract — stable codes only, Flutter never parses `message` for logic."""

    error_code: str
    message: str


class CaregiverNotificationResponse(BaseModel):
    notified_count: int
    auto_triggered: bool = False
