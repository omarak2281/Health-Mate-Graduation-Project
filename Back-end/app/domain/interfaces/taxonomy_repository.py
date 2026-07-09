from __future__ import annotations

from abc import ABC, abstractmethod

from app.domain.entities.category import Category
from app.domain.entities.disease import Disease
from app.domain.entities.symptom import Symptom


class TaxonomyRepository(ABC):
    @abstractmethod
    def get_categories(self) -> list[Category]: ...

    @abstractmethod
    def get_symptoms(self, category_id: str | None = None) -> list[Symptom]: ...

    @abstractmethod
    def get_symptom(self, symptom_id: str) -> Symptom | None: ...

    @abstractmethod
    def get_disease(self, disease_id: str) -> Disease | None: ...

    @abstractmethod
    def get_diseases(self) -> list[Disease]: ...
