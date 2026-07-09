from __future__ import annotations

from app.application.dto.assessment_dto import Lang
from app.domain.interfaces.taxonomy_repository import TaxonomyRepository


def get_categories(taxonomy: TaxonomyRepository, lang: Lang = "en") -> list[dict]:
    return [
        {"id": c.id, "name": c.name_ar if lang == "ar" else c.name_en, "order": c.order}
        for c in taxonomy.get_categories()
    ]
