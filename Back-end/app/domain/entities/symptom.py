from __future__ import annotations

from pydantic import BaseModel, Field


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
