"""Phase 5 — thin wrapper around `Symptom-Checker/training/feature_engineering.py`'s
`build_features()`. Per plan §7 coding standard, feature engineering must be a single shared
implementation used by both training and backend inference, never copy-pasted — so this module
does not reimplement the vector layout, it imports the real one. Same cross-project import
pattern already established in Phase 3/4 (Symptom-Checker scripts importing Back-end's domain
layer); here it runs in the opposite direction at request time instead of at script time.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

from app.core.config import settings
from app.domain.entities.assessment import AssessmentInput

_root = str(Path(settings.symptom_checker_root_path))
if _root not in sys.path:
    sys.path.insert(0, _root)

from training.feature_engineering import build_features as _build_features  # noqa: E402
from training.feature_engineering import feature_names  # noqa: E402


def build_features(assessment: AssessmentInput) -> np.ndarray:
    payload = {
        "symptoms": [{"id": s.id, "severity": s.severity} for s in assessment.symptoms],
        "duration_days": assessment.duration_days,
        "age_group": assessment.age_group,
        "risk_factors": assessment.known_conditions,
        "vitals": assessment.vitals.model_dump() if assessment.vitals else None,
    }
    return _build_features(payload)


__all__ = ["build_features", "feature_names"]
