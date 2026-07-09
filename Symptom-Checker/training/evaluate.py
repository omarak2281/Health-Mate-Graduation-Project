"""Phase 4 — evaluate.py. Full confusion matrix + confusable-pair table for the trained
LightGBM model (train_final.py), reported against the same held-out split methodology, plus
the explicit §1.4 baseline caveat restated per plan §6 Phase 4 DoD/§8 risk register.

Run: python training/evaluate.py   (from the Symptom-Checker/ directory, after train_final.py)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import joblib
import numpy as np
from sklearn.metrics import confusion_matrix, top_k_accuracy_score
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "training"))
from feature_engineering import build_feature_matrix  # noqa: E402

DATASET_PATH = ROOT / "Data" / "cases" / "dataset.jsonl"
PRODUCTION_DIR = ROOT / "Output" / "Production"
MODEL_PATH = PRODUCTION_DIR / "best_model_v2.pkl"
LABEL_ENCODER_PATH = PRODUCTION_DIR / "label_encoder_v2.pkl"
REPORT_PATH = PRODUCTION_DIR / "evaluation_report_v2.md"

RANDOM_STATE = 42
TEST_SIZE = 0.2

# Same confusable pairs named throughout plan §1.5/§3/§6 Phase 3/Phase 4.
CONFUSABLE_GROUPS = [
    ["common_cold", "influenza", "covid_19"],
    ["hypertension", "migraine"],
    ["hypertension", "stroke"],
]


def load_dataset() -> list[dict]:
    with DATASET_PATH.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def main() -> None:
    cases = load_dataset()
    X = build_feature_matrix(cases)
    y_raw = np.array([c["disease_id"] for c in cases])

    model = joblib.load(MODEL_PATH)
    label_encoder = joblib.load(LABEL_ENCODER_PATH)
    y = label_encoder.transform(y_raw)

    _, X_test, _, y_test = train_test_split(X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y)

    proba = model.predict_proba(X_test)
    y_pred = np.argmax(proba, axis=1)
    top3_acc = top_k_accuracy_score(y_test, proba, k=3, labels=np.arange(len(label_encoder.classes_)))

    labels = list(label_encoder.classes_)
    cm = confusion_matrix(y_test, y_pred, labels=np.arange(len(labels)))

    lines = ["# Evaluation Report (Phase 4)\n"]
    lines.append(
        "**Baseline caveat (plan §1.4/§8, restated per DoD requirement):** the old notebook's "
        "reported 0.9034 accuracy (Standard MLP, `CountVectorizer`) was measured on the same "
        "random-subset synthetic dataset it was trained on (narrow symptom-combination space, "
        "no severity/duration/vitals input) — it is not a fair baseline and should never be "
        "quoted as a real-world number. The metrics below are measured on a stratified 80/20 "
        "held-out split of the new structured dataset instead.\n"
    )
    lines.append(f"- Top-1 accuracy: **{(y_pred == y_test).mean():.4f}**")
    lines.append(f"- Top-3 accuracy: **{top3_acc:.4f}**\n")

    lines.append("## Confusable-pair confusion table\n")
    for group in CONFUSABLE_GROUPS:
        idxs = [labels.index(g) for g in group if g in labels]
        if len(idxs) < 2:
            continue
        lines.append(f"### {' vs '.join(group)}\n")
        lines.append("| true \\ pred | " + " | ".join(labels[i] for i in idxs) + " |")
        lines.append("|---" * (len(idxs) + 1) + "|")
        for i in idxs:
            row = [str(int(cm[i, j])) for j in idxs]
            lines.append(f"| {labels[i]} | " + " | ".join(row) + " |")
        lines.append("")

    per_class_accuracy = {}
    for i, label in enumerate(labels):
        mask = y_test == i
        if mask.sum() == 0:
            continue
        per_class_accuracy[label] = float((y_pred[mask] == i).mean())
    worst = sorted(per_class_accuracy.items(), key=lambda kv: kv[1])[:10]
    lines.append("## 10 worst-performing classes (top-1 accuracy)\n")
    for label, acc in worst:
        lines.append(f"- `{label}`: {acc:.3f}")

    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"top1={(y_pred == y_test).mean():.4f} top3={top3_acc:.4f}")
    print(f"Wrote {REPORT_PATH}")


if __name__ == "__main__":
    main()
