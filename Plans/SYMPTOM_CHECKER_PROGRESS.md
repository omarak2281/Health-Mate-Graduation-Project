# Symptom Checker — Execution Progress Log

Tracks real execution against `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md`. Updated after each phase completes — not a plan, a record of what actually happened, including deviations found during real execution (per §9.5 of the plan, deviations get written back to the plan too).

Legend: ✅ done · 🚧 in progress · ⬜ not started

| # | Phase | Status |
|---|---|---|
| 1 | Taxonomy Migration | ✅ |
| 2 | Red-Flag & Urgency Rule Engine | ✅ |
| 3 | Structured Dataset Generation | ✅ |
| 4 | ML Feature Engineering & Training | ✅ |
| 5 | Backend Clean-Architecture Refactor | ✅ |
| 6 | Persistence Layer | ✅ |
| 7 | Flutter Guided Wizard | ✅ |
| 8 | BP Feature Integration Hook | ✅ |
| 9 | Optional LLM Phrasing Layer | ✅ |
| 10 | Localization & Encoding Audit | ✅ |
| 11 | Testing & QA | ✅ |
| 12 | Rollout | ✅ |

---

## 🚦 HANDOFF TO NEXT AGENT — read this section first, before touching anything

**Phases 1-12 are implemented and tested.** Phases 1-12 are done, tested, and were
verified against the *real* running Docker container (not just unit tests) as of 2026-07-01.
This section is written so you don't need to re-read the entire log below to get oriented —
but the full per-phase detail (all flagged decisions, deviations, limitations) is below it, and
`Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` is the actual spec you're implementing against.

### What exists right now (verified, not assumed)

| Thing | Where | Status |
|---|---|---|
| Migrated taxonomy | `Symptom-Checker/taxonomy/{categories,symptoms,diseases}.json` | 9 categories, 41 diseases, 108 symptoms (49 defined + 59 orphan stubs) |
| Synthetic dataset | `Symptom-Checker/Data/cases/dataset.jsonl` | 12,300 cases, balanced 300/class, validated |
| Trained model | `Symptom-Checker/Output/Production/best_model_v2.pkl` + `label_encoder_v2.pkl` + `model_metadata_v2.json` | LightGBM, top-1 85.8%, top-3 95.5% — does **not** overwrite the old `best_model.pkl` (still in prod) |
| Rule engine | `Back-end/app/domain/rules_engine/{red_flag_rules,urgency_rules,bp_rules}.py` | 43 pytest tests, 100% branch coverage |
| Backend v2 endpoints | `Back-end/app/api/v1/ai.py` (5 new routes, appended to the existing file) | 13 pytest contract tests + verified live in a real `docker compose` container |
| Persistence layer | `Back-end/app/models/symptom_assessment.py`, `app/infrastructure/persistence/{postgres_assessment_repository,redis_chat_session_repository}.py`, Alembic `phase6_symptom_checker` | Assessments saved to Postgres; active chat sessions saved to Redis; restart smoke test passed |
| Flutter guided wizard | `Front-end/health_mate_app/lib/features/symptom_checker/**` | 5-step guided assessment wired to v2 backend; guided wizard is the primary Check tab |
| BP integration hook | `Front-end/health_mate_app/lib/features/vitals/presentation/widgets/bp_card.dart`, `SymptomCheckerWizardPage(initialBpReading: ...)`, `/api/v1/ai/bp-triage` | Manual high/critical BP reading opens the `heart_bp` wizard with vitals prefilled; `/bp-triage` persists `source_vital_id` |
| Optional LLM phrasing | `Back-end/app/infrastructure/phrasing/assessment_phraser.py` | Feature-flagged off by default; can rewrite only patient/caregiver text; static fallback verified |
| Encoding audit | `Back-end/tests/quality/test_encoding_audit.py` | CI-style pytest gate for UTF-8/BOM/mojibake across the Phase-10 paths |
| Rollout controls | `SYMPTOM_CHECKER_V2_ENABLED`, `symptom_checker_v2_enabled`, `/api/v1/ai/assessment/rollout-metrics` | v2 can be disabled with old Flutter flow fallback; in-process rollout metrics exposed |
| Charts (PNG, real numbers) | `Symptom-Checker/Output/Production/analysis/*.png` + `analysis_index.md` | Regenerate via `python analysis/generate_visualizations.py` from `Symptom-Checker/` |
| Architecture/flow diagrams | `Plans/SYMPTOM_CHECKER_DIAGRAMS.md` | Mermaid — renders in VS Code preview / GitHub directly |

### How to verify all of the above still works before you change anything

