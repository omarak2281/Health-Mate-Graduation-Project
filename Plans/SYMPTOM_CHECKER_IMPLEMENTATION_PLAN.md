# Symptom Checker — Professional Implementation Plan (v2, audit-grounded)

Status: **Approved for execution**
Scope: Full end-to-end (Data → ML → Backend → Flutter)
Model strategy: **Hybrid — Deterministic Red-Flag Rule Engine + Structured ML Classifier**
Audience: Written for direct hand-off to an implementation model. Every phase references **real, existing files and real numbers** from the current codebase audit — nothing here is generic or assumed. Do not skip a phase's Definition of Done (DoD) to move to the next phase.

---

## 0. Decisions Locked In

| Decision | Choice | Why |
|---|---|---|
| Rollout style | Full end-to-end plan | "Immediate fixes" are folded into the correct phases (mainly Phase 5) instead of being a throwaway pass that gets rewritten later. |
| Model strategy | **Hybrid (Rule Engine + Structured ML)** | Emergency detection (chest pain, stroke signs, syncope) must be deterministic, not left to a classifier's confidence score. ML only ranks candidate diseases; it never decides urgency alone. |
| Dataset | **Migrated + regenerated**, not written from zero | The existing `Data/General/` and `Data/Heart/` JSON already contain real bilingual medical content (41 diseases, ~52 raw symptom entries with overlap). We **migrate** this into the new stable-ID schema first, then generate structured synthetic cases from the migrated taxonomy — we do not throw away the existing medical content. |
| Current production model | **Deprecated, not patched** | Current model is `CountVectorizer(181 features)` + `MLPClassifier(hidden=(100,))` trained on space-joined symptom text with **no** severity/duration/vitals input. It cannot accept the new structured input at all — it must be replaced, not fine-tuned. |
| `train_model.py` vs `Disease_Prediction_Model.ipynb` | **Notebook is the reference; both are retired** | `train_model.py` references `Data/Heart/heart_training_data.json` and `Data/General/general_training_data.json`, which do not exist in the current tree — it is dead/broken code. The notebook is the real source of current production artifacts, but it too generates data by naive random-subset sampling of `relatedSymptoms` (see §1.4), which is not sufficient going forward. Both are superseded by the new `Symptom-Checker/training/` pipeline in Phase 4. Do not build on top of either. |
| LLM explanation layer (Option C) | Deferred to Phase 9 | Additive only, never load-bearing for diagnosis. |

---

## 1. Current State Baseline (Audit Results — already collected, do not re-derive)

This section is the ground truth for every later phase. All later phases reference these exact numbers/paths.

### 1.1 Current folder layout
```
Symptom-Checker/
  Data/
    General/
      GeneralDiseases.json   GeneralDiseases.js
      GeneralSymptoms.json   GeneralSymptoms.js
    Heart/
      HeartDiseases.json     HeartDiseases.js
      HeartSymptoms.json     HeartSymptoms.js
  Output/
    Production/
      best_model.pkl          # MLPClassifier(hidden_layer_sizes=(100,), max_iter=100, random_state=42)
      vectorizer.pkl           # CountVectorizer, 181 features  ⚠ NOT TfidfVectorizer despite train_model.py
      model_metadata.json      # contains symptom_translations, disease_translations, categories only
    Models_Archive/
      AdaBoost.pkl  Decision_Tree.pkl  Deep_Neural_Network.pkl  Extra_Trees.pkl
      Gradient_Boosting.pkl  K-Neighbors.pkl  Logistic_Regression.pkl
      Random_Forest.pkl  Standard_MLP.pkl  SVM.pkl  Wide_Neural_Network.pkl
    Reports/
      Model_Comparison_Report.pdf
  Disease_Prediction_Model.ipynb   # ← real source of current production artifacts
  train_model.py                    # ← broken/stale, references missing data files
  app.py
  README.md
  requirements.txt
```

### 1.2 Current data counts (exact)
- Diseases: `GeneralDiseases.json` = 23, `HeartDiseases.json` = 18 → **41 total classes**.
- Symptoms: `GeneralSymptoms.json` = 34 entries, `HeartSymptoms.json` = 18 entries.
- **Overlap exists** between General and Heart symptom files for at least: `Chest Pain`, `Shortness of Breath`, `Fatigue`, `Dizziness` — these must be **deduplicated into one canonical symptom ID** during migration (Phase 1), not kept as two separate entries.
- **[Correction, logged during Phase 1 execution — see `Symptom-Checker/migration/migration_report.md`]** The actual overlapping top-level symptom **keys** between `GeneralSymptoms.json` and `HeartSymptoms.json` are `Chest Pain`, `Shortness of Breath`, and `Fever` (3 keys, 3 dedup merges performed). `Fatigue` and `Dizziness` are only ever defined as top-level entries in `GeneralSymptoms.json`; `HeartSymptoms.json` references them inside disease `relatedSymptoms` arrays but never defines them as its own symptom entry, so there was nothing to deduplicate for those two names — they map onto the General-defined entry automatically since both files share one slugified ID namespace. Separately, migration surfaced a **much larger data gap** than this section anticipated: 59 symptom names referenced by `relatedSymptoms` across the 41 diseases have no defining entry in either symptoms file at all (e.g. `Bloating`, `Increased Thirst`, `Sudden Numbness`, `Trouble Speaking`, `Nosebleeds`, `Radiating Pain to Left Arm`...). These were migrated as stub `Symptom` entries (`needs_translation: true`, no `name_ar`/description) rather than silently dropped — full list in the migration report. This pushed the total migrated symptom count to 108 (49 directly-defined + 59 stubs) instead of the ~48-52 estimated in §6 Phase 1 DoD.

