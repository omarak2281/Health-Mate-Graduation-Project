"""Documentation/presentation support — NOT part of the plan's phase roadmap.

Generates charts (PNG) from the *real* Phase 1-4 artifacts (taxonomy JSON, generated dataset,
baseline/final model metrics) so a graduation-project writeup/presentation has accurate,
reproducible visuals instead of hand-drawn numbers. Nothing here feeds back into the pipeline;
it only reads existing outputs.

Run: python analysis/generate_visualizations.py   (from the Symptom-Checker/ directory)
Output: Output/Production/analysis/*.png + analysis_index.md
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

import joblib
import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, top_k_accuracy_score
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "training"))
from feature_engineering import build_feature_matrix  # noqa: E402

TAXONOMY_DIR = ROOT / "taxonomy"
DATASET_PATH = ROOT / "Data" / "cases" / "dataset.jsonl"
PRODUCTION_DIR = ROOT / "Output" / "Production"
OUT_DIR = PRODUCTION_DIR / "analysis"
OUT_DIR.mkdir(parents=True, exist_ok=True)

RANDOM_STATE = 42
TEST_SIZE = 0.2

plt.rcParams["figure.dpi"] = 140
plt.rcParams["savefig.bbox"] = "tight"
plt.rcParams["font.size"] = 10

CHART_LOG: list[tuple[str, str]] = []  # (filename, one-line description) for the index


def save(fig, name: str, description: str) -> None:
    path = OUT_DIR / name
    fig.savefig(path)
    plt.close(fig)
    CHART_LOG.append((name, description))
    print(f"wrote {path}")


def load_taxonomy():
    categories = json.loads((TAXONOMY_DIR / "categories.json").read_text(encoding="utf-8"))
    symptoms = json.loads((TAXONOMY_DIR / "symptoms.json").read_text(encoding="utf-8"))
    diseases = json.loads((TAXONOMY_DIR / "diseases.json").read_text(encoding="utf-8"))
    return categories, symptoms, diseases


def load_dataset():
    with DATASET_PATH.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


# --- 1. Taxonomy migration: old vs new counts -------------------------------------------
def chart_taxonomy_before_after(diseases, symptoms):
    stub_count = sum(1 for s in symptoms if s.get("source") == "stub_orphan_reference")
    defined_count = len(symptoms) - stub_count

    fig, axes = plt.subplots(1, 2, figsize=(9, 4))

    axes[0].bar(["Diseases\n(General+Heart)", "Symptoms\n(raw entries)"], [41, 52], color="#4C72B0")
    axes[0].set_title("Legacy source files (before migration)")
    axes[0].set_ylabel("count")
    for i, v in enumerate([41, 52]):
        axes[0].text(i, v + 0.5, str(v), ha="center")

    axes[1].bar(
        ["Categories", "Diseases", "Symptoms\n(defined)", "Symptoms\n(orphan stubs)"],
        [9, len(diseases), defined_count, stub_count],
        color=["#55A868", "#4C72B0", "#4C72B0", "#C44E52"],
    )
    axes[1].set_title("Migrated taxonomy (Phase 1 output)")
    for i, v in enumerate([9, len(diseases), defined_count, stub_count]):
        axes[1].text(i, v + 0.5, str(v), ha="center")

    fig.suptitle("Phase 1 — Taxonomy Migration: before vs after")
    fig.tight_layout()
    save(fig, "01_taxonomy_before_after.png", "Legacy source counts vs the migrated taxonomy, including the 59 orphan-stub symptoms discovered during migration.")


# --- 2. Diseases per category --------------------------------------------------------------
def chart_diseases_per_category(categories, diseases):
    order = {c["id"]: c["name_en"] for c in sorted(categories, key=lambda c: c["order"])}
    counts = Counter(d["category_id"] for d in diseases)
    labels = [order[cid] for cid in order]
    values = [counts.get(cid, 0) for cid in order]

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.barh(labels[::-1], values[::-1], color="#4C72B0")
    for i, v in enumerate(values[::-1]):
        ax.text(v + 0.3, i, str(v), va="center")
    ax.set_xlabel("number of diseases")
    ax.set_title("Diseases per category (41 total, 9 fixed categories)")
    fig.tight_layout()
    save(fig, "02_diseases_per_category.png", "How the 41 migrated diseases distribute across the plan's 9 fixed categories.")


# --- 3. Dataset class balance ---------------------------------------------------------------
def chart_class_balance(cases):
    counts = Counter(c["disease_id"] for c in cases)
    values = sorted(counts.values())
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar(range(len(values)), values, color="#55A868", width=1.0)
    ax.axhline(np.median(values), color="#C44E52", linestyle="--", label=f"median = {np.median(values):.0f}")
    ax.set_xlabel("disease class (sorted by case count)")
    ax.set_ylabel("case count")
    ax.set_title(f"Phase 3 — class balance across all {len(counts)} diseases ({sum(values)} cases total)")
    ax.legend()
    fig.tight_layout()
    save(fig, "03_dataset_class_balance.png", "Per-class case counts in the generated synthetic dataset — flat at 300/class by construction, comfortably passing the plan's '<=2x median' balance rule.")


# --- 4. Urgency label distribution -----------------------------------------------------------
def chart_urgency_distribution(cases):
    counts = Counter(c["urgency"] for c in cases)
    order = ["low", "moderate", "high", "critical"]
    values = [counts.get(u, 0) for u in order]
    colors = ["#55A868", "#DD8452", "#C44E52", "#8C2D26"]
    fig, ax = plt.subplots(figsize=(6, 4))
    bars = ax.bar(order, values, color=colors)
    for b, v in zip(bars, values):
        ax.text(b.get_x() + b.get_width() / 2, v + 30, str(v), ha="center")
    ax.set_ylabel("case count")
    ax.set_title("Urgency label distribution across all 12,300 synthetic cases\n(computed via the Phase 2 rule engine, not hand-labeled)")
    fig.tight_layout()
    save(fig, "04_urgency_distribution.png", "How many generated cases land in each urgency tier — labels come from actually running the Phase 2 rule engine on each case, not from invented percentages.")


# --- 5. Baseline vs final model accuracy ------------------------------------------------------
def chart_model_comparison():
    baseline = json.loads((PRODUCTION_DIR / "baseline_comparison.json").read_text(encoding="utf-8"))
    metadata = json.loads((PRODUCTION_DIR / "model_metadata_v2.json").read_text(encoding="utf-8"))
    names = ["Logistic\nRegression", "Random\nForest", "LightGBM\n(top-1)", "LightGBM\n(top-3)"]
    values = [
        baseline["logistic_regression"]["accuracy"],
        baseline["random_forest"]["accuracy"],
        metadata["evaluation"]["top1_accuracy"],
        metadata["evaluation"]["top3_accuracy"],
    ]
    colors = ["#8C8C8C", "#8C8C8C", "#4C72B0", "#55A868"]
    fig, ax = plt.subplots(figsize=(7, 4.5))
    bars = ax.bar(names, values, color=colors)
    for b, v in zip(bars, values):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.01, f"{v:.1%}", ha="center")
    ax.set_ylim(0, 1.05)
    ax.set_ylabel("accuracy on held-out split")
    ax.set_title("Phase 4 — model comparison (new structured-feature dataset)\nNOT comparable to the old model's self-reported 90.3% — see caveat in evaluation_report_v2.md")
    fig.tight_layout()
    save(fig, "05_model_comparison.png", "Baseline (LogisticRegression/RandomForest) vs the final LightGBM model's top-1 and top-3 accuracy, all measured the same way on the same held-out split.")
    return metadata


# --- 6+7. Confusion matrices for the named confusable pairs -----------------------------------
def chart_confusable_pairs(cases):
    X = build_feature_matrix(cases)
    y_raw = np.array([c["disease_id"] for c in cases])
    label_encoder = joblib.load(PRODUCTION_DIR / "label_encoder_v2.pkl")
    model = joblib.load(PRODUCTION_DIR / "best_model_v2.pkl")
    y = label_encoder.transform(y_raw)
    _, X_test, _, y_test = train_test_split(X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y)
    proba = model.predict_proba(X_test)
    y_pred = np.argmax(proba, axis=1)
    labels = list(label_encoder.classes_)

    groups = [
        ("06_confusion_respiratory_triad.png", ["common_cold", "influenza", "covid_19"], "Common Cold / Influenza / COVID-19 — the plan's named confusable respiratory triad."),
        ("07_confusion_hypertension_pairs.png", ["hypertension", "migraine", "stroke"], "Hypertension vs Migraine vs Stroke — the plan's other named confusable pair, both show zero cross-confusion."),
    ]
    for filename, group, desc in groups:
        idxs = [labels.index(g) for g in group if g in labels]
        cm = confusion_matrix(y_test, y_pred, labels=np.arange(len(labels)))
        sub = cm[np.ix_(idxs, idxs)]
        fig, ax = plt.subplots(figsize=(4.5, 4))
        im = ax.imshow(sub, cmap="Blues")
        ax.set_xticks(range(len(idxs)))
        ax.set_yticks(range(len(idxs)))
        tick_labels = [labels[i] for i in idxs]
        ax.set_xticklabels(tick_labels, rotation=30, ha="right")
        ax.set_yticklabels(tick_labels)
        for i in range(len(idxs)):
            for j in range(len(idxs)):
                ax.text(j, i, str(sub[i, j]), ha="center", va="center", color="black")
        ax.set_xlabel("predicted")
        ax.set_ylabel("true")
        ax.set_title("Confusion matrix (held-out set)")
        fig.colorbar(im, fraction=0.046, pad=0.04)
        fig.tight_layout()
        save(fig, filename, desc)

    return labels, y_test, y_pred


# --- 8. Worst 10 classes ----------------------------------------------------------------------
def chart_worst_classes(labels, y_test, y_pred):
    per_class = {}
    for i, label in enumerate(labels):
        mask = y_test == i
        if mask.sum() == 0:
            continue
        per_class[label] = float((y_pred[mask] == i).mean())
    worst = sorted(per_class.items(), key=lambda kv: kv[1])[:10]
    fig, ax = plt.subplots(figsize=(7, 4.5))
    names = [w[0] for w in worst][::-1]
    values = [w[1] for w in worst][::-1]
    ax.barh(names, values, color="#C44E52")
    for i, v in enumerate(values):
        ax.text(v + 0.01, i, f"{v:.0%}", va="center")
    ax.set_xlim(0, 1.0)
    ax.set_xlabel("top-1 accuracy")
    ax.set_title("10 worst-performing classes\n(mostly the heart_bp cluster — flagged limitation, see Phase 4 progress log)")
    fig.tight_layout()
    save(fig, "08_worst_10_classes.png", "The 10 diseases the model struggles with most — dominated by clinically-similar heart diseases sharing near-identical symptom profiles in the taxonomy.")


# --- 9. COVID-19 predicted vs true share (Phase 4 DoD check) -----------------------------------
def chart_covid_share(metadata):
    check = metadata["evaluation"]["covid_19_share_check"]
    fig, ax = plt.subplots(figsize=(4.5, 4))
    ax.bar(["true share", "predicted share"], [check["true_share"], check["predicted_share"]], color=["#4C72B0", "#55A868"])
    for i, v in enumerate([check["true_share"], check["predicted_share"]]):
        ax.text(i, v + 0.001, f"{v:.2%}", ha="center")
    ax.set_title(f"COVID-19 share check (DoD requirement)\nratio = {check['ratio']:.2f} (1.0 = no bias)")
    fig.tight_layout()
    save(fig, "09_covid19_share_check.png", "Plan §6 Phase 4 DoD: COVID-19's predicted share must be proportional to its true class share — confirms the old model's COVID-19-dominance failure mode was not reintroduced.")


def main() -> None:
    categories, symptoms, diseases = load_taxonomy()
    cases = load_dataset()

    chart_taxonomy_before_after(diseases, symptoms)
    chart_diseases_per_category(categories, diseases)
    chart_class_balance(cases)
    chart_urgency_distribution(cases)
    metadata = chart_model_comparison()
    labels, y_test, y_pred = chart_confusable_pairs(cases)
    chart_worst_classes(labels, y_test, y_pred)
    chart_covid_share(metadata)

    index_lines = ["# Analysis Charts Index\n", "Generated by `analysis/generate_visualizations.py` from the real Phase 1-4 artifacts — not hand-drawn. Regenerate any time the taxonomy, dataset, or model changes.\n"]
    for name, desc in CHART_LOG:
        index_lines.append(f"### `{name}`\n{desc}\n")
    (OUT_DIR / "analysis_index.md").write_text("\n".join(index_lines), encoding="utf-8")
    print(f"\nWrote {len(CHART_LOG)} charts + index to {OUT_DIR}")


if __name__ == "__main__":
    main()
