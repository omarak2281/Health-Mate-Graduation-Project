from __future__ import annotations

from pydantic import BaseModel, Field

from app.domain.value_objects.urgency import Urgency


class Disease(BaseModel):
    id: str
    name_en: str
    name_ar: str
    description_en: str
    description_ar: str
    category_id: str
    default_urgency: Urgency
    related_symptom_ids: list[str] = Field(default_factory=list)