### 1.3 Current data shape (dict-keyed-by-English-name — must be transformed)
Disease entry (example, verbatim structure):
```json
{
  "Hypertension": {
    "nameAr": "ارتفاع ضغط الدم",
    "description": "Long-term force of the blood against your artery walls is high",
    "descriptionAr": "...",
    "severity": "moderate",
    "category": "Cardiovascular",
    "relatedSymptoms": ["Headache", "Shortness of Breath", "Nosebleeds", "Dizziness", "Chest Pain"]
  }
}
```
Symptom entry follows the same pattern with `relatedDiseases` instead of `relatedSymptoms`.

**Important field-meaning clarification (do not conflate these two "severity" concepts):**
- The existing disease-level `severity` field (e.g. `"moderate"`) is a **static per-disease default** → this becomes `default_urgency` in the new schema.
- The **new** per-symptom, per-assessment `severity` (0–4 scale, entered by the patient at Step 3 of the wizard) is a completely different, dynamic concept → this is `SelectedSymptom.severity` in the new schema. Never merge these two fields.

Known gaps in current data (confirmed by audit): no stable `id`, key is the English display name, no `name_en` field, no red-flag flag, no synonym list, no follow-up question set, no differentiating features between similar diseases.

### 1.4 Current model & training pipeline (confirmed by audit)
```
selected symptoms
   → joined into one space-separated text string (e.g. "Fever Cough Fatigue")
   → CountVectorizer.transform()
   → MLPClassifier.predict()   [single class, no probabilities surfaced]
   → backend returns ONE disease name
```
- Training data generation (in the notebook): `samples_per_disease = 250` synthetic samples per disease, built by taking **random subsets of each disease's `relatedSymptoms`** → 41 × 250 = **10,250 samples total**.
- Reported notebook metrics (Standard MLP, champion model): Accuracy 0.9034, Precision 0.9103, Recall 0.9034, F1 0.9044 — **measured only on this synthetic random-subset dataset**, so this is not a valid real-world baseline; it likely overstates true performance because train/test subsets are drawn from the same narrow symptom-combination space.
- The model receives **none** of: severity, duration, age, sex, chronic disease, medications, vitals, red-flag answers.
- `requirements.txt` pins `scikit-learn>=1.7.2`. **Constraint carried into Phase 4:** the new training environment and the backend runtime environment must use the same pinned scikit-learn version, or model loading will throw `InconsistentVersionWarning`/fail silently on subtle behavior differences.

### 1.5 Confirmed weak points (drives Phase 3 & 4 design)
- Single top-1 prediction, no confidence surfaced to the user.
- No severity/duration/red-flag input at all.
- Confuses clinically similar respiratory diseases (Common Cold / Influenza / COVID-19) — confirmed pattern, not a hypothesis.
- English names used as dict keys and as the only stable identifier.
- Backend (`ai_service.py`, `ai.py`) and Flutter have contract mismatches — see §1.6.

### 1.6 Confirmed backend/Flutter mismatches (fix in Phase 5, not before)
1. Flutter's `analyzeSymptoms` sends `language` in the request **body**; backend expects `lang` as a **query parameter**. → Standardize on `lang` query param everywhere.
2. Flutter's `SymptomCheckerPage` reads `severity` and `advice` from the **top level** of the response; backend actually nests them inside `disease_info`. → New response DTO puts them top-level (see §6.1).
3. Flutter's `getAvailableSymptoms` does not pass `lang` at all → symptom names default to English regardless of app language.
4. Backend chat sessions are **in-memory only** → lost on every restart, not persisted per user (fixed in Phase 6).
5. Arabic text is mojibake/encoding-broken in multiple files (list in Phase 10).

---

## 2. Recommended Model Strategy — Detail

### 2.1 Two independent, composable components
```
 Structured        ┌─────────────────────────┐
 Assessment   ───▶ │   Red-Flag Rule Engine   │ → deterministic, pure functions
 Input              │  (domain/rules_engine)   │ → red_flags[], urgency_floor
                    └─────────────────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  ML Disease Classifier   │ → top_predictions[] (id + confidence)
                    │ (infrastructure/ml)      │
                    └─────────────────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │   Assessment Aggregator  │ → urgency = max(rule_urgency, ml-derived)
                    │  (application/use_cases) │
                    └─────────────────────────┘
```
Rule of composition: the rule engine can only **escalate** urgency, never suppress it; the ML output can never **downgrade** a red-flag-triggered urgency.

### 2.2 Why the current model can't just be "improved"
It is architecturally text-based (`CountVectorizer` over a joined string). There is no way to feed severity/duration/vitals into a `CountVectorizer` pipeline without abandoning it. Replacement, not patching, is the only correct path — confirmed by the audit, not a preference.

### 2.3 Where Option C (LLM) plugs in later (Phase 9, optional)
Only to phrase already-decided structured output into natural language. Never a diagnosis source.

---

## 3. Target Architecture

### 3.1 Backend (FastAPI) — Clean Architecture layers
```
Back-end/app/
├── domain/
│   ├── entities/          symptom.py  disease.py  category.py  assessment.py  red_flag.py
│   ├── value_objects/      urgency.py  age_group.py
│   ├── rules_engine/        red_flag_rules.py  urgency_rules.py  bp_rules.py
│   └── interfaces/          disease_classifier.py  taxonomy_repository.py
│                             assessment_repository.py  chat_session_repository.py
├── application/
│   ├── use_cases/           run_assessment.py  get_categories.py  get_available_symptoms.py
│   │                         start_chat_from_assessment.py  run_bp_triage.py
│   └── dto/                 assessment_dto.py  chat_dto.py
├── infrastructure/
│   ├── ml/                  structured_feature_builder.py  disease_classifier_impl.py  model_registry.py
│   ├── persistence/         postgres_taxonomy_repository.py  postgres_assessment_repository.py
│   │                         redis_chat_session_repository.py
│   └── localization/        translation_loader.py
├── api/v1/
│   ├── ai.py                 # thin controllers only, ≤15 lines per handler
│   └── schemas/              assessment_schemas.py  category_schemas.py
└── core/                     config.py  di.py
```
`ai_service.py` is retired; its logic is redistributed into the layers above — nothing stays as a single god-file.

