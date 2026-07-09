from __future__ import annotations

from pydantic import BaseModel


class Category(BaseModel):
    id: str
    name_en: str
    name_ar: str
    order: int
