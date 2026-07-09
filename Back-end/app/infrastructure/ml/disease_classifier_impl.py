from __future__ import annotations

from app.domain.entities.assessment import AssessmentInput
from app.domain.interfaces.disease_classifier import DiseaseClassifier, DiseasePrediction
from app.infrastructure.ml.model_registry import ModelRegistry
from app.infrastructure.ml.structured_feature_builder import build_features


class LightGbmDiseaseClassifier(DiseaseClassifier):
    def __init__(self, registry: ModelRegistry) -> None:
        self._registry = registry

    def predict_top_k(self, assessment: AssessmentInput, k: int = 3) -> list[DiseasePrediction]:
        if not self._registry.is_available:
            return []
        features = build_features(assessment).reshape(1, -1)
        proba = self._registry.model.predict_proba(features)[0]
        top_indices = proba.argsort()[::-1][:k]
        disease_ids = self._registry.label_encoder.inverse_transform(top_indices)
        return [
            DiseasePrediction(disease_id=disease_id, confidence=float(proba[idx]))
            for disease_id, idx in zip(disease_ids, top_indices)
        ]
