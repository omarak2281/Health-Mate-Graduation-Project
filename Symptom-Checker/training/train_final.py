"""Phase 4 — train_final.py. LightGBM multiclass classifier — the actual replacement
candidate for the old CountVectorizer+MLPClassifier pipeline (plan §1.4/§2.2: replacement,
not patching, since the old pipeline architecturally cannot accept severity/duration/vitals).

Saves artifacts to Output/Production/ with a `_v2` suffix so the old `best_model.pkl` /
`vectorizer.pkl` / `model_metadata.json` are never overwritten — plan §6 Phase 4 DoD requires
this for rollback safety. `vectorizer.pkl` is untouched entirely; the new model doesn't use it
(plan §3.3: it's kept only for the free-text chat synonym fallback, unrelated to this classifier).

Run: python training/train_final.py   (from the Symptom-Checker/ directory)
"""
from __future__ import annotations

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import sklearn
from sklearn.metrics import accuracy_score, top_k_accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "training"))
from feature_engineering import SCHEMA_VERSION, build_feature_matrix, feature_names  # noqa: E402

DATASET_PATH = ROOT / "Data" / "cases" / "dataset.jsonl"
PRODUCTION_DIR = ROOT / "Output" / "Production"
MODEL_PATH = PRODUCTION_DIR / "best_model_v2.pkl"
LABEL_ENCODER_PATH = PRODUCTION_DIR / "label_encoder_v2.pkl"
METADATA_PATH = PRODUCTION_DIR / "model_metadata_v2.json"

RANDOM_STATE = 42
TEST_SIZE = 0.2


def load_dataset() -> list[dict]:
    with DATASET_PATH.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def dataset_hash() -> str:
    return hashlib.sha256(DATASET_PATH.read_bytes()).hexdigest()[:16]


def main() -> None:
    cases = load_dataset()
    X = build_feature_matrix(cases)
    y_raw = np.array([c["disease_id"] for c in cases])

    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(y_raw)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y
    )

    model = lgb.LGBMClassifier(
        objective="multiclass",
        num_class=len(label_encoder.classes_),
        n_estimators=300,
        learning_rate=0.05,
        random_state=RANDOM_STATE,
        verbosity=-1,
    )
    model.fit(X_train, y_train)

    proba = model.predict_proba(X_test)
    top1_pred = np.argmax(proba, axis=1)
    top1_acc = accuracy_score(y_test, top1_pred)
    top3_acc = top_k_accuracy_score(y_test, proba, k=3, labels=np.arange(len(label_encoder.classes_)))

    # COVID-19 predicted-share sanity check (plan §6 Phase 4 DoD)
    covid_idx = list(label_encoder.classes_).index("covid_19") if "covid_19" in label_encoder.classes_ else None
    covid_report = None
    if covid_idx is not None:
        true_share = float(np.mean(y_test == covid_idx))
        pred_share = float(np.mean(top1_pred == covid_idx))
        covid_report = {"true_share": true_share, "predicted_share": pred_share, "ratio": pred_share / true_share if true_share else None}

    PRODUCTION_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    joblib.dump(label_encoder, LABEL_ENCODER_PATH)

    metadata = {
        "schema_version": SCHEMA_VERSION,
        "model_type": "LGBMClassifier",
        "feature_list": feature_names(),
        "n_features": len(feature_names()),
        "class_labels": list(label_encoder.classes_),
        "training_date": datetime.now(timezone.utc).isoformat(),
        "dataset_hash": dataset_hash(),
        "dataset_path": str(DATASET_PATH.relative_to(ROOT)),
        "n_train_samples": int(len(X_train)),
        "n_test_samples": int(len(X_test)),
        "sklearn_version": sklearn.__version__,
        "lightgbm_version": lgb.__version__,
        "python_version": platform.python_version(),
        "evaluation": {
            "top1_accuracy": top1_acc,
            "top3_accuracy": top3_acc,
            "covid_19_share_check": covid_report,
            "caveat_old_baseline": (
                "The old notebook's reported 0.9034 accuracy (Standard MLP) is NOT a fair "
                "baseline for comparison — it was measured on the same random-subset synthetic "
                "generation method used to train it (narrow symptom-combination space, no "
                "held-out real-world distribution). This model's top1/top3 accuracy above is "
                "measured on a stratified held-out split of the new, richer structured dataset "
                "(severity/duration/age/risk-factors/vitals-aware) — see plan §1.4 and "
                "Plans/SYMPTOM_CHECKER_PROGRESS.md Phase 4 for the full methodology note."
            ),
        },
    }
    METADATA_PATH.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    print(f"top1_accuracy={top1_acc:.4f} top3_accuracy={top3_acc:.4f}")
    if covid_report:
        print(f"covid_19 true_share={covid_report['true_share']:.4f} predicted_share={covid_report['predicted_share']:.4f} ratio={covid_report['ratio']:.2f}")
    print(f"Saved model to {MODEL_PATH}")
    print(f"Saved metadata to {METADATA_PATH}")


if __name__ == "__main__":
    main()
