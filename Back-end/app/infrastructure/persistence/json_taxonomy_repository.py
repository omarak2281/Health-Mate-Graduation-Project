"""Phase 5 — reads the Phase 1 migrated taxonomy directly from
`Symptom-Checker/taxonomy/*.json` (same pattern the old `ai_service.py` already used to read
`Symptom-Checker/Data/*.json` — reading a mounted data directory, not a new precedent). In
Docker this path is `/app/Symptom-Checker/taxonomy` via the `../Symptom-Checker:/app/Symptom-Checker`
volume mount in `docker-compose.yml`; locally it resolves relative to the repo root via
`app.core.config.settings.symptom_checker_taxonomy_path`.

A real database-backed repository (plan's `postgres_taxonomy_repository.py`) is future work —
not required by this plan; the taxonomy is static reference data, not user data, so a read-only
JSON-backed repository behind the same `TaxonomyRepository` interface is a legitimate permanent
choice, not just a Phase 5 stopgap. Cached in memory after first read since the taxonomy only
changes when Phase 1's migration script re-runs (not per-request).
"""
from __future__ import annotations

import json
from pathlib import Path

from app.core.config import settings
from app.domain.entities.category import Category
from app.domain.entities.disease import Disease
from app.domain.entities.symptom import Symptom
from app.domain.interfaces.taxonomy_repository import TaxonomyRepository


class JsonTaxonomyRepository(TaxonomyRepository):
    def __init__(self, taxonomy_dir: str | None = None) -> None:
        self._dir = Path(taxonomy_dir or settings.symptom_checker_taxonomy_path)
        self._categories: list[Category] | None = None
        self._symptoms: list[Symptom] | None = None
        self._diseases: list[Disease] | None = None

    def _load(self) -> None:
        if self._categories is not None:
            return
        self._categories = [
            Category(**c) for c in json.loads((self._dir / "categories.json").read_text(encoding="utf-8"))
        ]
        self._symptoms = [
            Symptom(**s) for s in json.loads((self._dir / "symptoms.json").read_text(encoding="utf-8"))
        ]
        self._diseases = [
            Disease(**d) for d in json.loads((self._dir / "diseases.json").read_text(encoding="utf-8"))
        ]

    def get_categories(self) -> list[Category]:
        self._load()
        return sorted(self._categories, key=lambda c: c.order)

    def get_symptoms(self, category_id: str | None = None) -> list[Symptom]:
        self._load()
        if category_id is None:
            return list(self._symptoms)
        return [s for s in self._symptoms if category_id in s.category_ids]

    def get_symptom(self, symptom_id: str) -> Symptom | None:
        self._load()
        return next((s for s in self._symptoms if s.id == symptom_id), None)

    def get_disease(self, disease_id: str) -> Disease | None:
        self._load()
        return next((d for d in self._diseases if d.id == disease_id), None)

    def get_diseases(self) -> list[Disease]:
        self._load()
        return list(self._diseases)