### 3.2 Frontend (Flutter) — matches existing Clean Architecture convention
```
Front-end/health_mate_app/lib/features/symptom_checker/
├── domain/       entities/  repositories/ (abstract)  usecases/
├── data/         models/  datasources/  repositories/ (impl)
└── presentation/
    ├── pages/     category_selection_page.dart  symptom_selection_page.dart
    │              symptom_severity_page.dart  followup_questions_page.dart
    │              assessment_result_page.dart
    ├── providers/ category_provider.dart  assessment_flow_provider.dart  assessment_result_provider.dart
    └── widgets/   severity_selector.dart  urgency_badge.dart  red_flag_banner.dart
```
Existing `ai_symptom_chat_page.dart` and `symptom_checker_page.dart` remain and are reached from `assessment_result_page.dart` via "Open AI Chat", now seeded with context instead of starting empty.

### 3.3 ML pipeline (offline, inside `Symptom-Checker/`)
```
Symptom-Checker/
├── migration/
│   ├── migrate_legacy_taxonomy.py   # Phase 1 — reads existing Data/General, Data/Heart
│   └── migration_report.md          # generated: mapping table old-name → new-id, dedupe log
├── data_pipeline/
│   ├── schema.py
│   ├── generate_structured_cases.py
│   └── validate_dataset.py
├── training/
│   ├── feature_engineering.py
│   ├── train_baseline.py            # LogisticRegression / RandomForest, for comparison only
│   ├── train_final.py               # LightGBM/XGBoost, top-3 + confidence
│   └── evaluate.py                  # confusion matrix incl. confusable-pair report
└── Output/Production/
    ├── model_metadata.json          # schema_version, feature_list, training_date, dataset_hash
    ├── best_model.pkl
    └── vectorizer.pkl               # kept ONLY for free-text chat synonym extraction fallback
```
`Disease_Prediction_Model.ipynb`, `train_model.py`, and the current `Data/General/*`, `Data/Heart/*` files are **not deleted** — they remain as historical/reference material, but nothing new is built on top of them after Phase 1 completes.

---

## 4. Data Schema Specifications

### 4.1 Category (new — did not exist before)
```json
{"id": "heart_bp", "name_en": "Heart & Blood Pressure", "name_ar": "القلب وضغط الدم", "order": 1}
```
Minimum category set per source doc: `heart_bp`, `respiratory`, `neurological`, `digestive`, `general_fever`, `muscles_joints`, `skin`, `urinary_kidney`, `mental_health`. Map every existing disease's current `category` string (e.g. `"Cardiovascular"`) to one of these during migration — build the mapping table explicitly in `migration_report.md`, do not silently guess.

### 4.2 Symptom (migrated from `GeneralSymptoms.json` + `HeartSymptoms.json`, deduplicated)
```json
{
  "id": "chest_pain",
  "name_en": "Chest Pain",
  "name_ar": "ألم في الصدر",
  "description_en": "Pain or pressure in the chest area.",
  "description_ar": "ألم أو ضغط في منطقة الصدر.",
  "category_ids": ["heart_bp", "general_fever"],
  "red_flag": true,
  "synonyms_en": ["chest pain", "chest pressure", "chest tightness"],
  "synonyms_ar": ["ألم صدر", "ضغط في الصدر", "وجع صدري"]
}
```
**Design decision (resolving the General/Heart overlap found in §1.2):** a symptom gets **one canonical ID** but a **list** of `category_ids` (not a single `category_id`), so `Chest Pain` shows up correctly when Step 2 of the wizard filters symptoms by category, without duplicating the symptom record. Set `red_flag: true` at minimum on: `chest_pain`, `shortness_of_breath`, `sudden_numbness`, `trouble_speaking`, `loss_of_balance`, `syncope`, `loss_of_consciousness`, and any sudden/severe headache variant already present in the migrated data.

### 4.3 Disease (migrated from `GeneralDiseases.json` + `HeartDiseases.json`)
```json
{
  "id": "hypertension",
  "name_en": "Hypertension",
  "name_ar": "ارتفاع ضغط الدم",
  "description_en": "Long-term force of the blood against your artery walls is high",
  "description_ar": "...",
  "category_id": "heart_bp",
  "default_urgency": "moderate",
  "related_symptom_ids": ["headache", "shortness_of_breath", "nosebleeds", "dizziness", "chest_pain"]
}
```
`default_urgency` is copied directly from the old `severity` field (renamed, not recomputed) — see the field-meaning clarification in §1.3.

### 4.4 Structured training case
```json
{
  "case_id": "c00001",
  "disease_id": "influenza",
  "symptoms": [
    {"id": "fever", "severity": 3},
    {"id": "cough", "severity": 2},
    {"id": "sore_throat", "severity": 1},
    {"id": "fatigue", "severity": 3}
  ],
  "duration_days": 2,
  "age_group": "adult",
  "risk_factors": ["asthma"],
  "vitals": null,
  "urgency": "moderate",
  "source": "synthetic_v1"
}
```
`source` values: `synthetic_v1` (newly generated), `reformatted_legacy` (derived from the old random-subset method but reformatted — use sparingly, only if useful for coverage), `clinical_reviewed`. Absent symptoms are simply not listed (no `severity: 0` entries).

### 4.5 Feature vector (single shared implementation, used by both training and inference)
```
[ multi-hot symptom presence            (N_symptoms) ]
[ severity per symptom, 0 if absent     (N_symptoms) ]
[ duration_days bucketed: <1,1-3,4-7,>7 (4) ]
[ age_group one-hot: child/adult/elderly (3) ]
[ risk_factors multi-hot                (N_risk_factors) ]
[ vitals: systolic_norm, diastolic_norm, hr_norm, vitals_present_flag (4) ]
```
`N_symptoms` and `N_risk_factors` are derived from the **migrated** taxonomy (Phase 1 output), not invented — after migration you will know the exact final symptom count. `model_metadata.json` persists the exact ordered feature list at training time; inference refuses to run against a mismatched `schema_version`.

