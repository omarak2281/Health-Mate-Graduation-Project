from __future__ import annotations

from abc import ABC, abstractmethod

from pydantic import BaseModel

from app.domain.entities.assessment import AssessmentInput


class DiseasePrediction(BaseModel):
    disease_id: str
    confidence: float


class DiseaseClassifier(ABC):
    """ML disease classifier — ranks candidate diseases only. Per plan §2.1, it never decides
    urgency alone; that stays with the rule engine + this classifier's aggregate output."""

    @abstractmethod
    def predict_top_k(self, assessment: AssessmentInput, k: int = 3) -> list[DiseasePrediction]: ...
