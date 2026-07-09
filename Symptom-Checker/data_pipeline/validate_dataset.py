"""Phase 3 — validate_dataset.py.

Schema-validates every case in Data/cases/dataset.jsonl against TrainingCase, cross-checks
disease_id/symptom ids against the migrated taxonomy, and fails the build if any class is
more than 2x the median class count (guards against reintroducing the old COVID-19-dominance
pattern from the notebook's uneven sampling — plan §6 Phase 3 DoD).

Run: python data_pipeline/validate_dataset.py   (from the Symptom-Checker/ directory)
Exit code 0 = pass, 1 = fail.
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path
from statistics import median

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from data_pipeline.schema import Taxonomy, TrainingCase  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TAXONOMY_DIR = ROOT / "taxonomy"
DATASET_PATH = ROOT / "Data" / "cases" / "dataset.jsonl"

MAX_CLASS_RATIO = 2.0


def load_taxonomy() -> Taxonomy:
    categories = json.loads((TAXONOMY_DIR / "categories.json").read_text(encoding="utf-8"))
    symptoms = json.loads((TAXONOMY_DIR / "symptoms.json").read_text(encoding="utf-8"))
    diseases = json.loads((TAXONOMY_DIR / "diseases.json").read_text(encoding="utf-8"))
    return Taxonomy(categories=categories, symptoms=symptoms, diseases=diseases)


def main() -> int:
    taxonomy = load_taxonomy()
    disease_ids = {d.id for d in taxonomy.diseases}
    symptom_ids = {s.id for s in taxonomy.symptoms}

    errors: list[str] = []
    cases: list[TrainingCase] = []

    with DATASET_PATH.open("r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                case = TrainingCase.model_validate_json(line)
            except Exception as exc:  # noqa: BLE001
                errors.append(f"line {lineno}: schema validation failed: {exc}")
                continue
            if case.disease_id not in disease_ids:
                errors.append(f"line {lineno} ({case.case_id}): unknown disease_id '{case.disease_id}'")
            for s in case.symptoms:
                if s.id not in symptom_ids:
                    errors.append(f"line {lineno} ({case.case_id}): unknown symptom id '{s.id}'")
            cases.append(case)

    if errors:
        print(f"FAIL: {len(errors)} schema/reference errors")
        for e in errors[:50]:
            print(f"  - {e}")
        if len(errors) > 50:
            print(f"  ... and {len(errors) - 50} more")
        return 1

    class_counts = Counter(c.disease_id for c in cases)
    missing_classes = disease_ids - set(class_counts)
    if missing_classes:
        print(f"FAIL: {len(missing_classes)} diseases have zero cases: {sorted(missing_classes)}")
        return 1

    med = median(class_counts.values())
    over_ratio = {
        did: count for did, count in class_counts.items() if count > MAX_CLASS_RATIO * med
    }
    if over_ratio:
        print(f"FAIL: {len(over_ratio)} classes exceed {MAX_CLASS_RATIO}x the median ({med}):")
        for did, count in sorted(over_ratio.items(), key=lambda kv: -kv[1]):
            print(f"  - {did}: {count} ({count / med:.2f}x median)")
        return 1

    print(f"PASS: {len(cases)} cases, {len(class_counts)} classes, median class size {med}, "
          f"max ratio {max(class_counts.values()) / med:.2f}x")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