---

## 5. Full Phase Roadmap

| # | Phase | Depends on | Primary output |
|---|---|---|---|
| 1 | Taxonomy Migration (not audit — audit is done, see §1) | — | `taxonomy/categories.json`, `symptoms.json`, `diseases.json` + `migration_report.md` |
| 2 | Red-Flag & Urgency Rule Engine | 1 | `domain/rules_engine/*` + 100% branch-coverage tests |
| 3 | Structured Dataset Generation | 1 | `Data/cases/dataset.jsonl`, balanced, validated |
| 4 | ML Feature Engineering & Training | 2, 3 | `best_model.pkl`, `model_metadata.json`, evaluation report vs the §1.4 baseline |
| 5 | Backend Clean-Architecture Refactor | 2, 4 | New layered backend, fixes all §1.6 mismatches |
| 6 | Persistence Layer (assessments/chat) | 5 | Postgres tables + Redis session store |
| 7 | Flutter Guided Wizard | 5 | New 5-step wizard wired to backend |
| 8 | BP Feature Integration Hook | 5, 7 | High-BP → auto-open `heart_bp` category, prefilled vitals |
| 9 | Optional LLM Phrasing Layer | 5 | Natural-language `patient_message`/`caregiver_summary` |
| 10 | Localization & Encoding Audit | 1–9 | UTF-8 clean, full ar/en parity |
| 11 | Testing & QA | all | Bilingual test matrix passed |
| 12 | Rollout | 11 | Feature-flagged release |

---

## 6. Detailed Phase Specifications

