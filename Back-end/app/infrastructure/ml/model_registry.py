"""Phase 5 — model_registry.py. Loads the Phase 4 LightGBM artifacts and enforces the
version/schema guard the plan's risk register explicitly asks for (§8: "scikit-learn version
drift between training and backend -> add a startup check in model_registry.py that logs a
hard warning (or refuses to load) on version mismatch").
"""
from __future__ import annotations

import json
import logging
from pathlib import Path

import joblib
import sklearn

from app.core.config import settings

logger = logging.getLogger(__name__)

MODEL_FILENAME = "best_model_v2.pkl"
LABEL_ENCODER_FILENAME = "label_encoder_v2.pkl"
METADATA_FILENAME = "model_metadata_v2.json"


class ModelRegistry:
    def __init__(self, production_dir: str | None = None) -> None:
        self._dir = Path(production_dir or settings.symptom_checker_model_path)
        self.model = None
        self.label_encoder = None
        self.metadata: dict | None = None
        self._load()

    def _load(self) -> None:
        metadata_path = self._dir / METADATA_FILENAME
        if not metadata_path.exists():
            logger.warning("Model metadata not found at %s — classifier will be unavailable", metadata_path)
            return
        self.metadata = json.loads(metadata_path.read_text(encoding="utf-8"))

        trained_sklearn = self.metadata.get("sklearn_version")
        if trained_sklearn and trained_sklearn != sklearn.__version__:
            logger.warning(
                "scikit-learn version mismatch: model trained with %s, backend runtime has %s. "
                "Predictions may be unreliable or fail to unpickle — see plan §1.4/§8. "
                "Pin matching versions in Symptom-Checker/requirements.txt and Back-end/requirements.txt.",
                trained_sklearn,
                sklearn.__version__,
            )

        self.model = joblib.load(self._dir / MODEL_FILENAME)
        self.label_encoder = joblib.load(self._dir / LABEL_ENCODER_FILENAME)

    @property
    def is_available(self) -> bool:
        return self.model is not None and self.label_encoder is not None


_registry: ModelRegistry | None = None


def get_model_registry() -> ModelRegistry:
    global _registry
    if _registry is None:
        _registry = ModelRegistry()
    return _registry
