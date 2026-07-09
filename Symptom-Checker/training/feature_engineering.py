"""Phase 4 — feature_engineering.py.

Single `build_features()` implementation, per plan §4.5/§7: imported by both `training/`
(this phase) and the backend's `infrastructure/ml/` (Phase 5) — never copy-pasted. Takes a
plain dict (works for both a `TrainingCase.model_dump()` from the dataset and a Back-end
`AssessmentInput.model_dump()` at inference time, so it stays framework-agnostic) and returns
a fixed-length numeric vector plus the ordered feature name list.

Vector layout (plan §4.5), in this exact order:
  [ multi-hot symptom presence            (N_symptoms) ]
  [ severity per symptom, 0 if absent     (N_symptoms) ]
  [ duration_days bucketed: <1,1-3,4-7,>7 (4) ]
  [ age_group one-hot: child/adult/elderly (3) ]
  [ risk_factors multi-hot                (N_risk_factors) ]
  [ vitals: systolic_norm, diastolic_norm, hr_norm, vitals_present_flag (4) ]

N_symptoms/N_risk_factors are derived from the Phase 1 migrated taxonomy and the shared
`data_pipeline/constants.RISK_FACTOR_POOL`, not invented here — see that module's docstring
for the Phase 1 taxonomy gap this pool works around.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
TAXONOMY_DIR = ROOT / "taxonomy"

import sys  # noqa: E402

sys.path.insert(0, str(ROOT))
from data_pipeline.constants import RISK_FACTOR_POOL  # noqa: E402

_symptoms_raw = json.loads((TAXONOMY_DIR / "symptoms.json").read_text(encoding="utf-8"))
SYMPTOM_IDS: list[str] = sorted(s["id"] for s in _symptoms_raw)
SYMPTOM_INDEX: dict[str, int] = {sid: i for i, sid in enumerate(SYMPTOM_IDS)}
N_SYMPTOMS = len(SYMPTOM_IDS)

RISK_FACTOR_INDEX: dict[str, int] = {rf: i for i, rf in enumerate(RISK_FACTOR_POOL)}
N_RISK_FACTORS = len(RISK_FACTOR_POOL)

AGE_GROUPS = ["child", "adult", "elderly"]
DURATION_BUCKETS = ["lt_1", "1_to_3", "4_to_7", "gt_7"]

# Clinically reasonable min/max used only to normalize vitals into [0, 1] for the model input,
# not diagnostic thresholds (those live in Back-end/app/domain/rules_engine/bp_rules.py).
SYSTOLIC_RANGE = (70, 220)
DIASTOLIC_RANGE = (40, 140)
HR_RANGE = (40, 180)

SCHEMA_VERSION = "symptom_checker_features_v1"


def _duration_bucket_index(duration_days: int | None) -> int:
    if duration_days is None:
        return 0
    if duration_days < 1:
        return 0
    if duration_days <= 3:
        return 1
    if duration_days <= 7:
        return 2
    return 3


def _normalize(value: float | None, bounds: tuple[float, float]) -> float:
    if value is None:
        return 0.0
    lo, hi = bounds
    return float(np.clip((value - lo) / (hi - lo), 0.0, 1.0))


def feature_names() -> list[str]:
    names: list[str] = []
    names += [f"symptom_present__{sid}" for sid in SYMPTOM_IDS]
    names += [f"symptom_severity__{sid}" for sid in SYMPTOM_IDS]
    names += [f"duration_bucket__{b}" for b in DURATION_BUCKETS]
    names += [f"age_group__{a}" for a in AGE_GROUPS]
    names += [f"risk_factor__{rf}" for rf in RISK_FACTOR_POOL]
    names += ["vitals_systolic_norm", "vitals_diastolic_norm", "vitals_hr_norm", "vitals_present"]
    return names


_FEATURE_LENGTH = 2 * N_SYMPTOMS + 4 + 3 + N_RISK_FACTORS + 4


def build_features(assessment_input: dict) -> np.ndarray:
    """assessment_input keys: symptoms (list[{id, severity}]), duration_days (int|None),
    age_group (str|None), risk_factors (list[str]), vitals (dict|None with
    systolic/diastolic/heart_rate/spo2 — spo2 is not part of the feature vector per §4.5,
    only used by the rule engine)."""
    vec = np.zeros(_FEATURE_LENGTH, dtype=np.float32)
    offset = 0

    presence = np.zeros(N_SYMPTOMS, dtype=np.float32)
    severity = np.zeros(N_SYMPTOMS, dtype=np.float32)
    for s in assessment_input.get("symptoms", []):
        idx = SYMPTOM_INDEX.get(s["id"])
        if idx is None:
            continue  # unknown symptom id — caller's responsibility to validate against taxonomy
        presence[idx] = 1.0
        severity[idx] = float(s.get("severity", 0))
    vec[offset : offset + N_SYMPTOMS] = presence
    offset += N_SYMPTOMS
    vec[offset : offset + N_SYMPTOMS] = severity
    offset += N_SYMPTOMS

    duration_onehot = np.zeros(4, dtype=np.float32)
    duration_onehot[_duration_bucket_index(assessment_input.get("duration_days"))] = 1.0
    vec[offset : offset + 4] = duration_onehot
    offset += 4

    age_onehot = np.zeros(3, dtype=np.float32)
    age_group = assessment_input.get("age_group")
    if age_group in AGE_GROUPS:
        age_onehot[AGE_GROUPS.index(age_group)] = 1.0
    vec[offset : offset + 3] = age_onehot
    offset += 3

    risk_onehot = np.zeros(N_RISK_FACTORS, dtype=np.float32)
    for rf in assessment_input.get("risk_factors", []) or []:
        idx = RISK_FACTOR_INDEX.get(rf)
        if idx is not None:
            risk_onehot[idx] = 1.0
    vec[offset : offset + N_RISK_FACTORS] = risk_onehot
    offset += N_RISK_FACTORS

    vitals = assessment_input.get("vitals")
    if vitals:
        vec[offset] = _normalize(vitals.get("systolic"), SYSTOLIC_RANGE)
        vec[offset + 1] = _normalize(vitals.get("diastolic"), DIASTOLIC_RANGE)
        vec[offset + 2] = _normalize(vitals.get("heart_rate"), HR_RANGE)
        vec[offset + 3] = 1.0
    offset += 4

    return vec


def build_feature_matrix(cases: list[dict]) -> np.ndarray:
    return np.stack([build_features(c) for c in cases])
