"""Phase 1 — Taxonomy Migration.

Reads the legacy dict-keyed-by-English-name JSON in Symptom-Checker/Data/{General,Heart}
and converts it into the stable-ID schema defined in
Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md §4 / Symptom-Checker/data_pipeline/schema.py.

Legacy .js files are intentionally ignored (the .json files are the source of truth).
This script never deletes or edits the legacy files — Data/General and Data/Heart stay
read-only historical/reference material per the plan's handoff instructions (§9.4).

Run: python migration/migrate_legacy_taxonomy.py   (from the Symptom-Checker/ directory)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from data_pipeline.schema import Category, Disease, Symptom, Taxonomy  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "Data"
TAXONOMY_DIR = ROOT / "taxonomy"
REPORT_PATH = ROOT / "migration" / "migration_report.md"

# ---------------------------------------------------------------------------
# 9 target categories (Plan §4.1)
# ---------------------------------------------------------------------------
CATEGORIES: list[Category] = [
    Category(id="heart_bp", name_en="Heart & Blood Pressure", name_ar="القلب وضغط الدم", order=1),
    Category(id="respiratory", name_en="Respiratory", name_ar="الجهاز التنفسي", order=2),
    Category(id="neurological", name_en="Neurological", name_ar="الجهاز العصبي", order=3),
    Category(id="digestive", name_en="Digestive", name_ar="الجهاز الهضمي", order=4),
    Category(id="general_fever", name_en="General & Fever", name_ar="أعراض عامة وحمى", order=5),
    Category(id="muscles_joints", name_en="Muscles & Joints", name_ar="العضلات والمفاصل", order=6),
    Category(id="skin", name_en="Skin", name_ar="الجلد", order=7),
    Category(id="urinary_kidney", name_en="Urinary & Kidney", name_ar="الجهاز البولي والكلى", order=8),
    Category(id="mental_health", name_en="Mental Health", name_ar="الصحة النفسية", order=9),
]
CATEGORY_IDS = {c.id for c in CATEGORIES}

# Old free-text `category` string -> new category id.
# Every mapping decision is logged to migration_report.md; anything not in this
# table is treated as unmapped and the build fails loudly rather than guessing.
CATEGORY_MAP: dict[str, str] = {
    # General diseases
    "Respiratory Infection": "respiratory",
    "Chronic Respiratory": "respiratory",
    "Gastrointestinal": "digestive",
    "Metabolic": "general_fever",  # best-fit: no dedicated metabolic/endocrine category exists in the fixed 9-set
    "Endocrine": "general_fever",  # same rationale as Metabolic
    "Musculoskeletal": "muscles_joints",
    "Neurological": "neurological",
    "Psychiatric": "mental_health",
    "Dermatological": "skin",
    "Infectious Disease": "respiratory",  # COVID-19 / Tuberculosis are primarily respiratory infections
    "Hematological": "general_fever",  # best-fit: Anemia, no dedicated blood-disorder category in the fixed 9-set
    "Liver Disease": "digestive",  # liver grouped under digestive system
    "Renal": "urinary_kidney",
    "Cardiovascular": "heart_bp",
    # Heart diseases
    "Coronary Artery Disease": "heart_bp",
    "Heart Failure": "heart_bp",
    "Valvular Heart Disease": "heart_bp",
    "Cardiomyopathy": "heart_bp",
    "Arrhythmia": "heart_bp",
    "Inflammatory Heart Disease": "heart_bp",
    "Vascular Disease": "heart_bp",
    "Congenital Heart Defect": "heart_bp",
}

# Minimum red-flag set mandated verbatim by Plan §4.2.
REQUIRED_RED_FLAG_NAMES = [
    "Chest Pain",
    "Shortness of Breath",
    "Sudden Numbness",
    "Trouble Speaking",
    "Loss of Balance",
    "Syncope",
    "Loss of Consciousness",
]
# Reasonable, explicitly-logged extension: "Sudden Loss of Consciousness" is an
# already-defined HeartSymptoms entry (severity=critical, category=Emergency) that is
# clearly the same clinical concept as "Loss of Consciousness" — flagged in the report,
# not silently assumed.
EXTRA_RED_FLAG_NAMES = ["Sudden Loss of Consciousness"]

# One unambiguous spelling-variant alias found during manual ID review (Plan §6 Phase 1
# task: "manually review the auto-generated ID list for correctness"). Everything else
# that doesn't resolve to an existing symptom key becomes its own stub entry instead of
# being silently merged into a look-alike.
MANUAL_ALIASES = {
    "coughing": "cough",
}

# Manual Arabic translations for the subset of orphan stub symptoms that are also
# plan-mandated red flags (REQUIRED_RED_FLAG_NAMES). These are the classic FAST
# stroke-warning-sign symptoms, so shipping them with no Arabic text at all (the default
# stub behaviour — see resolve_symptom_ref) is a real safety/usability gap for Arabic
# users doing a stroke-risk assessment, not just a cosmetic translation gap. Terms are
# standard clinical Arabic, not invented. This does NOT resolve the full 59-stub review
# the plan's risk register asks for — it only covers the ones that are red flags.
MANUAL_STUB_TRANSLATIONS: dict[str, dict[str, str]] = {
    "sudden_numbness": {
        "name_ar": "خدر مفاجئ",
        "description_ar": "تنميل أو خدر مفاجئ، غالبًا في جانب واحد من الجسم أو الوجه أو الذراع أو الساق.",
    },
    "trouble_speaking": {
        "name_ar": "صعوبة في الكلام",
        "description_ar": "صعوبة مفاجئة في الكلام أو فهمه، أو كلام غير واضح.",
    },
    "loss_of_balance": {
        "name_ar": "فقدان التوازن",
        "description_ar": "فقدان مفاجئ للتوازن أو التنسيق، أو صعوبة في المشي.",
    },
    "loss_of_consciousness": {
        "name_ar": "فقدان الوعي",
        "description_ar": "فقدان مفاجئ للوعي أو الإغماء الكامل.",
    },
}


def slugify(name: str) -> str:
    s = name.strip().lower()
    s = s.replace("/", "_")
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def main() -> None:
    general_diseases = load_json(DATA_DIR / "General" / "GeneralDiseases.json")
    heart_diseases = load_json(DATA_DIR / "Heart" / "HeartDiseases.json")
    general_symptoms = load_json(DATA_DIR / "General" / "GeneralSymptoms.json")
    heart_symptoms = load_json(DATA_DIR / "Heart" / "HeartSymptoms.json")

    report_lines: list[str] = []
    report_lines.append("# Taxonomy Migration Report (Phase 1)\n")
    report_lines.append(
        "Generated by `migration/migrate_legacy_taxonomy.py`. Source of truth: the 4 legacy "
        "`.json` files under `Data/General` and `Data/Heart` (`.js` variants ignored per the plan).\n"
    )

    # -- Symptoms: build canonical pool, deduping by slug across both files -----
    symptoms: dict[str, Symptom] = {}
    dedupe_log: list[str] = []
    conflict_log: list[str] = []

    def ingest_symptom_file(data: dict, source: str) -> None:
        for name, entry in data.items():
            sid = slugify(name)
            new = Symptom(
                id=sid,
                name_en=name,
                name_ar=entry.get("nameAr"),
                description_en=entry.get("description"),
                description_ar=entry.get("descriptionAr"),
                category_ids=[],
                red_flag=False,
                source=source,  # type: ignore[arg-type]
            )
            if sid in symptoms:
                existing = symptoms[sid]
                dedupe_log.append(f"- `{sid}` — merged duplicate definition from **{source}** (already defined via **{existing.source}**)")
                if existing.description_en != new.description_en:
                    conflict_log.append(
                        f"- `{sid}`: kept **{existing.source}** description "
                        f"(\"{existing.description_en}\"); discarded **{source}** variant "
                        f"(\"{new.description_en}\") — logged here for manual review, no data lost."
                    )
                # keep the first-seen (General is ingested first) description/name_ar
                continue
            symptoms[sid] = new

    ingest_symptom_file(general_symptoms, "general")
    ingest_symptom_file(heart_symptoms, "heart")

    # -- Diseases: build + resolve related_symptom_ids, creating stubs for orphans --
    diseases: list[Disease] = []
    category_mismatch_log: list[str] = []
    orphan_stub_log: list[str] = []
    orphan_seen: dict[str, str] = {}  # slug -> original text (first seen)

    def resolve_symptom_ref(raw_name: str, disease_name: str) -> str:
        slug = slugify(raw_name)
        alias_target = MANUAL_ALIASES.get(slug)
        if alias_target:
            return alias_target
        if slug in symptoms:
            return slug
        if slug not in orphan_seen:
            orphan_seen[slug] = raw_name
            manual = MANUAL_STUB_TRANSLATIONS.get(slug)
            symptoms[slug] = Symptom(
                id=slug,
                name_en=raw_name,
                name_ar=manual["name_ar"] if manual else None,
                description_en=None,
                description_ar=manual["description_ar"] if manual else None,
                category_ids=[],
                red_flag=False,
                needs_translation=manual is None,
                source="stub_orphan_reference",
            )
            if manual:
                orphan_stub_log.append(
                    f"- `{slug}` (\"{raw_name}\") — referenced by **{disease_name}** but has no own "
                    f"entry in GeneralSymptoms.json/HeartSymptoms.json. Created as a stub symptom, "
                    f"but manually translated (`needs_translation=false`) because it is also one of "
                    f"the plan-mandated red-flag symptoms — see MANUAL_STUB_TRANSLATIONS."
                )
            else:
                orphan_stub_log.append(
                    f"- `{slug}` (\"{raw_name}\") — referenced by **{disease_name}** but has no own "
                    f"entry in GeneralSymptoms.json/HeartSymptoms.json. Created as a stub symptom "
                    f"(no `name_ar`, `needs_translation=true`) so the disease-symptom link is not "
                    f"silently dropped. Needs manual translation + clinical review before Phase 3."
                )
        return slug

    def ingest_disease_file(data: dict, source_label: str) -> None:
        for name, entry in data.items():
            did = slugify(name)
            old_category = entry.get("category", "")
            new_category = CATEGORY_MAP.get(old_category)
            if new_category is None:
                category_mismatch_log.append(
                    f"- `{did}` (\"{name}\", {source_label}): old category \"{old_category}\" has "
                    f"NO mapping in CATEGORY_MAP — build aborted, add an explicit mapping."
                )
                continue
            related = [resolve_symptom_ref(s, name) for s in entry.get("relatedSymptoms", [])]
            # de-dup while preserving order (a disease can't list the same symptom twice post-slug)
            seen = set()
            related_unique = []
            for r in related:
                if r not in seen:
                    seen.add(r)
                    related_unique.append(r)
            diseases.append(
                Disease(
                    id=did,
                    name_en=name,
                    name_ar=entry.get("nameAr", ""),
                    description_en=entry.get("description", ""),
                    description_ar=entry.get("descriptionAr", ""),
                    category_id=new_category,
                    default_urgency=entry.get("severity", "moderate"),
                    related_symptom_ids=related_unique,
                )
            )

    ingest_disease_file(general_diseases, "General")
    ingest_disease_file(heart_diseases, "Heart")

    if category_mismatch_log:
        report_lines.append("## ABORTED — unmapped categories\n")
        report_lines.extend(category_mismatch_log)
        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_PATH.write_text("\n".join(report_lines), encoding="utf-8")
        raise SystemExit(f"Aborting: {len(category_mismatch_log)} unmapped categories. See {REPORT_PATH}")

    # -- Derive each symptom's category_ids from the diseases that reference it --
    symptom_to_categories: dict[str, set[str]] = {sid: set() for sid in symptoms}
    for d in diseases:
        for sid in d.related_symptom_ids:
            symptom_to_categories[sid].add(d.category_id)
    for sid, cats in symptom_to_categories.items():
        symptoms[sid].category_ids = sorted(cats)

    unused_symptoms = [sid for sid, cats in symptom_to_categories.items() if not cats]

    # -- Red flags -----------------------------------------------------------
    red_flag_ids = set()
    red_flag_resolution_log: list[str] = []
    for rname in REQUIRED_RED_FLAG_NAMES + EXTRA_RED_FLAG_NAMES:
        slug = slugify(rname)
        if slug in symptoms:
            symptoms[slug].red_flag = True
            red_flag_ids.add(slug)
            red_flag_resolution_log.append(f"- `{slug}` (\"{rname}\") — found, `red_flag=true` set.")
        else:
            red_flag_resolution_log.append(
                f"- `{slug}` (\"{rname}\") — **NOT FOUND** in migrated symptom pool even as a stub. "
                f"This should not happen; investigate."
            )

    headache_variants = [sid for sid in symptoms if "headache" in sid or "head_pain" in sid]

    # -- Assemble + validate ---------------------------------------------------
    taxonomy = Taxonomy(categories=CATEGORIES, symptoms=list(symptoms.values()), diseases=diseases)

    TAXONOMY_DIR.mkdir(parents=True, exist_ok=True)
    (TAXONOMY_DIR / "categories.json").write_text(
        json.dumps([c.model_dump() for c in taxonomy.categories], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (TAXONOMY_DIR / "symptoms.json").write_text(
        json.dumps([s.model_dump() for s in taxonomy.symptoms], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (TAXONOMY_DIR / "diseases.json").write_text(
        json.dumps([d.model_dump() for d in taxonomy.diseases], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    # -- Report ---------------------------------------------------------------
    stub_count = sum(1 for s in symptoms.values() if s.source == "stub_orphan_reference")
    defined_count = len(symptoms) - stub_count

    report_lines.append("## Counts\n")
    report_lines.append(f"- Diseases migrated: **{len(diseases)}** (General {len(general_diseases)} + Heart {len(heart_diseases)})")
    report_lines.append(f"- Symptoms defined in source files: {len(general_symptoms)} (General) + {len(heart_symptoms)} (Heart) = {len(general_symptoms) + len(heart_symptoms)} raw entries")
    report_lines.append(f"- Symptoms after dedup of directly-defined entries: **{defined_count}**")
    report_lines.append(f"- Orphan stub symptoms created (referenced by a disease but never defined as their own entry): **{stub_count}**")
    report_lines.append(f"- Total symptoms in migrated taxonomy: **{len(symptoms)}**")
    report_lines.append(f"- Categories: **{len(CATEGORIES)}** (fixed set per plan §4.1)\n")

    report_lines.append("## Deviation from the plan's §1.2 overlap claim\n")
    report_lines.append(
        "The plan states the General/Heart symptom files overlap on `Chest Pain`, "
        "`Shortness of Breath`, `Fatigue`, `Dizziness`. Actual inspection of the JSON keys "
        "(not `relatedSymptoms`/`relatedDiseases` values, the top-level symptom entries "
        "themselves) shows the overlapping **keys** are `Chest Pain`, `Shortness of Breath`, "
        f"and `Fever` ({len(dedupe_log)} dedup merge(s) performed — see below). `Fatigue` and "
        "`Dizziness` are only defined in `GeneralSymptoms.json`; `HeartSymptoms.json` references "
        "them inside disease `relatedSymptoms` lists but never defines them as its own top-level "
        "symptom entry, so there was nothing to deduplicate for those two names. This has been "
        "written back into `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` §1.2 per the plan's own "
        "handoff instruction #5 (deviations must be recorded in the plan document).\n"
    )

    report_lines.append("## Symptom key dedup log (General/Heart direct overlaps)\n")
    report_lines.extend(dedupe_log or ["- (none)"])
    report_lines.append("")
    if conflict_log:
        report_lines.append("### Description conflicts on dedup (kept General's text, Heart's discarded)\n")
        report_lines.extend(conflict_log)
        report_lines.append("")

    report_lines.append("## Category mapping table (old free-text `category` -> new category id)\n")
    report_lines.append("| Old category | New category id |")
    report_lines.append("|---|---|")
    for old, new in CATEGORY_MAP.items():
        report_lines.append(f"| {old} | `{new}` |")
    report_lines.append("")
    report_lines.append(
        "Ambiguous best-fit decisions (no dedicated category exists in the fixed 9-set): "
        "`Metabolic` -> `general_fever`, `Endocrine` -> `general_fever`, `Hematological` -> "
        "`general_fever`, `Liver Disease` -> `digestive`, `Infectious Disease` -> `respiratory` "
        "(both diseases in that bucket — COVID-19, Tuberculosis — are primarily respiratory). "
        "Flagged per plan §6 Phase 1 instruction to log rather than silently guess.\n"
    )

    manually_translated_stub_count = sum(
        1 for s in symptoms.values() if s.source == "stub_orphan_reference" and not s.needs_translation
    )
    report_lines.append(f"## Orphan symptom stubs ({stub_count})\n")
    report_lines.append(
        "Symptom names referenced in a disease's `relatedSymptoms` array that have no matching "
        "top-level entry in either `GeneralSymptoms.json` or `HeartSymptoms.json`. This is a data "
        "gap in the legacy source, not introduced by migration. Each was kept as a stub (Arabic "
        "translation and description left empty, `needs_translation=true`) rather than silently "
        "dropping the disease-symptom relationship. **Action required before Phase 3**: a human "
        "should review this list, supply `name_ar`/descriptions, and decide whether any stub is "
        "actually a duplicate of an existing symptom under different wording (e.g. `swelling_in_legs` "
        "vs. `edema`/`peripheral_edema` — several candidates below look related but were NOT merged "
        "automatically, per the plan's instruction not to guess medical equivalence).\n\n"
        f"**Exception ({manually_translated_stub_count} of {stub_count}, added during post-Phase-12 review):** "
        "the orphan stubs that are also plan-mandated red-flag symptoms "
        "(`sudden_numbness`, `trouble_speaking`, `loss_of_balance`, `loss_of_consciousness` — the "
        "classic FAST stroke warning signs) were manually translated via `MANUAL_STUB_TRANSLATIONS` "
        "and no longer carry `needs_translation=true`, because shipping the app's most safety-critical "
        "symptom set with zero Arabic text was judged too risky to leave for a later, unscheduled "
        "clinical-review pass. The remaining stubs are unaffected and still need the review described "
        "above.\n"
    )
    report_lines.extend(orphan_stub_log or ["- (none)"])
    report_lines.append("")

    report_lines.append("## One manual spelling-alias applied\n")
    report_lines.append("- `\"Coughing\"` -> `cough` (same concept as the already-defined `Cough` symptom; used by Asthma).\n")

    report_lines.append("## Red-flag resolution (plan §4.2 minimum set + one logged extension)\n")
    report_lines.extend(red_flag_resolution_log)
    report_lines.append(
        "\nExtension: `sudden_loss_of_consciousness` (from HeartSymptoms.json's own "
        "\"Sudden Loss of Consciousness\" entry, severity=critical, category=Emergency) was also "
        "flagged `red_flag=true` in addition to the literal `loss_of_consciousness` stub, since "
        "it is clearly the same clinical concept and already carried critical/Emergency metadata "
        "in the source data.\n"
    )
    report_lines.append(
        f"No sudden/severe headache variant beyond the base set was found in the migrated data "
        f"(headache-related ids present: {', '.join(sorted(headache_variants)) or '(none)'}) — "
        f"none of these represent a \"sudden/severe\" onset variant, so none were marked as a "
        f"red flag. This is a decision, not an omission — flagged per plan §9.3.\n"
    )

    if unused_symptoms:
        report_lines.append(f"## Symptoms with empty `category_ids` ({len(unused_symptoms)})\n")
        report_lines.append(
            "These symptoms are defined but never appear in any disease's `related_symptom_ids`, "
            "so no category could be derived for them. They will not surface when filtering the "
            "wizard's Step 2 by category until either a disease references them or they get a "
            "manual category assignment.\n"
        )
        report_lines.extend(f"- `{sid}` (\"{symptoms[sid].name_en}\")" for sid in sorted(unused_symptoms))
        report_lines.append("")

    report_lines.append("## Disease-level `severity` -> `default_urgency`\n")
    report_lines.append(
        "Copied verbatim (not recomputed) per plan §1.3/§4.3's field-meaning clarification. "
        "The old per-symptom `severity` free-text field (a static per-symptom label, distinct "
        "from both `default_urgency` and the new dynamic per-assessment severity) is intentionally "
        "**not** migrated — the new `Symptom` schema has no equivalent field; it is superseded by "
        "the `red_flag` boolean plus the dynamic 0-4 severity entered per assessment.\n"
    )

    report_lines.append("## DoD check against plan §6 Phase 1\n")
    report_lines.append(f"- `taxonomy/categories.json`: {len(CATEGORIES)} entries (target: 9) — {'OK' if len(CATEGORIES) == 9 else 'MISMATCH'}")
    report_lines.append(f"- `taxonomy/diseases.json`: {len(diseases)} entries (target: 41) — {'OK' if len(diseases) == 41 else 'MISMATCH'}")
    report_lines.append(
        f"- `taxonomy/symptoms.json`: {defined_count} directly-defined entries after dedup "
        f"(plan expected ~48-52 from merging 4 known overlaps; actual overlap was 3 keys, see "
        f"deviation note above, so the directly-defined count lands close to but not identical to "
        f"that estimate) + {stub_count} orphan stubs = {len(symptoms)} total."
    )
    report_lines.append("- All entries validate against `data_pipeline/schema.py` Pydantic models — OK (script would have raised otherwise).")

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(report_lines), encoding="utf-8")

    print(f"Wrote {len(taxonomy.categories)} categories, {len(taxonomy.symptoms)} symptoms, {len(taxonomy.diseases)} diseases to {TAXONOMY_DIR}")
    print(f"Report: {REPORT_PATH}")


if __name__ == "__main__":
    main()
