"""Phase 4 — train_baseline.py. LogisticRegression + RandomForest on the new structured
features, for comparison only (plan §6 Phase 4) — train_final.py is the actual candidate
for production.

Run: python training/train_baseline.py   (from the Symptom-Checker/ directory)
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "training"))
from feature_engineering import build_feature_matrix  # noqa: E402

DATASET_PATH = ROOT / "Data" / "cases" / "dataset.jsonl"
OUT_PATH = ROOT / "Output" / "Production" / "baseline_comparison.json"
RANDOM_STATE = 42
TEST_SIZE = 0.2


def load_dataset() -> list[dict]:
    with DATASET_PATH.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def main() -> None:
    cases = load_dataset()
    X = build_feature_matrix(cases)
    y = np.array([c["disease_id"] for c in cases])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y
    )

    results = {}
    models = {
        "logistic_regression": LogisticRegression(max_iter=1000, random_state=RANDOM_STATE),
        "random_forest": RandomForestClassifier(n_estimators=200, random_state=RANDOM_STATE, n_jobs=-1),
    }
    for name, model in models.items():
        t0 = time.time()
        model.fit(X_train, y_train)
        train_seconds = time.time() - t0
        y_pred = model.predict(X_test)
        results[name] = {
            "accuracy": accuracy_score(y_test, y_pred),
            "precision_weighted": precision_score(y_test, y_pred, average="weighted", zero_division=0),
            "recall_weighted": recall_score(y_test, y_pred, average="weighted", zero_division=0),
            "f1_weighted": f1_score(y_test, y_pred, average="weighted", zero_division=0),
            "train_seconds": round(train_seconds, 2),
        }
        print(f"{name}: accuracy={results[name]['accuracy']:.4f} f1={results[name]['f1_weighted']:.4f}")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
