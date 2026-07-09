"""Phase 3 — Structured Dataset Generation.

Generates synthetic training cases (plan §4.4 schema) from the Phase 1 migrated taxonomy.
Each disease's related_symptom_ids becomes a symptom-probability profile (earlier-listed
symptoms = higher inclusion probability); each case then independently samples severity,
duration, age group, optional risk factors and vitals around that profile. This replaces the
old notebook's plain "random subset of relatedSymptoms, no severity/duration" method (plan
§1.4) with materially richer cases built from the same underlying clinical associations.

`urgency` per case is computed by running the case through the actual Phase 2 rule engine
(Back-end/app/domain/rules_engine) rather than invented separately in this script — the
dataset must never encode an urgency label that disagrees with the rule engine that will
gate real assessments in production.

Run: python data_pipeline/generate_structured_cases.py   (from the Symptom-Checker/ directory)
"""
from __future__ import annotations

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT.parent / "Back-end"))

from data_pipeline.constants import RISK_FACTOR_POOL  # noqa: E402
from data_pipeline.schema import CaseSymptom, CaseVitals, Taxonomy, TrainingCase  # noqa: E402
from app.domain.entities.assessment import AssessmentInput, SelectedSymptom, Vitals  # noqa: E402
from app.domain.entities.red_flag import RedFlag  # noqa: E402
from app.domain.rules_engine.red_flag_rules import evaluate_red_flags  # noqa: E402
from app.domain.rules_engine.urgency_rules import determine_urgency  # noqa: E402

TAXONOMY_DIR = ROOT / "taxonomy"
OUT_DIR = ROOT / "Data" / "cases"
OUT_PATH = OUT_DIR / "dataset.jsonl"
REPORT_PATH = OUT_DIR / "dataset_report.md"

SEED = 42
CASES_PER_DISEASE = 300  # comfortably above the plan's ">=250/class floor" (old notebook baseline)

# --- Risk-factor vocabulary ------------------------------------------------------------
# Plan gap, flagged rather than guessed: §4.5 says N_risk_factors is "derived from the
# migrated taxonomy", but Phase 1's taxonomy schema (categories/symptoms/diseases) has no
# risk-factor list anywhere — it was never specified. The plan's own two worked examples
# (§4.4 "risk_factors": ["asthma"], §6.1 "known_conditions": ["hypertension"]) both reuse
# existing disease ids as risk-factor tokens, so that convention is followed here: the pool
# (in data_pipeline/constants.py, shared with Phase 4's feature engineering so the two never
# drift apart) is a small, explicitly-chosen subset of already-migrated chronic disease ids
# that plausibly act as comorbidities, not a new invented taxonomy.

# --- Confusable-pair differentiation, per plan §6 Phase 3 -------------------------------
# Common Cold / Influenza / COVID-19 share overlapping symptoms in the migrated taxonomy
# (fever, cough, fatigue, headache/sore_throat), so duration + severity + the COVID-specific
# stub symptom are used as explicit differentiators. Hypertension vs Migraine and Hypertension
# vs Stroke need no extra help — their migrated related_symptom_ids sets do not overlap at all
# (checked directly against taxonomy/diseases.json), so natural separation already exists;
# Hypertension additionally gets a high probability of carrying elevated vitals, which neither
# Migraine nor Stroke cases receive, reinforcing the separation.
DURATION_OVERRIDES_DAYS: dict[str, tuple[int, int]] = {
    "common_cold": (2, 5),
    "influenza": (3, 7),
    "covid_19": (5, 14),
}
SEVERITY_BIAS: dict[str, tuple[int, int]] = {
    # (min, max) severity sampled for non-red-flag symptoms of this disease
    "common_cold": (1, 2),
    "influenza": (2, 4),
    "covid_19": (1, 3),
}
SYMPTOM_PROBABILITY_OVERRIDES: dict[str, dict[str, float]] = {
    # COVID-19's pathognomonic differentiator boosted well above its default list-position probability
    "covid_19": {"loss_of_taste_smell": 0.85},
}
VITALS_PROBABILITY_OVERRIDES: dict[str, float] = {
    "hypertension": 0.75,
}


def load_taxonomy() -> Taxonomy:
    categories = json.loads((TAXONOMY_DIR / "categories.json").read_text(encoding="utf-8"))
    symptoms = json.loads((TAXONOMY_DIR / "symptoms.json").read_text(encoding="utf-8"))
    diseases = json.loads((TAXONOMY_DIR / "diseases.json").read_text(encoding="utf-8"))
    return Taxonomy(categories=categories, symptoms=symptoms, diseases=diseases)


