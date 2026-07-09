from __future__ import annotations

from pydantic import BaseModel, Field


class CategoryResponse(BaseModel):
    id: str
    name: str
    order: int


class SymptomResponse(BaseModel):
    id: str
    name: str
    description: str
    red_flag: bool
    synonyms: list[str] = Field(default_factory=list)
