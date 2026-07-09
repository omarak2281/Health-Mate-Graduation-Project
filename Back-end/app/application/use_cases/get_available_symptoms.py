from __future__ import annotations

from app.application.dto.assessment_dto import Lang
from app.domain.interfaces.taxonomy_repository import TaxonomyRepository


def get_available_symptoms(
    taxonomy: TaxonomyRepository, category_id: str | None = None, lang: Lang = "en"
) -> list[dict]:
    return [
        {
            "id": s.id,
            "name": (s.name_ar or s.name_en) if lang == "ar" else s.name_en,
            "description": (s.description_ar if lang == "ar" else s.description_en) or "",
            "red_flag": s.red_flag,
            "synonyms": s.synonyms_ar if lang == "ar" else s.synonyms_en,
        }
        for s in taxonomy.get_symptoms(category_id)
    ]
