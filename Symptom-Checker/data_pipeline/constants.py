"""Shared constants for the data pipeline and training phases — kept in one place so Phase 3
(dataset generation) and Phase 4 (feature engineering/training) never define this twice.
"""
from __future__ import annotations

# See Symptom-Checker/data_pipeline/generate_structured_cases.py module docstring for the
# full explanation of why this pool exists (plan §4.5 gap: no risk-factor taxonomy from Phase 1).
RISK_FACTOR_POOL = [
    "hypertension",
    "diabetes_mellitus_type_2",
    "asthma",
    "hypothyroidism",
    "chronic_kidney_disease",
]