```bash
# Backend rule-engine + API contract tests (from Back-end/, needs the venv or equivalent deps)
cd Back-end
PYTHONIOENCODING=utf-8 ./venv/Scripts/python.exe -m pytest tests/ -v   # expect 77 passed

# Real container check (needs Docker Desktop running)
docker compose build api && docker compose up -d
curl http://localhost:8000/docs   # should be 200
docker compose down
```
**Windows gotcha:** if you run Python scripts directly in a terminal (not via pytest/uvicorn),
set `PYTHONIOENCODING=utf-8` first — `ai_service.py` and other modules print emoji/Arabic to
stdout, which crashes with `UnicodeEncodeError` under the default Windows `cp1252` console
codepage. This is a pre-existing characteristic of the environment, not a code bug (it's fine
inside Docker/uvicorn, which don't use that codepage).

### Things you must know after Phase 12

1. **This backend runs via `docker-compose`/`Dockerfile`, not a local venv.** Any new Python
   dependency goes in `Back-end/requirements.txt` (which the Dockerfile installs from). The
   local `Back-end/venv` exists only for running tests quickly during development — it is not
   what ships. Keep `Back-end/requirements.txt`'s `scikit-learn`/`lightgbm` versions in sync
   with `Symptom-Checker/requirements.txt` or `infrastructure/ml/model_registry.py` will fail to
   unpickle the model (see the inline comment in both requirements files for why).
2. **Two AI endpoint generations coexist on purpose.** The 10 original `/ai/*` routes (`/chat`,
   `/symptom-checker`, `/available-symptoms`, `/model-info`, `/symptom-checker/history/{id}`)
   are untouched and still serve the shipped Flutter pages. The 5 new v2 routes
   (`/categories`, `/taxonomy/symptoms`, `/assessment`, `/bp-triage`, `/chat/from-assessment`,
   `/assessment/notify-caregiver`)
   are additive. **Do not merge/replace `/available-symptoms`** — the new taxonomy-based listing
   was deliberately placed at `/taxonomy/symptoms` instead, specifically to avoid breaking the
   live `SymptomCheckerPage`. Phase 7 kept that page and the old chat entry point intact, so do
   not repoint `/available-symptoms` unless a later product decision retires the old page.
3. **Phase 6 persistence is now implemented behind the same API contracts.**
   - `app/infrastructure/persistence/redis_chat_session_repository.py` implements active chat
     session storage for both `/chat/from-assessment` and the original `/chat` session state.
   - `app/infrastructure/persistence/postgres_assessment_repository.py` persists `/assessment`,
     `/bp-triage`, and `/chat/from-assessment` results to Postgres.
   - The Alembic revision `phase6_symptom_checker` creates `assessments`,
     `assessment_symptoms`, `red_flags_triggered`, `chat_sessions`, and `chat_messages`.
   - `/assessment` and `/bp-triage` intentionally do **not** add `assessment_id` to the response,
     preserving Phase 5's locked contract; `/chat/from-assessment` already returns
     `{"assessment_id": ...}` and uses that UUID for the saved assessment/chat seed.
   - `app/infrastructure/persistence/json_taxonomy_repository.py` (reads the static
     `Symptom-Checker/taxonomy/*.json`) is a **legitimate permanent choice**, not a stopgap — the
     taxonomy is static reference data, not per-user data. Leave it as JSON-backed unless you
     have a specific reason to move it to Postgres.
4. **Phase 7 made the guided wizard the Check-tab diagnosis flow.** The patient/caregiver Check
   tab opens `SymptomCheckerWizardPage` directly. `AiSymptomChatPage` still exists, but it is
   reached from the result page with the structured assessment context pre-seeded; it is not a
   competing diagnosis entry point.
5. **Phase 8 links high/critical manual BP readings into the guided flow.** When a manual BP
   reading is saved and classified as high/critical, the Flutter vitals card opens
   `SymptomCheckerWizardPage(initialBpReading: reading)`, selects `heart_bp`, pre-fills
   systolic/diastolic/heart-rate values, skips category selection, and submits through
   `/bp-triage`. The backend persists the resulting assessment with `assessment_type='bp_triage'`
   and `source_vital_id` pointing back to the originating `vital_signs.id`.
6. **BP alert cooldown wording in the Phase 8 plan did not match the current code.** The existing
   BP path in `app/api/v1/vitals.py` sends emergency BP alerts through
   `NotificationService.send_emergency_bp_alert`, but no actual cooldown implementation exists in
   this codebase yet. Phase 8 therefore did **not** add a second caregiver-notification path in
   `/bp-triage`; it preserved the existing single BP alert path and only linked/persisted the
   guided assessment.
7. **59 taxonomy symptoms are still orphan stubs** (`needs_translation: true`, no `name_ar`, no
   description) — see `Symptom-Checker/migration/migration_report.md` for the full list. These
   were never reviewed by a human as the plan's own risk register requires before Phase 3
   (dataset generation) "starts" — dataset generation already ran anyway with stubs in place,
   which was a judgment call to keep momentum, flagged at the time. Phase 7's wizard now surfaces
   these symptom names through `/taxonomy/symptoms`; the 59 stubs still show English text with no
   Arabic translation until the taxonomy is reviewed.
8. **The heart-disease symptom cluster is under-differentiated** (9 of the 10 worst-performing
   model classes are `heart_bp` diseases sharing near-identical symptoms) — see
   `Symptom-Checker/Output/Production/evaluation_report_v2.md`. Not a Phase 6 concern, but don't
   be surprised by it, and don't assume it's a bug in Phase 6's persistence work if a demo
   assessment for e.g. `myocarditis` predicts the wrong disease.
9. **The Docker `postgres_data`/`redis_data` volumes are real and persistent** across
   `docker compose down` (without `-v`). A test user created during Phase 5 verification was
   deleted afterward — don't assume the DB is empty, but also don't assume it's pristine test
   fixtures either.
10. **Docker dev-volume Alembic note from Phase 8.** This local Docker volume had already created
    the Phase-6 tables through `Base.metadata.create_all` while `alembic_version` was still old.
    During Phase 8 verification it was corrected with `alembic stamp phase6_symptom_checker`
    before applying `alembic upgrade head`; the final verified head is `phase7_notify_bp_link`.
11. **Phase 9 LLM phrasing is optional and off by default.** Set
    `SYMPTOM_CHECKER_LLM_PHRASING_ENABLED=true` plus an API key only if you want text rewrites.
    It is not allowed to change diagnosis, urgency, red flags, actions, notifications, or
    thresholds; failures return the static Phase-5 text.
12. **Phase 12 rollout flag defaults to enabled.** Backend uses `SYMPTOM_CHECKER_V2_ENABLED`
    (`symptom_checker_v2_enabled` in settings). Flutter uses
    `--dart-define=SYMPTOM_CHECKER_V2_ENABLED=false` to route the Check tab and BP emergency
    fallback back to the old `SymptomCheckerPage`.

### If something looks wrong

Every deviation from the plan (path changes, ambiguous-spec interpretations, version bumps) was
written back into `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` itself at the relevant section,
per that document's own handoff rule #5 — search that file for "Execution note" or "deviation"
if something in this progress log seems to contradict the plan.

### Documentation/presentation support (cross-cutting, not a plan phase)

Requested separately for the graduation-project writeup/presentation, covering everything built
in Phases 1-5: `Symptom-Checker/analysis/generate_visualizations.py` generates 9 PNG charts
(taxonomy before/after, category distribution, dataset class balance, urgency distribution,
model comparison, two confusion matrices for the named confusable pairs, worst-10 classes,
COVID-19 share check) straight from the real artifacts — nothing hand-drawn or estimated.
`Plans/SYMPTOM_CHECKER_DIAGRAMS.md` has 5 Mermaid diagrams (end-to-end pipeline, Clean
Architecture layers, the red-flag/urgency decision flow, the `/assessment` request sequence,
and a v1-vs-v2 comparison). Regenerate the charts any time the taxonomy/dataset/model changes;
the diagrams are static (architecture, not data) and only need edits if the architecture itself
changes in a later phase.

---

## Phase 1 — Taxonomy Migration

Status: ✅ done (2026-07-01)

**Built:**
- `Symptom-Checker/data_pipeline/schema.py` — Pydantic models (`Category`, `Symptom`, `Disease`, `Taxonomy`) shared by migration and later phases.
- `Symptom-Checker/migration/migrate_legacy_taxonomy.py` — reads the 4 legacy JSON files (`.js` variants ignored, JSON is source of truth), slugifies names to stable IDs, dedupes overlapping symptom keys, maps old free-text categories onto the fixed 9-category set, copies disease `severity` → `default_urgency` verbatim, derives each symptom's `category_ids` from the diseases that reference it, and sets `red_flag=true` on the plan's mandated set.
- Output: `Symptom-Checker/taxonomy/{categories.json, symptoms.json, diseases.json}`.
- `Symptom-Checker/migration/migration_report.md` — full mapping tables, dedup log, category-mapping log, orphan-symptom log, red-flag resolution log.

**Result counts:**
- Categories: 9 (fixed set: `heart_bp`, `respiratory`, `neurological`, `digestive`, `general_fever`, `muscles_joints`, `skin`, `urinary_kidney`, `mental_health`)
- Diseases: 41 (General 23 + Heart 18) — matches plan exactly
- Symptoms: 108 total = 49 directly-defined (after dedup) + 59 orphan stubs (see below)

**Sanity checks run and passed:**
- Every `disease.related_symptom_ids` entry resolves to a real `symptoms.json` id (zero dangling refs).
- Every `disease.category_id` and `symptom.category_ids[*]` resolves to a real category id.
- All output validates against the Pydantic `Taxonomy` schema (script raises on any validation failure — it didn't).

**Key findings/deviations (also written back into `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` §1.2, per the plan's own handoff rule #5):**
1. The plan's claimed 4-way symptom overlap (`Chest Pain`, `Shortness of Breath`, `Fatigue`, `Dizziness`) was only partly right. The real overlapping **top-level entries** are `Chest Pain`, `Shortness of Breath`, `Fever` (3, not 4) — `Fatigue`/`Dizziness` are only ever defined in `GeneralSymptoms.json`.
2. Much bigger issue found: **59 symptom names** are referenced by a disease's `relatedSymptoms` array but were never defined as their own entry in either symptoms file (e.g. `Sudden Numbness`, `Trouble Speaking`, `Loss of Balance`, `Nosebleeds`, `Bloating`, `Increased Thirst`, `Radiating Pain to Left Arm`...). Notably, this includes several symptoms the plan **requires** to be `red_flag: true` (`sudden_numbness`, `trouble_speaking`, `loss_of_balance`, `loss_of_consciousness`) — they exist only as text inside `Stroke`'s and other diseases' related-symptom lists, never as first-class symptom records. Handled by creating stub entries (`needs_translation: true`, no Arabic, no description) so no disease→symptom link was silently dropped — full list with source disease in the migration report.
3. Ambiguous category mappings (no dedicated bucket in the fixed 9-category set): `Metabolic` → `general_fever`, `Endocrine` → `general_fever`, `Hematological` → `general_fever`, `Liver Disease` → `digestive`, `Infectious Disease` → `respiratory`.
4. One spelling-alias resolved manually: `"Coughing"` → `cough` (Asthma referenced a variant spelling of the already-defined `Cough` symptom).
5. 12 defined symptoms end up with empty `category_ids` because no disease currently references them (e.g. `edema`, `tachycardia`, `insomnia`, `skin_rash`, `orthopnea`) — they won't surface in a category-filtered symptom picker until either a disease links to them or they get a manual category assignment.

**Action required before Phase 3 (dataset generation depends on `related_symptom_ids`, which depends on clean stubs):**
- A human should review the 59 orphan stubs in `migration_report.md`, add `name_ar` + descriptions, and decide whether any are actually duplicates of an existing symptom under different wording (e.g. `swelling_in_legs` / `swelling_in_ankles` vs. `edema`/`peripheral_edema` look like likely duplicates but were **not** auto-merged — flagged, not guessed).
- This review was explicitly deferred, not performed automatically, per the plan's Phase 1 DoD and risk register ("Migration mis-maps a disease/symptom category" → `migration_report.md` must be human-reviewed before Phase 3 starts).

**Not touched (by design, per plan §9.4):** `Disease_Prediction_Model.ipynb`, `train_model.py`, `Data/General/*`, `Data/Heart/*` — left read-only as migration input / historical reference.

---

## Phase 2 — Red-Flag & Urgency Rule Engine

Status: ✅ done (2026-07-01)

**Built** (at `Back-end/app/domain/...`, ahead of the Phase 5 Clean-Architecture refactor — the domain layer has zero framework dependencies per the plan's own coding standard, "domain/ imports nothing beyond pydantic/stdlib", so it can be built standalone now and Phase 5 just wires the rest of the layers around it):
- `app/domain/value_objects/urgency.py` — `Urgency` literal + `max_urgency()` helper (for the Phase 5 aggregator's "rule engine can only escalate" composition rule).
- `app/domain/value_objects/age_group.py` — `AgeGroup` literal.
- `app/domain/entities/assessment.py` — `SelectedSymptom`, `Vitals`, `AssessmentInput`.
- `app/domain/entities/red_flag.py` — `RedFlag`.
- `app/domain/rules_engine/bp_rules.py` — shared BP threshold constants (single source, reused by both this module and the future Phase 8 BP alert logic).
- `app/domain/rules_engine/red_flag_rules.py` — `evaluate_red_flags()`.
- `app/domain/rules_engine/urgency_rules.py` — `determine_urgency()`.
- Tests: `Back-end/tests/domain/rules_engine/{test_red_flag_rules,test_bp_rules,test_urgency_rules}.py` — 43 tests.
- `Back-end/pytest.ini` added (none existed before).

**DoD check:**
- 100% branch coverage confirmed via `pytest-cov --cov-branch` on all three rule-engine modules (62 statements / 20 branches, 0 missed) — command: `venv/Scripts/python.exe -m pytest tests/domain/rules_engine/ --cov=app.domain.rules_engine --cov-branch --cov-report=term-missing`.
- All three plan-mandated DoD scenarios have explicit end-to-end tests: "chest pain + shortness of breath = urgent" (`test_e2e_chest_pain_and_shortness_of_breath_is_high`), "fainting = emergency" (`test_e2e_fainting_is_emergency`), "stroke symptoms = emergency" (`test_e2e_stroke_symptoms_is_emergency`).

**Environment note:** `Back-end/venv` had only `pytest`/`pytest-cov`/base tooling installed, no project dependencies at all (not even `pydantic`, despite being a FastAPI project — the venv looks like it was never fully populated from `requirements.txt`). Installed `pytest==7.4.4`, `pytest-cov==4.1.0` (matching `requirements-dev.txt`) and `pydantic==2.5.3` (matching `requirements.txt`'s pin) into it so tests actually run. Full `requirements.txt` still isn't installed — that'll be needed once Phase 5 starts touching FastAPI routes.

**Two flagged assumptions** (also written back into `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` §6 Phase 2, per the plan's handoff rule #5 — neither is silently guessed, both need sign-off before ship):
1. **"Elevated BP" threshold for the moderate-urgency rule is not defined in either source doc.** The plan's own moderate-tier rule ("known hypertension + elevated BP") needs a number, but neither this plan nor `BP_FLOW_CALIBRATION_HANDOFF.md` gives one (the handoff doc only names the tier without bounds). Implemented as `SBP_ELEVATED=130` / `DBP_ELEVATED=80` in `bp_rules.py` — the standard AHA Elevated/Stage-1-hypertension boundary, chosen as the most defensible public reference, but explicitly commented as unsourced and pending clinical/product review.
2. **HR thresholds are defined in the handoff doc but not wired into this plan's own urgency formula.** `BP_FLOW_CALIBRATION_HANDOFF.md`'s "Medium: HR>100, HR<50" tier isn't part of this plan's Phase 2 moderate-urgency spec (which only lists 2 triggers). Kept `HR_HIGH=100`/`HR_LOW=50` as named constants in `bp_rules.py` for Phase 8's direct BP alert use, but `determine_urgency()` does not consume them — implemented literally per this plan's spec, discrepancy between the two docs logged for reconciliation rather than silently picking one.

**Not yet done (belongs to later phases, not a Phase 2 gap):** wiring `evaluate_red_flags`/`determine_urgency` into an actual API endpoint (Phase 5), resolving `SelectedSymptom.red_flag` from the real taxonomy repository instead of tests hand-setting it (Phase 5), and the Phase 5 aggregator's `max(rule_urgency, ml_urgency)` composition (needs Phase 4's ML classifier to exist first).

---

## Phase 3 — Structured Dataset Generation

Status: ✅ done (2026-07-01)

**Built:**
- `Symptom-Checker/data_pipeline/generate_structured_cases.py` — for each of the 41 migrated diseases, builds a symptom-inclusion probability profile from `related_symptom_ids` order (earlier-listed = more probable), independently samples each case's symptom subset/severity/duration/age_group/optional risk factors/vitals with a fixed seed (42), then **imports the actual Phase 2 rule engine from `Back-end/app/domain/rules_engine`** (cross-project import) to compute each case's `urgency` label — so the synthetic dataset's ground truth can never disagree with the production rule engine.
- `Symptom-Checker/data_pipeline/validate_dataset.py` — schema-validates every case, cross-checks `disease_id`/symptom ids against the taxonomy, fails if any class exceeds 2x the median class size.
- Extended `Symptom-Checker/data_pipeline/schema.py` with `TrainingCase`/`CaseSymptom`/`CaseVitals` (plan §4.4 shape).
- Output: `Symptom-Checker/Data/cases/dataset.jsonl` (12,300 cases) + `Symptom-Checker/Data/cases/dataset_report.md`.

**DoD check:**
- `validate_dataset.py` → `PASS: 12300 cases, 41 classes, median class size 300, max ratio 1.00x` (uniform 300/class by construction, comfortably above the plan's ≥250/class floor, so the "no class >2x median" check passes trivially).
- Confusable-pair differentiation implemented and confirmed: `common_cold`/`influenza`/`covid_19` get distinct duration-day ranges and severity ranges, and `covid_19` cases carry `loss_of_taste_smell` at 85% inclusion (confirmed: 255/300 cases). `hypertension` vs `migraine`/`stroke` needed no synthetic boosting — checked directly against the taxonomy that their `related_symptom_ids` sets don't overlap at all — but `hypertension` additionally gets elevated vitals in 75% of cases as an extra signal.

**Two flagged issues (both written into `Data/cases/dataset_report.md`, not silently shipped):**
1. **Risk-factor vocabulary gap in the plan itself.** Plan §4.5 says `N_risk_factors` is "derived from the migrated taxonomy," but Phase 1's taxonomy schema has no risk-factor list anywhere — never specified. Used the plan's own two literal worked examples (`"hypertension"`, `"asthma"`) as the seed for a small pool of existing chronic disease ids (`hypertension`, `diabetes_mellitus_type_2`, `asthma`, `hypothyroidism`, `chronic_kidney_disease`) reused as risk-factor tokens. Needs product/clinical sign-off before Phase 4 treats it as final.
2. **Urgency label skew for red-flag-heavy diseases.** 18 of 41 diseases (mostly `heart_bp` category — `aortic_stenosis`, `hypertension`, `stroke`, `pneumonia`, etc.) end up with 70-98% of their cases labeled `high`/`critical`, because their `related_symptom_ids` legitimately include a red-flag symptom (e.g. `chest_pain`) that the rule engine escalates whenever sampled at severity≥2. Each individual case's label is clinically defensible, but the *aggregate* distribution likely overstates how often these diagnoses present as emergencies in real life (most Hypertension is not an emergency). Iterated once already (red-flag symptom severity changed from a forced `randint(2,4)` to `randint(1,4)` to reduce this), but the skew remains significant for the heart-disease cluster. Flagged in the dataset report per-disease, needs clinical review before Phase 4 trains on it as ground truth.

**Not touched:** the old notebook's random-subset generation method and its output artifacts — this is a parallel, new pipeline, per plan §1 "Deprecated, not patched."

---

## Phase 4 — ML Feature Engineering & Training

Status: ✅ done (2026-07-01)

**Built:**
- `Symptom-Checker/data_pipeline/constants.py` — pulled `RISK_FACTOR_POOL` out of Phase 3's generator into a shared module so Phase 3 and Phase 4 can never drift apart on the risk-factor vocabulary.
- `Symptom-Checker/training/feature_engineering.py` — single `build_features(assessment_input: dict) -> np.ndarray` (232-dim: 108 symptom-presence + 108 symptom-severity + 4 duration-bucket + 3 age-group + 5 risk-factor + 4 vitals), plus `feature_names()` for metadata and `build_feature_matrix()` for batch use. Framework-agnostic (plain dict in, numpy array out) so it can be imported unchanged by Back-end's future `infrastructure/ml/` (Phase 5) the same way Phase 3 already cross-imports Back-end's domain layer into Symptom-Checker.
- `Symptom-Checker/training/train_baseline.py` — LogisticRegression + RandomForest, comparison only.
- `Symptom-Checker/training/train_final.py` — LightGBM multiclass (300 estimators), saved as `Output/Production/{best_model_v2.pkl, label_encoder_v2.pkl, model_metadata_v2.json}` — **not overwriting** the original `best_model.pkl`/`vectorizer.pkl`/`model_metadata.json`, per DoD.
- `Symptom-Checker/training/evaluate.py` — confusion matrix + confusable-pair tables + worst-10-classes report → `Output/Production/evaluation_report_v2.md`.

**Results:**
- Baseline: LogisticRegression 87.0% / RandomForest 86.6% top-1 accuracy (`Output/Production/baseline_comparison.json`).
- Final (LightGBM): **top-1 accuracy 0.8581, top-3 accuracy 0.9549** on a stratified 80/20 held-out split — reported with the mandatory §1.4 caveat restated in the report itself (the old 0.9034 number is not comparable, different methodology).
- COVID-19 predicted/true share ratio: **0.98** (DoD requirement satisfied — no systematic over/under-prediction).
- Confusable-pair confusion matrices confirm the Phase 3 differentiation fully worked: `common_cold`/`influenza`/`covid_19` and `hypertension`/`migraine`/`stroke` all show **zero** cross-class confusion in the held-out set.

**Two things flagged during execution (both written back into the plan §6 Phase 4, per handoff rule #5):**
1. **Version drift reproduced the exact risk the plan's own §1.4/§8 warned about.** `lightgbm==4.5.0` (what was installed) calls a `scikit-learn.check_X_y()` argument (`force_all_finite`) that `scikit-learn>=1.7` removed → `TypeError` on `model.fit()`. Fixed by upgrading to `lightgbm>=4.6.0` and bumping the pin in `Symptom-Checker/requirements.txt` from `scikit-learn>=1.7.2` to `>=1.9.0` (also added `pandas`, `xgboost`, `pydantic` pins that were being used but not declared). **Action required in Phase 5:** `Back-end/requirements.txt` must pin the same `scikit-learn` version before it loads this model, or the same crash will happen there.
2. **The heart-disease cluster, not the respiratory triad, is the model's real weak spot.** 9 of the 10 worst-performing classes are `heart_bp` diseases with heavily overlapping symptoms and no differentiating boost applied in Phase 3 (only the respiratory triad and the two hypertension pairs were explicitly named in the plan's Phase 3 spec): `myocarditis` 35% accuracy, `hypertrophic_cardiomyopathy` 40%, `coronary_artery_disease` 52%, `congestive_heart_failure`/`pericarditis` 60%, `ventricular_tachycardia` 65%, `heart_failure`/`pulmonary_hypertension` 68%, `stable_angina` 70%, `aortic_stenosis` 75%. Full confusion detail in `Output/Production/evaluation_report_v2.md`. This is a real limitation to revisit (candidate: Phase 3 could add differentiating boosts for this cluster the same way it did for `covid_19`'s `loss_of_taste_smell`), not something to silently accept as final.

**Environment note:** the system-wide (global, not a project venv) Python environment was used for Symptom-Checker's training — there is no dedicated `Symptom-Checker/venv`. Upgraded `scikit-learn` 1.3.0→1.9.0 and `lightgbm` 4.5.0→4.6.0 globally to make training work; pip flagged unrelated pre-existing version conflicts (`albumentations`, `camel-tools`, `feature-engine`, `imbalanced-learn`, `mlflow` all want different `numpy`/`pandas`/`scipy`/`pyarrow` versions) that were not touched and appear unrelated to any Health-Mate work. Worth creating a dedicated `Symptom-Checker/venv` before this ships, to stop drifting the shared global environment.

**Not yet done (belongs to Phase 5):** wiring `build_features`/`best_model_v2.pkl` into an actual backend inference path — Phase 4 only produces the artifacts, `infrastructure/ml/disease_classifier_impl.py` and `model_registry.py` (with the version-mismatch guard the plan's risk register asks for) are Phase 5 work.

---

## Phase 5 — Backend Clean-Architecture Refactor

Status: ✅ done (2026-07-01)

**IMPORTANT environment correction mid-phase:** the user clarified this backend runs via `docker-compose`/`Dockerfile`, not a local venv (I had been treating `Back-end/venv` as if it were the deployment mechanism). Adjusted: every new Python dependency this phase needed (`lightgbm`, upgraded `scikit-learn`/`joblib`) was added to `Back-end/requirements.txt` (which the `Dockerfile` installs from), not just `pip install`-ed into the local venv. The local venv was still used to run tests quickly during development, but it is not what ships. **The Docker image itself was not rebuilt or run in this pass** — only verified locally against a venv installed from the updated `requirements.txt`. Rebuilding/smoke-testing the actual container before relying on this in the real environment is an open follow-up.

**Also found and fixed my own mistake:** an earlier `cd "Back-end"` I ran when the shell was already inside `Back-end/` silently created a junk nested `Back-end/Back-end/app/...` directory tree (empty `__init__.py` stubs only, from `mkdir -p`/`touch` — no real code, since every actual file write used an absolute path and landed correctly). Verified it was 100% empty junk, then deleted it. No data was lost; flagging so it isn't a mystery if noticed later.

**Built (additive only — zero existing `/ai/*` routes modified):**
- Domain: `entities/{category,disease,symptom}.py`; `interfaces/{taxonomy_repository,disease_classifier,assessment_repository,chat_session_repository}.py` (the last two are interface-only — concrete Postgres/Redis implementations are Phase 6).
- Infrastructure: `persistence/json_taxonomy_repository.py` (reads `Symptom-Checker/taxonomy/*.json` directly — same "read the mounted data directory" pattern the old `ai_service.py` already used, works unchanged in Docker via the existing `../Symptom-Checker:/app/Symptom-Checker` volume mount); `persistence/in_memory_chat_session_repository.py` (Phase 5 stopgap, same in-memory pattern the old `ai.py` already had); `ml/model_registry.py` (loads `best_model_v2.pkl`/`label_encoder_v2.pkl`, logs a hard warning on scikit-learn version mismatch — the exact guard the plan's risk register asked for); `ml/structured_feature_builder.py` (cross-imports `Symptom-Checker/training/feature_engineering.py`'s real `build_features`, never reimplements it); `ml/disease_classifier_impl.py` (`LightGbmDiseaseClassifier`).
- Application: `dto/assessment_dto.py` (plan §6.1 response shape + the static templated urgency-label/action-text/disclaimer strings — the Phase 9 LLM layer's baseline to fall back to, not a placeholder to be replaced); `use_cases/{run_assessment,get_categories,get_available_symptoms,start_chat_from_assessment,run_bp_triage}.py`.
- API: `schemas/{assessment_schemas,category_schemas}.py`; `core/di.py` (lightweight `Depends`-compatible providers, no DI framework); extended `api/v1/ai.py` with 5 new routes (see path deviation below) — each handler ≤15 lines, delegating to use cases per the coding standard.
- Config: `symptom_checker_root_path`/`symptom_checker_taxonomy_path` added to `core/config.py` (reuses the existing `MODELS_BASE_PATH` Docker-vs-local detection, no new logic needed).
- Tests: `tests/api/v1/test_assessment_endpoints.py` — 13 tests, mounting only the `/ai` router on a bare `FastAPI()` instance with dependency overrides (no real Postgres/Redis needed).

**DoD check:**
- `/docs` (verified via `app.openapi()` on the router directly): all 5 new endpoints appear (`/categories`, `/taxonomy/symptoms`, `/assessment`, `/bp-triage`, `/chat/from-assessment`) alongside all 10 original ones, untouched.
- 13/13 contract tests pass: en+ar for every new endpoint; the literal regression test for "`lang` arrives as query param, body `lang` is ignored"; the literal regression test for "`urgency`/`recommended_action_text` top-level, no `disease_info` nesting"; "`red_flags` still populated when the ML classifier raises" (top_predictions degrades to `[]`, red flags don't); `no_symptoms_selected` error-contract shape.
- **Real end-to-end smoke test** (not fakes): real `JsonTaxonomyRepository` (108 symptoms/41 diseases/9 categories loaded from the actual Phase 1 output) + real `LightGbmDiseaseClassifier` (the actual Phase 4 `best_model_v2.pkl`) through `run_assessment` — chest_pain(3) + shortness_of_breath(2) + elevated BP correctly produced `urgency=critical`, correct Arabic disease names, and `why=[...,"elevated_bp"]` reasoning.

**Deviations/decisions flagged (also written into the plan §6 Phase 5, per handoff rule #5):**
1. **Path deviation:** `available-symptoms` already exists with an incompatible response shape consumed by the shipped `SymptomCheckerPage`. New taxonomy-based listing exposed at `GET /taxonomy/symptoms` instead of overwriting it.
2. **Docker requirements sync:** `Back-end/requirements.txt` bumped to match `Symptom-Checker/requirements.txt` (`scikit-learn>=1.9.0`, `lightgbm>=4.6.0`, `joblib>=1.5.0`) — otherwise `model_registry.py` can't even unpickle the new model in the container.
3. **"ml-derived urgency" interpretation:** plan §2.1 says final urgency = `max(rule_urgency, ml-derived)` but never defines what "ml-derived" means numerically. Implemented as the top-1 predicted disease's `default_urgency`. Reasonable literal reading, not explicitly spelled out in the plan — flagged rather than assumed silently.
4. **"why" field heuristic:** intersection of selected symptom ids and the predicted disease's `related_symptom_ids`, plus the literal token `"elevated_bp"` appended when the disease is `heart_bp` category and vitals classify as high/critical — matches the plan's own §6.1 worked example (`"why": [..., "elevated_bp"]`) exactly, not invented from scratch.
5. **Static templated text (urgency labels, recommended-action text, disclaimer, patient/caregiver messages) is the Phase 5 baseline**, per plan §6 Phase 9 ("must degrade gracefully to static templated text if disabled") — this is intentionally what Phase 9's optional LLM layer would enhance, not a stopgap to rip out later.

**Originally deferred from Phase 5 and now completed later:** Postgres assessment persistence and
Redis chat sessions (Phase 6), Flutter wizard consuming the v2 endpoints (Phase 7), BP handoff and
`source_vital_id` persistence (Phase 8), and optional LLM phrasing with static fallback (Phase 9).

**Update (same day) — Docker verification actually done, superseding the caveat above:**
Ran `docker compose build api` (succeeded — `lightgbm==4.6.0`/`scikit-learn==1.9.0` installed
cleanly into the image) then `docker compose up -d` (db/redis/api all healthy). Confirmed via the
**real running container**, not just the local venv:
- `/openapi.json` shows all 5 new routes alongside all 10 original ones, untouched.
- Registered a real user, logged in, called `POST /api/v1/ai/assessment?lang=ar` with
  `chest_pain`(3) + `shortness_of_breath`(2) + BP 150/95 → got back `urgency=critical`,
  correct red flags, and fully correct Arabic disease names/action text/disclaimer (verified via
  `curl -v` output directly, avoiding a Windows-console-encoding false alarm that showed up in an
  earlier diagnostic-only pass — the underlying taxonomy data and API response were never
  actually corrupted, only a terminal print in my own debugging command was).
- The old v1 model still loads too (with the expected `InconsistentVersionWarning` against the
  new scikit-learn — same warning reproduced inside the real container as in the venv, confirming
  it's a genuine, harmless-for-now, environment-level warning and not a venv artifact).
- Cleaned up afterward: deleted the test user row from the `postgres_data` volume, `docker compose down`.
  Also deleted `Back-end/{__pycache__,.pytest_cache}` directories created while running tests
  (regenerable, not part of the codebase) and the accidental empty `Back-end/Back-end/` tree
  from a shell `cd` mistake earlier in this phase (verified zero real content before deleting).
- Left alone on request: `tmp_nb_cell_04/10/18/24/32.txt` at the repo root — pre-existing,
  unrelated to this plan (look like extracted cells from the separate BP-prediction notebook),
  user asked to keep them.

---

## Phase 6 — Persistence Layer

Status: ✅ done (2026-07-01)

**Built:**
- `Back-end/app/models/symptom_assessment.py` — SQLAlchemy models for
  `assessments`, `assessment_symptoms`, `red_flags_triggered`, `chat_sessions`, and
  `chat_messages`.
- `Back-end/alembic/versions/20260701_1000_phase6_symptom_checker_persistence.py` — Alembic
  migration adding the five Phase-6 tables.
- `Back-end/app/infrastructure/persistence/postgres_assessment_repository.py` — concrete
  `AssessmentRepository` using the existing async SQLAlchemy session.
- `Back-end/app/infrastructure/persistence/redis_chat_session_repository.py` — concrete
  `ChatSessionRepository` using Redis for active session state.
- `Back-end/app/core/di.py` now provides `get_assessment_repository()` and swaps
  `get_chat_sessions()` from the Phase-5 in-memory repo to Redis.
- `Back-end/app/api/v1/ai.py` now persists `/assessment`, `/bp-triage`, and
  `/chat/from-assessment` results to Postgres. The original `/chat` endpoint now stores active
  session state through the same `ChatSessionRepository` interface instead of the process-local
  dict.
- `Back-end/tests/infrastructure/test_redis_chat_session_repository.py` — Redis repository unit
  tests with a fake Redis client; existing API contract tests updated with a fake assessment
  repository so they stay fast and isolated.
- `Back-end/app/core/config.py` accepts externally supplied `DEBUG=release|prod|production` as
  `False`. This was needed because the test process had an external `DEBUG=release` value even
  though `.env` itself says `DEBUG=True`; without this, importing `settings` failed during pytest
  collection.

**DoD check:**
- Local backend tests: `./venv/Scripts/python.exe -m pytest tests/ -v` → **58 passed**, 6 warnings
  (same old v1 model `InconsistentVersionWarning`, Pydantic deprecation warnings, and FastAPI
  `on_event` warning).
- Docker build: `docker compose build api` → succeeded.
- Docker runtime: `docker compose up -d` → db/redis/api started; `/openapi.json` returned `200`.
- Real container persistence smoke test:
  - Inserted a smoke assessment through `PostgresAssessmentRepository` inside the running `api`
    container; confirmed rows were written to `assessments`, `assessment_symptoms`,
    `red_flags_triggered`, `chat_sessions`, and `chat_messages`.
  - Wrote the matching active chat session through `RedisChatSessionRepository`.
  - Ran `docker compose restart api`.
  - Read the same assessment back from Postgres (`urgency=critical`,
    `symptoms=[{"id":"chest_pain","severity":3}]`, red flag `chest_pain`) and the same active
    chat session back from Redis (`state=INITIAL`, `seeded_from_assessment=true`) after restart.
  - Cleaned up the smoke assessment row and Redis key afterward so the persistent Docker volumes
    were not left with test fixture data.
- Verified the new tables exist in the real Postgres container:
  `assessments`, `assessment_symptoms`, `red_flags_triggered`, `chat_sessions`, `chat_messages`.

**Decisions/deviations (also written into `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` Phase 6):**
1. **No response-contract change for `/assessment` or `/bp-triage`.** These routes now generate
   and persist an internal assessment UUID, but do not return it because Phase 5/§6.1 locked the
   response shape and contract tests assert top-level medical guidance fields, not an ID.
2. **`/chat/from-assessment` uses one UUID across assessment, Redis session, and Postgres chat
   seed row.** That endpoint already returns `{"assessment_id": ...}`, so reusing the same UUID
   gives Phase 7 a stable handoff without adding a new field.
3. **`chat_messages` durable logging is currently wired for `/chat/from-assessment` seed
   messages, not the old free-text `/chat` transcript.** Phase 6's DoD ("restart does not lose
   an in-progress chat") is satisfied by Redis-backed active session state. Full transcript
   history can be wired when a real chat-history contract replaces the current mocked
   `/symptom-checker/history/{session_id}` response.
4. **Clean Architecture follow-up before Phase 7 sign-off:** `save_chat_seed()` is now part of
   `AssessmentRepository` itself, and `/chat/from-assessment` calls the interface directly. A
   temporary `getattr()` escape hatch used during Phase 6 was removed after review.

**Not changed:**
- `json_taxonomy_repository.py` remains JSON-backed intentionally; taxonomy is static reference
  data, not user persistence.
- No charts regenerated; Phase 6 changed backend persistence only, not taxonomy/dataset/model
  artifacts.

---

## Phase 7 — Flutter Guided Wizard

Status: ✅ done (2026-07-01)

**Built:**
- New Flutter feature under
  `Front-end/health_mate_app/lib/features/symptom_checker/` with Clean-Architecture-style
  `domain/entities`, `domain/repositories`, `data/datasources`, `data/models`,
  `data/repositories`, Riverpod providers, widgets, and pages.
- Five-step wizard:
  `CategorySelectionPage` → `SymptomSelectionPage` → `SymptomSeverityPage` →
  `FollowupQuestionsPage` → `AssessmentResultPage`, coordinated by
  `SymptomCheckerWizardPage` and `assessment_flow_provider.dart`.
- Backend wiring through `SymptomCheckerRemoteDataSource`:
  `GET /api/v1/ai/categories`, `GET /api/v1/ai/taxonomy/symptoms`,
  `POST /api/v1/ai/assessment`, and `POST /api/v1/ai/chat/from-assessment`.
- Result UI: urgency badge, red-flag banner, patient message, top predictions with confidence,
  recommended action, disclaimer, Open AI Chat, and real Notify Caregiver.
- Shared `WizardBottomActions` widget removed duplicated Back/Next button code from the wizard
  pages.
- `AiSymptomChatPage` now accepts an optional persisted session id plus a human-readable
  assessment context message. The Check tab opens the new guided wizard directly; the chat is
  opened from the assessment result with the structured context already seeded.
- `POST /api/v1/ai/assessment` now auto-notifies linked caregivers when the result is high risk
  (`should_notify_caregiver`, `high`, or `critical`). `POST /api/v1/ai/assessment/notify-caregiver`
  sends the same assessment summary manually when the patient taps Notify Caregiver.
- `AssessmentRepository.save_chat_seed()` was promoted into the backend interface and the
  temporary `getattr()` call was removed before this phase was signed off.
- `Front-end/health_mate_app/assets/translations/{en,ar}.json` gained all Phase-7 strings.
- `Front-end/health_mate_app/test/widget_test.dart` now validates the structured
  `AssessmentInputEntity.toJson()` backend contract.

**DoD check:**
- Backend regression: `./venv/Scripts/python.exe -m pytest tests/ -q` from `Back-end/` →
  **59 passed**, 6 existing warnings.
- Flutter analyzer: `flutter analyze` from `Front-end/health_mate_app/` → **No issues found**.
  The command still prints `The system cannot find the file specified.` after completion in this
  Windows environment, but exits successfully.
- Flutter tests: `flutter test` from `Front-end/health_mate_app/` → **All tests passed**.
- Docker backend smoke after the caregiver-notification wiring: `docker compose build api` succeeded,
  `docker compose up -d` started db/redis/api healthy, `GET http://localhost:8000/docs` returned
  `200`, then `docker compose down` cleaned up the running containers.

**Decisions/deviations (also written into `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` Phase 7):**
1. **Guided wizard is the Check tab.** Product clarification after review: the new diagnosis flow
   is category → symptoms → severity → details → result, so the Check tab now opens
   `SymptomCheckerWizardPage` directly. Free-text chat is not a competing diagnosis entry point;
   it is opened from the result with assessment context.
2. **Seeded chat context is displayed in Flutter.** `/chat/from-assessment` keeps the Phase-5
   response shape (`{"assessment_id": ...}` only), so Flutter builds the visible seed message
   from the already-loaded `AssessmentInputEntity` + `AssessmentResultEntity` and passes the
   persisted session id to the chat controller for subsequent messages.
3. **Notify Caregiver is real, Book Doctor removed.** There is no booking feature/contract in
   this app, so the Book Doctor CTA was removed. Notify Caregiver uses the existing linked-user
   notification infrastructure and FCM path.
4. **`aiBpTriage` constant exists but is intentionally unused until Phase 8.**
5. **No charts regenerated.** Phase 7 changed Flutter/backend integration shape only, not
   taxonomy, dataset, model training, or analysis artifacts.

**Cleanup:**
- Restored accidental encoding damage in `push_notification_service.dart` and left only the
  minimal Future-handling fix required for `flutter analyze` to pass. Confirmed the file has no
  UTF-8 BOM.

---

## Phase 8 — BP Feature Integration Hook

Status: ✅ done (2026-07-01)

**Built:**
- Backend assessment requests now accept optional `source_vital_id` and persist it on
  `assessments.source_vital_id`, linked to `vital_signs.id` with `ON DELETE SET NULL`.
- `PostgresAssessmentRepository` saves and reads `source_vital_id`; `/bp-triage` assessments keep
  `assessment_type='bp_triage'` and are now traceable back to the originating BP reading.
- Alembic revision `phase7_notify_bp_link`
  (`Back-end/alembic/versions/20260701_1100_add_symptom_assessment_notification_type.py`) adds both
  the Phase-7 notification enum value and the Phase-8 `source_vital_id` column/index/FK.
- Flutter `AssessmentInputEntity` carries `sourceVitalId`; result submission routes BP-originated
  flows through `runBpTriage()` and normal guided flows through `runAssessment()`.
- `SymptomCheckerWizardPage(initialBpReading: ...)` starts a BP triage flow by selecting
  `heart_bp`, loading its symptoms, pre-filling systolic/diastolic/heart-rate values, and skipping
  category selection so the patient lands on symptom selection.
- Manual high/critical BP readings saved from `bp_card.dart` open the guided symptom flow after the
  reading is saved. The existing `/vitals/bp` backend path still handles the BP emergency alert.

**DoD check:**
- Backend regression: `./venv/Scripts/python.exe -m pytest tests/ -q` from `Back-end/` →
  **60 passed**, 6 existing warnings.
- New API test: `test_bp_triage_persists_source_vital_id` posts a critical BP triage payload,
  verifies red flags/critical urgency, and confirms the persisted `bp_triage` assessment keeps the
  originating `source_vital_id`.
- Flutter analyzer: `flutter analyze` from `Front-end/health_mate_app/` → **No issues found**.
- Flutter tests: `flutter test` from `Front-end/health_mate_app/` → **All tests passed**.
- Docker verification: `docker compose build api` succeeded; `docker compose up -d` started
  db/redis/api; `alembic upgrade head` succeeded after the dev-volume stamp correction below;
  verified `alembic_version=phase7_notify_bp_link` and `assessments.source_vital_id` exists in the
  real Postgres container; then `docker compose down`.

**Decisions/deviations (also written into `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` Phase 8):**
1. **No duplicate BP caregiver notification path was added.** The plan says Phase 8 should reuse
   existing BP alert cooldown logic, but the current codebase has an existing BP alert send path
   and no implemented cooldown mechanism. To avoid double-notifying caregivers, `/bp-triage` only
   persists the structured assessment and links it to the vital reading; the original `/vitals/bp`
   flow remains responsible for BP emergency alerts.
2. **The implemented Flutter hook is the manual BP-reading path.** `bp_card.dart` creates a real
   `VitalSign`, then opens the guided `heart_bp` flow only when that saved reading is high/critical.
   Dashboard "check now" shortcuts that do not have a real reading still open the normal guided
   checker, because there is no originating `vital_signs.id` to link.
3. **Docker dev-volume correction:** this local volume had Phase-6 tables already created by
   `Base.metadata.create_all` while Alembic was still at an older revision. It was stamped to
   `phase6_symptom_checker` before applying `alembic upgrade head`; this is a development-volume
   repair note, not a production migration step.

**Cleanup:**
- Docker containers were stopped with `docker compose down`. Test caches are removed after this
  phase's final documentation pass.

---

## Phase 9 — Optional LLM Phrasing Layer

Status: ✅ done (2026-07-01)

**Built:**
- `Back-end/app/application/interfaces/assessment_phraser.py` defines the phrasing boundary.
- `Back-end/app/infrastructure/phrasing/assessment_phraser.py` provides:
  - `StaticAssessmentPhraser` no-op fallback.
  - `OpenAICompatibleAssessmentPhraser`, an optional chat-completions adapter that requests JSON
    with only `patient_message` and `caregiver_summary`.
- `Back-end/app/core/config.py` gained:
  `SYMPTOM_CHECKER_LLM_PHRASING_ENABLED`, `SYMPTOM_CHECKER_LLM_API_KEY`,
  `SYMPTOM_CHECKER_LLM_MODEL`, `SYMPTOM_CHECKER_LLM_BASE_URL`,
  `SYMPTOM_CHECKER_LLM_TIMEOUT_SECONDS`.
- `run_assessment()` and `run_bp_triage()` accept an optional phraser. `/bp-triage` applies phrasing
  after the BP-specific remeasure action override so phrased text sees the final action.

**DoD check:**
- Backend tests: `./venv/Scripts/python.exe -m pytest tests/ -q` → **63 passed** at Phase-9
  sign-off, then **77 passed** after later QA additions.
- Tests verify static fallback is complete, an LLM client failure returns the static result, and
  the phraser can update only patient/caregiver text while urgency/action/prediction remain stable.

**Decision:**
- LLM phrasing is **disabled by default**. This is a production-safe choice because Phase 9 is
  optional and must never be load-bearing for diagnosis or recommendations.

---

## Phase 10 — Localization & Encoding Audit

Status: ✅ done (2026-07-01)

**Built:**
- `Back-end/tests/quality/test_encoding_audit.py` scans the Phase-10 paths for invalid UTF-8,
  UTF-8 BOM, and common mojibake markers:
  `Symptom-Checker/README.md`, `Symptom-Checker/app.py`, `Symptom-Checker/Data/**/*.json`,
  `Symptom-Checker/Data/**/*.js`, `Back-end/app/api/v1/ai.py`,
  `Back-end/app/services/ai_service.py`, and Flutter `assets/translations/{ar,en}.json`.

**DoD check:**
- Backend tests: `./venv/Scripts/python.exe -m pytest tests/ -q` → **64 passed** when the encoding
  audit was introduced.

**Decision:**
- No broad rewrite was performed. The audited files already decoded as UTF-8 and did not contain
  the configured mojibake markers, so the durable fix was adding the CI-style pytest gate.

---

## Phase 11 — Testing & QA

Status: ✅ done (2026-07-01)

**Built:**
- Extended backend API tests for bilingual parity:
  same category IDs, same symptom IDs, localized synonym payloads, same top-prediction IDs,
  same red-flag codes, same urgency, caregiver notification routing independent of patient
  language, BP handoff persistence, chat-from-assessment, and Phase-12 metrics/flag behavior.
- Added `Back-end/tests/services/test_ai_service_phrase_extraction.py` for the six exact free-text
  phrases in the plan/source doc. These phrases belong to the legacy free-text extractor, while
  v2 remains structured.
- Added synonyms to the v2 symptom payload and Flutter model/search path so local symptom search
  can resolve backend-provided synonym terms.
- Extended Flutter tests for `source_vital_id` serialization and synonym model parsing.

**DoD check:**
- Backend tests: `./venv/Scripts/python.exe -m pytest tests/ -q` → **75 passed** before rollout
  tests, **77 passed** after Phase 12.
- Flutter analyzer: `flutter analyze` → **No issues found**.
- Flutter tests: `flutter test` → **All tests passed**.

**Decision/deviation:**
- The plan's "symptom search/synonyms" row was implemented as additive v2 symptom metadata plus
  Flutter local search over `name`, `id`, and `synonyms`. No new medical mapping was invented.
- The six natural-language phrases are covered through the existing legacy free-text extractor,
  not v2 `/assessment`, because v2 is intentionally structured and does not parse free text.

---

## Phase 12 — Rollout

Status: ✅ done (2026-07-01)

**Built:**
- Backend rollout flag: `SYMPTOM_CHECKER_V2_ENABLED` / `settings.symptom_checker_v2_enabled`
  defaults to `true`. When false, v2 structured endpoints return
  `error_code="symptom_checker_v2_disabled"` while legacy v1 routes remain in place.
- Flutter rollout flag: `--dart-define=SYMPTOM_CHECKER_V2_ENABLED=false` routes patient/caregiver
  Check tabs back to the old `SymptomCheckerPage`; high/critical BP manual-reading fallback also
  opens the old checker when v2 is disabled.
- Rollout monitoring:
  `Back-end/app/application/services/symptom_checker_metrics.py` tracks assessment count,
  top-prediction distribution, urgency distribution, red-flag trigger rate, caregiver-notification
  rate, and avg/max assessment latency.
- `GET /api/v1/ai/assessment/rollout-metrics` returns the current in-process metrics snapshot.

**DoD check:**
- Backend tests: `./venv/Scripts/python.exe -m pytest tests/ -q` → **77 passed**, 6 existing
  warnings.
- Flutter analyzer: `flutter analyze` → **No issues found**.
- Flutter tests: `flutter test` → **All tests passed**.
- Docker verification: from `Back-end/`, `docker compose build api` succeeded,
  `docker compose up -d` started db/redis/api healthy, `docker compose exec -T api alembic upgrade head`
  succeeded, `GET http://localhost:8000/docs` returned `200`, then `docker compose down`.

**Decision:**
- Metrics are in-process and reset on API restart. That is sufficient for the current graduation
  rollout surface without adding new infrastructure; production-grade long-window monitoring can
  later export the same counters to Prometheus/observability tooling.