### Phase 1 — Taxonomy Migration
**Tasks**
1. Write `migration/migrate_legacy_taxonomy.py`:
   - Read `Data/General/GeneralDiseases.json`, `Data/Heart/HeartDiseases.json`, `Data/General/GeneralSymptoms.json`, `Data/Heart/HeartSymptoms.json`. Ignore the `.js` variants — the JSON files are the source of truth per the "avoid duplicated truth across `.json`/`.js`" principle.
   - Convert each dict-keyed-by-name entry into a schema-4.2/4.3 object; generate `id` via slugification of the English name (e.g. `"Shortness of Breath"` → `shortness_of_breath`), then **manually review** the auto-generated ID list for correctness (do not trust slugification blindly for medical terms).
   - **Deduplicate** the 4 confirmed overlapping symptoms (`Chest Pain`, `Shortness of Breath`, `Fatigue`, `Dizziness`) into single canonical entries with multi-category `category_ids` per §4.2. Scan for any *other* overlaps beyond these 4 (the audit found these by inspection, not exhaustively) and log any found in `migration_report.md`.
   - Map every distinct old `category` string (`"Cardiovascular"`, etc.) to the new 9-category set in §4.1; if any old category doesn't map cleanly, flag it in the report rather than guessing.
   - Rename disease-level `severity` → `default_urgency` (verbatim value copy, per §1.3's clarification).
   - Add `red_flag: false` by default to every symptom, then explicitly set `red_flag: true` on the minimum set listed in §4.2.
2. Output `migration_report.md`: old-name → new-id mapping table for all 41 diseases and all deduplicated symptoms, plus a list of any ambiguous/manual decisions made.

**DoD:** `taxonomy/categories.json` (9 entries), `taxonomy/symptoms.json` (deduplicated, expected ~48–52 unique entries after merging the 4 known overlaps), `taxonomy/diseases.json` (41 entries) all validate against the Pydantic schema in `data_pipeline/schema.py`. `migration_report.md` accounts for all 41 disease names and all symptom names from the 4 source files with no silent drops.

---

### Phase 2 — Red-Flag & Urgency Rule Engine
**Tasks**
- `red_flag_rules.py`: `evaluate_red_flags(selected_symptoms) -> list[RedFlag]`. Triggers when `symptom.red_flag == True` and `severity >= 2`, except `syncope`/`loss_of_consciousness` which trigger at any `severity >= 1`.
- `urgency_rules.py`: combines red flags + vitals into `Urgency`:
  - `critical`: any red flag severity ≥3, OR SBP≥180/DBP≥120/SpO2<90.
  - `high`: any red flag present, OR SBP≥140/DBP≥90/SpO2<94.
  - `moderate`: no red flag but ≥2 symptoms severity ≥2, OR known hypertension + elevated BP.
  - `low`: everything else.
- `bp_rules.py`: BP threshold constants shared with the BP feature (reuse — do not duplicate numbers in two files; the BP feature's alert logic and this rule engine must import from the same constants module).

**DoD:** pytest suite covering every branch (target 100% branch coverage on this module — it is the safety-critical piece). Explicitly test the exact combinations named in both source docs: "chest pain + shortness of breath = urgent", "fainting = emergency", "stroke symptoms (sudden numbness / trouble speaking / loss of balance) = emergency".

**[Execution note, Phase 2 complete — see `Plans/SYMPTOM_CHECKER_PROGRESS.md` for full detail]** Built at `Back-end/app/domain/{entities,value_objects,rules_engine}/*` (ahead of the Phase 5 backend refactor — the domain layer has zero framework dependencies per §7 coding standards, so it can exist standalone and Phase 5 just wires the rest of Clean Architecture around it). 43 pytest tests, 100% branch coverage confirmed via `pytest-cov` on all three rule-engine modules. Two gaps flagged rather than guessed:
1. Neither this plan nor `BP_FLOW_CALIBRATION_HANDOFF.md` gives a numeric "elevated BP range" for the `urgency_rules` moderate-tier rule ("known hypertension + elevated BP"). Implemented using the standard AHA Elevated/Stage-1-hypertension boundary (SBP≥130 or DBP≥80) as `SBP_ELEVATED`/`DBP_ELEVATED` in `bp_rules.py`, explicitly commented as **not sourced from either doc** and needing clinical/product sign-off before ship.
2. `BP_FLOW_CALIBRATION_HANDOFF.md`'s "Medium: HR>100, HR<50" alert tier is not mapped into this plan's own moderate-urgency formula (which only defines two triggers: ≥2 symptoms severity≥2, or known-hypertension+elevated-BP). `HR_HIGH`/`HR_LOW` constants exist in `bp_rules.py` for Phase 8's direct BP alert use but are intentionally not consumed by `determine_urgency` — implemented literally per this plan's spec, discrepancy with the handoff doc logged for reconciliation.

---

### Phase 3 — Structured Dataset Generation
**Tasks**
- `generate_structured_cases.py`: for each of the 41 migrated diseases, generate synthetic cases from a **symptom-probability profile** derived from its `related_symptom_ids` (from the migrated taxonomy, not invented), sampling severity/duration/age_group/risk_factors with controlled randomness (fixed seed). This replaces the old "random subset of related symptoms with no severity/duration" method — same starting relationship data, materially richer generation.
- Target balance: since the old notebook used 250/class uniformly, keep that as the floor (≥250/class) unless time is constrained, but explicitly **boost** the distinguishing symptom combinations for the confusable pairs already named in the audit: `Common Cold` vs `Influenza` vs `COVID-19` (respiratory), `Hypertension` vs `Migraine`, `Hypertension` vs stroke-red-flag diseases.
- `validate_dataset.py`: schema conformance + fails the build if any class is >2x the median class count (guards against reintroducing the COVID-19 dominance pattern).

**DoD:** `Data/cases/dataset.jsonl` passes `validate_dataset.py`; class-balance report shows no class more than 2x the median; the confusable-pair symptom combinations are demonstrably present with differentiating features (e.g. COVID-19 cases include duration/exposure-style differentiators where the old data didn't).

---

### Phase 4 — ML Feature Engineering & Training
**Tasks**
- `feature_engineering.py`: single `build_features(assessment_input) -> np.ndarray`, imported by both training and backend inference (no duplicate implementation).
- `train_baseline.py`: Logistic Regression + Random Forest on the new structured features, for comparison.
- `train_final.py`: LightGBM/XGBoost multiclass, `predict_proba` → top 3 with confidence.
- `evaluate.py`: full confusion matrix + explicit confusable-pair table (same pairs as Phase 3) to demonstrate improvement **against the §1.4 baseline numbers** (0.9034 accuracy on random-subset synthetic data — report the new model's equivalent metric on a proper held-out split, and explain the methodology difference since the old number is not a fair baseline in the first place).
- Pin the exact scikit-learn version from `requirements.txt` (`>=1.7.2`, use the same resolved version) in both the training environment and the backend runtime to avoid the `InconsistentVersionWarning` risk flagged in §1.4.
- Export `model_metadata.json`: `schema_version`, ordered `feature_list`, training date, dataset hash, evaluation summary — richer than the old metadata which only had translation dicts.

**DoD:** Top-3 accuracy (true label within top 3) reported on a proper held-out split, not the old random-subset methodology. COVID-19-style predicted share is proportional to its true class share. Model artifacts saved to `Symptom-Checker/Output/Production/` alongside (not overwriting until validated) the current ones for rollback safety.

**[Execution note, Phase 4 complete — full detail in `Plans/SYMPTOM_CHECKER_PROGRESS.md`]** Top-1 accuracy 0.8581, top-3 accuracy 0.9549 on a stratified 80/20 held-out split (LightGBM, 300 estimators). COVID-19 predicted/true share ratio 0.98 — DoD satisfied. Artifacts saved with a `_v2` suffix (`best_model_v2.pkl`, `label_encoder_v2.pkl`, `model_metadata_v2.json`) alongside the untouched originals. Two things surfaced during execution:
1. **Version drift, exactly the risk this plan's own §1.4/§8 flags**: `lightgbm==4.5.0` (the version available when this phase started) calls a `scikit-learn` `check_X_y()` argument that `scikit-learn` 1.7+ removed. Fixed by bumping to `lightgbm>=4.6.0` and `scikit-learn>=1.9.0` (from the previous `>=1.7.2` pin) in `Symptom-Checker/requirements.txt`, with the reasoning documented inline in that file. `Back-end/requirements.txt` will need the matching `scikit-learn` pin once Phase 5 wires model loading into the backend, or the exact failure this plan warned about will reproduce there.
2. **The heart-disease cluster is the model's real weak spot**, not the respiratory triad this plan explicitly asked to boost. `common_cold`/`influenza`/`covid_19` and `hypertension`/`migraine`/`stroke` all show **zero** cross-confusion in the held-out confusion matrix (the differentiation work in Phase 3 fully worked). But 9 of the 10 worst-performing classes are heart_bp diseases with heavily overlapping `related_symptom_ids` and no differentiating boost applied in Phase 3 (`myocarditis` 35% accuracy, `hypertrophic_cardiomyopathy` 40%, `coronary_artery_disease` 52%...) — this wasn't explicitly required by the plan's Phase 3 spec (which only named the respiratory triad and the two hypertension pairs) but is a natural extension of the same idea. Flagged for a possible Phase 3 revisit, not silently left unreported.

---

### Phase 5 — Backend Clean-Architecture Refactor
**Tasks**
- Build the layered structure from §3.1, retiring `ai_service.py` as a single file.
- Implement endpoints: `GET /api/v1/ai/categories?lang=`, `GET /api/v1/ai/available-symptoms?category_id=&lang=`, `POST /api/v1/ai/assessment?lang=`, `POST /api/v1/ai/chat/from-assessment?lang=`, `POST /api/v1/ai/bp-triage?lang=`.
- Fix all 5 confirmed mismatches from §1.6 explicitly — each one is a checklist item, not optional cleanup:
  1. `lang` as query param everywhere (update Flutter's `analyzeSymptoms` too).
  2. Response DTO returns `urgency`/`recommended_action_text` (renamed from `severity`/`advice`) at **top level**, not nested in `disease_info`.
  3. `available-symptoms` accepts and uses `lang`.
  4. (Persistence — done in Phase 6.)
  5. (Encoding — done in Phase 10.)
- Return top 3 predictions from every assessment-producing endpoint. Apply red-flag rules **before** exposing model output, and red flags must still appear even if the ML call fails (see §6.1 error contract).

**DoD:** `/docs` shows all 5 endpoints fully specified. Contract tests pass for `lang=ar` and `lang=en` on every endpoint, including a regression test that specifically checks `lang` arrives as query param (not body) and that `urgency`/`recommended_action_text` are top-level in the response.

**[Execution note, Phase 5 complete — full detail in `Plans/SYMPTOM_CHECKER_PROGRESS.md`]** Built additively: none of the 10 pre-existing `/ai/*` routes were modified, so `AiSymptomChatPage`/`SymptomCheckerPage` keep working unchanged, per §3.2. 13 contract tests pass (en+ar for every new endpoint, the two literal §1.6 regression tests, an ML-failure-degrades-gracefully test, and the `no_symptoms_selected` error-contract test), and a real end-to-end smoke test (real taxonomy JSON + real Phase 4 model, not fakes) confirms the whole chain works. One deliberate path deviation and one confirmed cross-cutting fix, both logged:
1. **Path deviation:** the plan's literal `GET /available-symptoms?category_id=&lang=` reuses a path that already exists with an incompatible response shape (`SymptomListResponse`, consumed today by the shipped `SymptomCheckerPage`). Changing it in place would have broken that page immediately, before Phase 7 built anything to replace it. Exposed the new taxonomy-based listing at `GET /taxonomy/symptoms` instead — same query params, same plan §6.1 response shape — and left the old `/available-symptoms` completely untouched.
2. **Docker note:** this backend runs via `docker-compose`/`Dockerfile`, not a local venv. `Back-end/requirements.txt` was updated (`scikit-learn>=1.9.0`, added `lightgbm>=4.6.0`, `joblib` bumped to `>=1.5.0`) to match Phase 4's training environment pin — this is required for the image to even unpickle the new model, not optional. Verified locally against a venv installed from the same `requirements.txt`; **the Docker image itself was not rebuilt/verified in this pass** — that should happen before this is relied on in the actual running container.

---

### Phase 6 — Persistence Layer
**Tasks**
- Alembic migration adding: `assessments`, `assessment_symptoms`, `red_flags_triggered`, `chat_sessions`, `chat_messages` — replacing the current in-memory chat sessions.
- `redis_chat_session_repository.py` for active session state; Postgres for the durable log (caregiver history/audit).

**DoD:** Restarting the backend does not lose an in-progress or completed chat/assessment.

**[Execution note, Phase 6 complete — full detail in `Plans/SYMPTOM_CHECKER_PROGRESS.md`]**
Added SQLAlchemy models and Alembic migration for `assessments`, `assessment_symptoms`,
`red_flags_triggered`, `chat_sessions`, and `chat_messages`; implemented
`PostgresAssessmentRepository` and `RedisChatSessionRepository`; wired `/assessment`,
`/bp-triage`, `/chat/from-assessment`, and the original `/chat` session state through the new
persistence layer. `/chat/from-assessment` also writes the seeded assistant message into
`chat_messages` for the durable audit/history log; the old free-text `/chat` transcript remains
Redis-active-state only until its currently mocked history endpoint gets a real contract.
Deliberate contract-preserving decision: `/assessment` and `/bp-triage`
persist a generated assessment UUID internally but do **not** add `assessment_id` to their
response body, because Phase 5/§6.1 locked the response shape and Flutter contract. The existing
`/chat/from-assessment` response already returns `{"assessment_id": ...}`, so that route uses the
same UUID for the saved assessment, Redis session, and Postgres chat seed row.

---

### Phase 7 — Flutter Guided Wizard
**Tasks**
- Build the 5-step wizard per §3.2, single `assessment_flow_provider.dart` holding the in-progress `AssessmentInput` across all pages.
- `assessment_result_page.dart`: urgency badge (green/yellow/orange/red per source doc), top-3 conditions with confidence, "why" list, recommended action, red-flag banner, disclaimer, CTAs ("Open AI Chat", "Notify Caregiver").
- Zero hardcoded strings — all via `assets/translations/en.json`/`ar.json`.
- Existing chat page now opened via `startChatFromAssessment`, pre-seeded with context.

**DoD:** Arabic and English walkthroughs produce identical navigation/data, only text/direction differs. `flutter analyze` clean.

Execution note (2026-07-01):
1. Built the Phase-7 Flutter feature under `Front-end/health_mate_app/lib/features/symptom_checker/`
   and wired it to the Phase-5/6 backend contracts. `flutter analyze` is clean and `flutter test`
   passes.
2. UX clarification: the guided wizard is the final Check-tab diagnosis flow. The patient/caregiver
   Check tab opens `SymptomCheckerWizardPage` directly; `AiSymptomChatPage` is opened from the
   result screen only, with structured assessment context already seeded.
3. Seeded-chat deviation: `/chat/from-assessment` still returns only `{"assessment_id": ...}` to
   preserve the locked Phase-5 response shape. Flutter therefore builds the visible seed context
   from its current `AssessmentInputEntity` and `AssessmentResultEntity`, while using the returned
   id as the persisted chat session id.
4. `Notify Caregiver` is implemented through the existing linked-caregiver notification/FCM
   infrastructure. It runs automatically for high-risk assessments and manually when the patient
   taps the CTA via the additive `POST /api/v1/ai/assessment/notify-caregiver` route. `Book
   Doctor` was removed because this app has no booking feature/contract.
5. `aiBpTriage` was added to Flutter API constants but intentionally left unused until Phase 8.

Phase 6 follow-up recorded during Phase 7 review: `AssessmentRepository.save_chat_seed()` is now
part of the domain interface. The temporary `getattr(assessments, "save_chat_seed", None)`
escape hatch was removed.

---

### Phase 8 — BP Feature Integration Hook
**Tasks**
- High/critical BP reading → navigate into `heart_bp` category with `vitals` prefilled, skip to Symptom Selection.
- `run_bp_triage` use case wires BP context + symptoms into the same Rule Engine + ML pipeline, fulfilling the `POST /api/v1/ai/bp-triage` contract from the BP handoff doc.
- Caregiver notification reuses the **existing** BP alert cooldown logic — no second, conflicting notification path.

**DoD:** Simulated critical BP reading in tests results in: red flags evaluated, caregiver notified per existing cooldown, `bp_triage` assessment persisted and linked to the originating BP reading ID.

**[Execution note, Phase 8 complete — full detail in `Plans/SYMPTOM_CHECKER_PROGRESS.md`]**
Implemented the high/critical manual-BP hook end to end: a saved manual BP reading that is
classified high/critical opens `SymptomCheckerWizardPage(initialBpReading: ...)`, preselects
`heart_bp`, pre-fills systolic/diastolic/heart-rate values, skips category selection, submits via
`POST /api/v1/ai/bp-triage`, and persists the resulting `bp_triage` assessment with
`source_vital_id` linked to `vital_signs.id`. Backend test coverage now includes a critical
`/bp-triage` request that verifies critical urgency/red flags and the persisted source vital link.

Phase-8 deviation: this plan says to reuse the existing BP alert cooldown logic, but the current
codebase contains only the existing BP alert send path (`/vitals/bp` →
`NotificationService.send_emergency_bp_alert`) and no actual cooldown implementation to reuse.
Therefore `/bp-triage` deliberately does **not** send a second caregiver notification; it preserves
the single existing BP alert path and only links/persists the guided assessment. A full cooldown
service can be added in the dedicated BP-alert phase, but it was not invented here.

---

### Phase 9 — Optional LLM Phrasing Layer
Only after Phases 1–8 are stable. Strict template forbidding new diagnosis/urgency/recommendation beyond the input JSON. Must degrade gracefully to static templated text if disabled or failing.

**DoD:** Disabling this layer still produces a complete, safe, correctly-localized response.

**[Execution note, Phase 9 complete — full detail in `Plans/SYMPTOM_CHECKER_PROGRESS.md`]**
Implemented as an optional `AssessmentPhraser` boundary with a no-op static fallback and an
OpenAI-compatible adapter that may update only `patient_message` and `caregiver_summary`.
The layer is disabled by default via `SYMPTOM_CHECKER_LLM_PHRASING_ENABLED=false`. Tests verify
that disabled/failing phrasing returns the complete static response and that phrasing cannot alter
diagnosis, urgency, red flags, action code/text, or notification decisions.

---

### Phase 10 — Localization & Encoding Audit
**Tasks:** re-save as clean UTF-8: `Symptom-Checker/README.md`, `Symptom-Checker/app.py`, `Symptom-Checker/Data/**/*.json`, `Symptom-Checker/Data/**/*.js`, `Back-end/app/api/v1/ai.py`, `Back-end/app/services/ai_service.py` (or its replacement files post-Phase-5), `Front-end/.../app_constants.dart`, `Front-end/.../assets/translations/ar.json`. Add a CI check that fails on invalid UTF-8/mojibake in these paths.

**DoD:** CI encoding check passes; bilingual parity suite (Phase 11) green.

**[Execution note, Phase 10 complete]** Added `Back-end/tests/quality/test_encoding_audit.py` as
the CI-style gate for invalid UTF-8, UTF-8 BOM, and common mojibake markers across the paths named
above. The audit passed without a broad file rewrite.

---

### Phase 11 — Testing & QA
Automate every row as pytest (backend) / integration tests (Flutter):

| Flow | AR | EN | Notes |
|---|---|---|---|
| Category loading | ✅ | ✅ | same IDs |
| Symptom list loading | ✅ | ✅ | same IDs, dedup verified |
| Symptom search/synonyms | ✅ | ✅ | resolves to same ID |
| Severity selection | ✅ | ✅ | |
| Follow-up questions | ✅ | ✅ | |
| Assessment → top-3 + urgency | ✅ | ✅ | identical `disease_id`s both languages |
| Red flags | ✅ | ✅ | identical `code`s |
| Caregiver notification | ✅ | ✅ | caregiver lang independent of patient lang |
| BP → symptom checker handoff | ✅ | ✅ | |
| Chat from assessment | ✅ | ✅ | |

Include the exact test phrases from the source doc:
```
عندي كحة واحتقان وحرارة بسيطة
عندي صداع ودوخة والضغط عالي
عندي ألم في الصدر وضيق تنفس
I have cough, sore throat, and mild fever.
I have headache and dizziness after high blood pressure.
I have chest pain and shortness of breath.
```

**DoD:** All rows automated and green in CI.

**[Execution note, Phase 11 complete]** Automated the matrix with backend pytest coverage and
Flutter unit coverage. The plan's "symptom search/synonyms" row is implemented as additive v2
`synonyms` metadata in `/taxonomy/symptoms` plus Flutter local search over `name`, `id`, and
`synonyms`. The six exact free-text phrases are covered through the existing legacy free-text
extractor; v2 `/assessment` remains structured and does not parse free text.

---

### Phase 12 — Rollout
Feature flag `symptom_checker_v2_enabled`. Monitor prediction distribution, red-flag trigger rate, caregiver notification rate, `/assessment` latency. Old flow (current `MLPClassifier`/`CountVectorizer` production artifacts) stays as fallback until a defined stability window passes, then is removed.

**[Execution note, Phase 12 complete]** Backend flag `SYMPTOM_CHECKER_V2_ENABLED` defaults to true
and disables only v2 structured endpoints when false; legacy v1 endpoints stay available. Flutter
flag `--dart-define=SYMPTOM_CHECKER_V2_ENABLED=false` routes the Check tab and BP emergency
fallback to the old `SymptomCheckerPage`. Added in-process rollout metrics at
`GET /api/v1/ai/assessment/rollout-metrics` for assessment count, top-prediction distribution,
urgency distribution, red-flag trigger rate, caregiver notification rate, and latency. Metrics are
process-local and reset on API restart; exporting them to long-window observability is a later
infrastructure step, not invented in this phase.

---

## 6.1 API Contract Specification

### `POST /api/v1/ai/assessment?lang=ar|en`
Request:
```json
{
  "category_id": "heart_bp",
  "symptoms": [{"id": "headache", "severity": 2}, {"id": "dizziness", "severity": 1}],
  "duration_days": 1,
  "age_group": "elderly",
  "known_conditions": ["hypertension"],
  "vitals": {"systolic": 165, "diastolic": 100, "heart_rate": 95}
}
```
Response:
```json
{
  "top_predictions": [
    {"disease_id": "hypertension", "name": "ارتفاع ضغط الدم", "confidence": 0.78, "why": ["headache", "dizziness", "elevated_bp"]},
    {"disease_id": "migraine", "name": "الشقيقة", "confidence": 0.34, "why": ["headache"]}
  ],
  "urgency": "high",
  "urgency_label": "مرتفع",
  "red_flags": [],
  "patient_message": "...",
  "recommended_action_code": "remeasure_after_rest",
  "recommended_action_text": "استرح لمدة 5 دقائق ثم أعد القياس.",
  "caregiver_summary": "...",
  "should_notify_caregiver": true,
  "disclaimer": "هذا تقييم مبدئي وليس تشخيصًا نهائيًا."
}
```
`GET /api/v1/ai/categories?lang=` → `[{id, name, order}]`.
`GET /api/v1/ai/available-symptoms?category_id=&lang=` → `[{id, name, description, red_flag}]` (filtered via each symptom's `category_ids`).
`POST /api/v1/ai/bp-triage?lang=` → same response shape plus `should_remeasure`.
`POST /api/v1/ai/chat/from-assessment?lang=` → `{"assessment_id": "..."}` → seeded chat session.

**Error contract (all endpoints):**
```json
{"error_code": "no_symptoms_selected", "message": "يرجى اختيار عرض واحد على الأقل."}
```
Stable codes only; Flutter never parses `message` for logic.

---

## 7. Coding Standards

**Python / FastAPI**
- Type hints mandatory. `domain/` imports nothing beyond `pydantic`/stdlib.
- Use cases return DTOs, never ORM models or raw dicts.
- Rule-engine functions are pure — required for the Phase 2 100%-branch-coverage requirement.

**Dart / Flutter**
- Riverpod providers per feature, no global mutable singletons.
- Widgets contain no business logic — read providers, dispatch use-case calls only.
- All strings via `easy_localization` keys.

**ML**
- `feature_engineering.py` is imported by both `training/` and the backend's `infrastructure/ml/` — never copy-pasted.
- Every model artifact ships with `model_metadata.json` recording schema version + feature list; inference raises (never guesses) on mismatch.
- Training and backend environments pin the same scikit-learn version (see §1.4/Phase 4).

---

## 8. Risk Register

| Risk | Mitigation |
|---|---|
| Synthetic dataset medically implausible | Symptom-probability profiles derived from the migrated `related_symptom_ids` (real clinical associations already curated in the existing data), not invented from scratch; light clinical review if any medically-trained contact is available. |
| scikit-learn version drift between training and backend | Pin exact version in both `requirements.txt` files; add a startup check in `model_registry.py` that logs a hard warning (or refuses to load) on version mismatch. |
| Migration mis-maps a disease/symptom category | `migration_report.md` is mandatory output of Phase 1 and must be reviewed by a human before Phase 3 starts — do not auto-approve. |
| Old model's 90.34% accuracy gets misquoted later as a "real" baseline | Every evaluation report in Phase 4 must explicitly restate the §1.4 caveat (measured on random-subset synthetic data, not a fair baseline) alongside the new number. |
| Scope creep across 12 phases for a graduation timeline | Phases 1–6 (migration, rules, data, model, backend) are the defensible technical core; Phases 7–12 can be trimmed under time pressure without compromising the core technical claim. |

---

## 9. Handoff Instructions for the Implementation Model

1. Execute phases strictly in the dependency order in §5 — Phase 1 (migration) must fully complete and its `migration_report.md` be reviewed before Phase 3 (dataset generation) starts, since generation depends on the migrated taxonomy's `related_symptom_ids`.
2. Each phase's DoD is a hard gate. If a DoD can't be met, stop and report why.
3. Never invent medical thresholds, category mappings, or red-flag rules not present in this document, the migrated data, or the two source docs (`BP_FLOW_CALIBRATION_HANDOFF.md`, `SYMPTOM_CHECKER_IMPROVEMENT_PLAN.md`). Flag missing decisions explicitly rather than guessing.
4. Do not delete `Disease_Prediction_Model.ipynb`, `train_model.py`, or the legacy `Data/General/`/`Data/Heart/` files — they are migration inputs and historical reference, kept read-only after Phase 1.
5. Any deviation from this plan (folder names, schema fields, endpoint paths) must be written back into this document so it remains the single source of truth.