def symptom_probability_profile(related_ids: list[str], disease_id: str) -> dict[str, float]:
    profile: dict[str, float] = {}
    for i, sid in enumerate(related_ids):
        profile[sid] = max(0.35, 0.85 - 0.1 * i)
    profile.update(SYMPTOM_PROBABILITY_OVERRIDES.get(disease_id, {}))
    return profile


def sample_age_group(rng: random.Random, disease_id: str) -> str:
    # Osteoarthritis/Rheumatoid Arthritis skew elderly; otherwise a general adult-heavy population.
    if disease_id in ("osteoarthritis", "rheumatoid_arthritis"):
        weights = {"child": 0.02, "adult": 0.38, "elderly": 0.60}
    else:
        weights = {"child": 0.15, "adult": 0.65, "elderly": 0.20}
    return rng.choices(list(weights), weights=list(weights.values()), k=1)[0]


def sample_vitals(rng: random.Random, disease_id: str, category_id: str) -> CaseVitals | None:
    base_prob = 0.6 if category_id == "heart_bp" else 0.1
    prob = VITALS_PROBABILITY_OVERRIDES.get(disease_id, base_prob)
    if rng.random() > prob:
        return None
    if disease_id == "hypertension":
        systolic = rng.randint(135, 175)
        diastolic = rng.randint(85, 105)
    elif category_id == "heart_bp":
        systolic = rng.randint(110, 160)
        diastolic = rng.randint(70, 100)
    else:
        systolic = rng.randint(105, 130)
        diastolic = rng.randint(65, 85)
    heart_rate = rng.randint(60, 110)
    spo2 = round(rng.uniform(93.0, 99.5), 1)
    return CaseVitals(systolic=systolic, diastolic=diastolic, heart_rate=heart_rate, spo2=spo2)


def generate_case(
    rng: random.Random,
    case_id: str,
    disease: dict,
    symptoms_by_id: dict[str, dict],
) -> TrainingCase:
    related_ids = disease["related_symptom_ids"]
    profile = symptom_probability_profile(related_ids, disease["id"])

    included: list[str] = [sid for sid in related_ids if rng.random() < profile.get(sid, 0.5)]
    if not included and related_ids:
        included = [related_ids[0]]  # guarantee at least one symptom for a non-empty disease

    sev_min, sev_max = SEVERITY_BIAS.get(disease["id"], (1, 3))
    case_symptoms: list[CaseSymptom] = []
    for sid in included:
        sym = symptoms_by_id[sid]
        if sym["red_flag"]:
            # Sampled 1-4, not 2-4: forcing every included red-flag symptom to severity>=2 would
            # make every case that happens to include one automatically trip the Phase 2 red-flag
            # rule, which skews diseases like Hypertension/Pneumonia (whose related_symptom_ids
            # legitimately include chest_pain/shortness_of_breath) toward an unrealistically high
            # share of "critical"/"high" labels. Allowing severity 1 lets a red-flag symptom present
            # mildly and stay sub-threshold, which is also clinically plausible.
            severity = rng.randint(1, 4)
        else:
            severity = rng.randint(sev_min, sev_max)
        case_symptoms.append(CaseSymptom(id=sid, severity=severity))

    dur_min, dur_max = DURATION_OVERRIDES_DAYS.get(disease["id"], (1, 10))
    duration_days = rng.randint(dur_min, dur_max)

    age_group = sample_age_group(rng, disease["id"])

    risk_pool = [r for r in RISK_FACTOR_POOL if r != disease["id"]]
    risk_factors: list[str] = []
    if rng.random() < 0.2 and risk_pool:
        risk_factors = rng.sample(risk_pool, k=rng.randint(1, min(2, len(risk_pool))))

    vitals = sample_vitals(rng, disease["id"], disease["category_id"])

    selected_symptoms = [
        SelectedSymptom(id=cs.id, severity=cs.severity, red_flag=symptoms_by_id[cs.id]["red_flag"])
        for cs in case_symptoms
    ]
    assessment = AssessmentInput(
        category_id=disease["category_id"],
        symptoms=selected_symptoms,
        duration_days=duration_days,
        age_group=age_group,
        known_conditions=risk_factors,
        vitals=Vitals(**vitals.model_dump()) if vitals else None,
    )
    red_flags: list[RedFlag] = evaluate_red_flags(selected_symptoms)
    urgency = determine_urgency(assessment, red_flags)

    return TrainingCase(
        case_id=case_id,
        disease_id=disease["id"],
        symptoms=case_symptoms,
        duration_days=duration_days,
        age_group=age_group,
        risk_factors=risk_factors,
        vitals=vitals,
        urgency=urgency,
        source="synthetic_v1",
    )


