"""Pydantic schema for the migrated symptom-checker taxonomy.

Shared by the Phase 1 migration output and later phases (dataset generation,
feature engineering). Field shapes follow Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md §4.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

Urgency = Literal["low", "moderate", "high", "critical"]


class Category(BaseModel):
    id: str
    name_en: str
    name_ar: str
    order: int


class Symptom(BaseModel):
    id: str
    name_en: str
    name_ar: str | None = None
    description_en: str | None = None
    description_ar: str | None = None
    category_ids: list[str] = Field(default_factory=list)
    red_flag: bool = False
    synonyms_en: list[str] = Field(default_factory=list)
    synonyms_ar: list[str] = Field(default_factory=list)
    needs_translation: bool = False
    source: Literal["general", "heart", "stub_orphan_reference"] = "general"


class Disease(BaseModel):
    id: str
    name_en: str
    name_ar: str
    description_en: str
    description_ar: str
    category_id: str
    default_urgency: Urgency
    related_symptom_ids: list[str] = Field(default_factory=list)


class Taxonomy(BaseModel):
    categories: list[Category]
    symptoms: list[Symptom]
    diseases: list[Disease]


AgeGroup = Literal["child", "adult", "elderly"]


class CaseSymptom(BaseModel):
    id: str
    severity: int = Field(ge=0, le=4)


class CaseVitals(BaseModel):
    systolic: int | None = None
    diastolic: int | None = None
    heart_rate: int | None = None
    spo2: float | None = None


class TrainingCase(BaseModel):
    """Structured training case — plan §4.4. `urgency` is computed by running the case's
    symptoms/vitals through the Phase 2 rule engine (Back-end/app/domain/rules_engine), not
    invented separately, so the synthetic dataset and the production rule engine never disagree
    on what a given symptom/vitals combination implies."""

    case_id: str
    disease_id: str
    symptoms: list[CaseSymptom]
    duration_days: int
    age_group: AgeGroup
    risk_factors: list[str] = Field(default_factory=list)
    vitals: CaseVitals | None = None
    urgency: Urgency
    source: Literal["synthetic_v1", "reformatted_legacy", "clinical_reviewed"] = "synthetic_v1"