def main() -> None:
    taxonomy = load_taxonomy()
    symptoms_by_id = {s.id: s.model_dump() for s in taxonomy.symptoms}
    rng = random.Random(SEED)

    cases: list[TrainingCase] = []
    counter = 0
    for disease in taxonomy.diseases:
        disease_dict = disease.model_dump()
        for _ in range(CASES_PER_DISEASE):
            counter += 1
            case_id = f"c{counter:05d}"
            cases.append(generate_case(rng, case_id, disease_dict, symptoms_by_id))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8") as f:
        for case in cases:
            f.write(case.model_dump_json())
            f.write("\n")

    # --- report --------------------------------------------------------------
    from collections import Counter

    disease_counts = Counter(c.disease_id for c in cases)
    urgency_counts = Counter(c.urgency for c in cases)

    lines = ["# Structured Dataset Generation Report (Phase 3)\n"]
    lines.append(f"Generated by `data_pipeline/generate_structured_cases.py`, seed={SEED}.\n")
    lines.append(f"- Total cases: **{len(cases)}**")
    lines.append(f"- Diseases covered: **{len(disease_counts)}** (target 41)")
    lines.append(f"- Cases per disease: fixed at **{CASES_PER_DISEASE}** (uniform by construction, well above the plan's >=250/class floor)\n")
    lines.append("## Urgency label distribution (computed via the Phase 2 rule engine, not invented)\n")
    for level in ("low", "moderate", "high", "critical"):
        lines.append(f"- {level}: {urgency_counts.get(level, 0)}")
    lines.append("")
    lines.append("## Risk-factor vocabulary gap (flagged, see plan §4.5 vs Phase 1 output)\n")
    lines.append(
        "Plan §4.5 says `N_risk_factors` is derived from the migrated taxonomy, but Phase 1's "
        "taxonomy schema (categories/symptoms/diseases) never defines a risk-factor list. "
        f"Used the plan's own two literal examples (`\"hypertension\"`, `\"asthma\"`) as the seed "
        f"and extended to a small pool of already-migrated chronic disease ids: "
        f"`{RISK_FACTOR_POOL}`. This needs product/clinical review before Phase 4 treats it as final.\n"
    )
    high_urgency_share_by_disease: dict[str, float] = {}
    for did in disease_counts:
        d_cases = [c for c in cases if c.disease_id == did]
        share = sum(1 for c in d_cases if c.urgency in ("high", "critical")) / len(d_cases)
        high_urgency_share_by_disease[did] = share
    skewed = {did: s for did, s in high_urgency_share_by_disease.items() if s > 0.7}
    if skewed:
        lines.append("## Known limitation: urgency skew for red-flag-heavy diseases\n")
        lines.append(
            "Diseases whose `related_symptom_ids` include one or more red-flag symptoms (e.g. "
            "`chest_pain`, `shortness_of_breath`) end up with a higher share of `high`/`critical` "
            "labels than their `default_urgency` alone would suggest, because the rule engine "
            "escalates urgency whenever a sampled red-flag symptom lands at severity>=2. This is "
            "clinically defensible per-case (a red-flag symptom at meaningful severity IS urgent) "
            "but the aggregate distribution below may not match true epidemiological prevalence for "
            "these diagnoses (most real-world Hypertension presentations are not emergencies). "
            "Flagged for clinical/product review before Phase 4 trains on this as ground truth — "
            "not silently shipped as-is.\n"
        )
        for did, s in sorted(skewed.items(), key=lambda kv: -kv[1]):
            lines.append(f"- `{did}`: {s:.0%} of cases labeled high/critical")
        lines.append("")

    lines.append("## Confusable-pair differentiation applied\n")
    lines.append(
        "- `common_cold` / `influenza` / `covid_19`: distinct duration_days ranges "
        f"({DURATION_OVERRIDES_DAYS}), distinct severity ranges ({SEVERITY_BIAS}), and "
        "`covid_19` has `loss_of_taste_smell` boosted to 85% inclusion probability as its "
        "pathognomonic differentiator.\n"
        "- `hypertension` vs `migraine` / `stroke`: checked directly against `taxonomy/diseases.json` "
        "— these diseases' `related_symptom_ids` sets do not overlap at all, so they are already "
        "naturally separated by symptom identity; `hypertension` additionally carries elevated "
        "vitals in 75% of its cases (vs a 10% background rate elsewhere), which `migraine`/`stroke` "
        "never receive.\n"
    )
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {len(cases)} cases to {OUT_PATH}")
    print(f"Report: {REPORT_PATH}")


if __name__ == "__main__":
    main()
