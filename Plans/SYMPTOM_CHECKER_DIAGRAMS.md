# Symptom Checker v2 — Architecture & Flow Diagrams

Documentation/presentation support for `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` +
`Plans/SYMPTOM_CHECKER_PROGRESS.md`. All diagrams are Mermaid (renders natively in VS Code
preview, GitHub, and most modern markdown viewers — no external tool needed). Chart images
(PNG, real numbers from the actual artifacts) are in
`Symptom-Checker/Output/Production/analysis/`, indexed in that folder's `analysis_index.md`.

---

## 1. End-to-end pipeline (Phases 1-12, what actually got built)

```mermaid
flowchart TD
    subgraph Legacy["Legacy data (untouched, read-only)"]
        A1["Data/General/*.json<br/>23 diseases, 34 symptoms"]
        A2["Data/Heart/*.json<br/>18 diseases, 18 symptoms"]
    end

    subgraph Phase1["Phase 1 — Taxonomy Migration"]
        B1["migration/migrate_legacy_taxonomy.py"]
        B2["taxonomy/categories.json (9)<br/>taxonomy/symptoms.json (108)<br/>taxonomy/diseases.json (41)"]
        B3["migration_report.md<br/>(dedup log, category mapping,<br/>59 orphan-stub symptoms)"]
    end

    subgraph Phase2["Phase 2 — Rule Engine (Back-end/app/domain)"]
        C1["red_flag_rules.py<br/>evaluate_red_flags()"]
        C2["urgency_rules.py<br/>determine_urgency()"]
        C3["bp_rules.py<br/>shared BP thresholds"]
    end

    subgraph Phase3["Phase 3 — Structured Dataset Generation"]
        D1["data_pipeline/generate_structured_cases.py<br/>(imports Phase 2's rule engine<br/>to compute each case's urgency)"]
        D2["Data/cases/dataset.jsonl<br/>12,300 cases, 300/class"]
        D3["validate_dataset.py → PASS"]
    end

    subgraph Phase4["Phase 4 — ML Training"]
        E1["training/feature_engineering.py<br/>build_features() — 232-dim vector"]
        E2["training/train_final.py<br/>LightGBM, 300 estimators"]
        E3["Output/Production/best_model_v2.pkl<br/>top-1: 85.8% · top-3: 95.5%"]
    end

    subgraph Phase5["Phase 5 — Backend Clean Architecture"]
        F1["infrastructure/ml/disease_classifier_impl.py<br/>(reuses Phase 4's feature_engineering.py)"]
        F2["infrastructure/persistence/json_taxonomy_repository.py<br/>(reads Phase 1's taxonomy/*.json)"]
        F3["application/use_cases/run_assessment.py<br/>(reuses Phase 2's rule engine directly)"]
        F4["api/v1/ai.py<br/>5 new endpoints"]
    end

    subgraph Phase6to12["Phases 6-12 — Persistence, Flutter, QA, Rollout"]
        G1["Postgres assessments + Redis chat sessions"]
        G2["Flutter guided wizard + BP hook"]
        G3["Optional LLM phrasing<br/>(static fallback)"]
        G4["Encoding audit + QA matrix + rollout flag/metrics"]
    end

    A1 --> B1
    A2 --> B1
    B1 --> B2
    B1 --> B3
    B2 --> D1
    C1 --> D1
    C2 --> D1
    C3 -.-> C2
    D1 --> D2
    D2 --> D3
    D3 --> E1
    B2 --> E1
    E1 --> E2
    E2 --> E3
    B2 --> F2
    E3 --> F1
    E1 --> F1
    F1 --> F3
    F2 --> F3
    C1 --> F3
    C2 --> F3
    F3 --> F4
    F4 --> G1
    F4 --> G2
    F3 --> G3
    G1 --> G4
    G2 --> G4
    G3 --> G4
```

**Key point for the writeup:** the rule engine (Phase 2) and the feature engineering module
(Phase 4) are each a *single implementation* consumed by two different phases — Phase 3's
dataset generator and Phase 5's live backend both import the exact same
`red_flag_rules.py`/`urgency_rules.py`/`feature_engineering.py`, so the synthetic training
labels and the production decision logic can never drift apart.

---

## 2. Clean Architecture layers (Back-end, Phase 5)

```mermaid
flowchart TB
    subgraph API["api/ (thin controllers, <=15 lines each)"]
        R1["GET /categories"]
        R2["GET /taxonomy/symptoms"]
        R3["POST /assessment"]
        R4["POST /bp-triage"]
        R5["POST /chat/from-assessment"]
        R6["GET /assessment/rollout-metrics"]
        FLAG["SYMPTOM_CHECKER_V2_ENABLED"]
    end

    subgraph APP["application/ (orchestration, no I/O of its own)"]
        U1["get_categories"]
        U2["get_available_symptoms"]
        U3["run_assessment"]
        U4["run_bp_triage"]
        U5["start_chat_from_assessment"]
        MET["services/symptom_checker_metrics.py"]
        DTO["dto/assessment_dto.py<br/>(response shape + static<br/>localized text templates)"]
    end

    subgraph DOM["domain/ (pydantic + stdlib ONLY — zero framework deps)"]
        ENT["entities/<br/>Category · Disease · Symptom<br/>AssessmentInput · RedFlag"]
        VO["value_objects/<br/>Urgency · AgeGroup"]
        RULES["rules_engine/<br/>red_flag_rules · urgency_rules · bp_rules<br/>(pure functions, 100% branch-tested)"]
        IFACE["interfaces/<br/>TaxonomyRepository · DiseaseClassifier<br/>AssessmentRepository* · ChatSessionRepository*"]
    end

    subgraph INFRA["infrastructure/ (implements the interfaces)"]
        REPO["persistence/json_taxonomy_repository.py<br/>reads Symptom-Checker/taxonomy/*.json"]
        CHAT["persistence/redis_chat_session_repository.py"]
        ASSESS["persistence/postgres_assessment_repository.py"]
        PHRASE["phrasing/assessment_phraser.py<br/>optional LLM, static fallback"]
        ML1["ml/model_registry.py<br/>loads best_model_v2.pkl,<br/>warns on sklearn version mismatch"]
        ML2["ml/structured_feature_builder.py<br/>wraps Symptom-Checker's feature_engineering.py"]
        ML3["ml/disease_classifier_impl.py<br/>LightGbmDiseaseClassifier"]
    end

    R1 --> U1 --> IFACE
    R2 --> U2 --> IFACE
    R3 --> U3
    R4 --> U4 --> U3
    R5 --> U5
    R6 --> MET
    FLAG --> R1
    FLAG --> R2
    FLAG --> R3
    FLAG --> R4
    FLAG --> R5
    U3 --> RULES
    U3 --> ENT
    U3 --> DTO
    U3 --> PHRASE
    U3 --> MET
    U3 --> IFACE
    IFACE -.implemented by.-> REPO
    IFACE -.implemented by.-> CHAT
    IFACE -.implemented by.-> ASSESS
    IFACE -.implemented by.-> ML3
    ML3 --> ML1
    ML3 --> ML2
    RULES --> VO
```

**Dependency rule enforced throughout:** arrows only point *inward* — `domain/` never imports
from `application/` or `infrastructure/`; `infrastructure/` implements `domain/interfaces/` but
`domain/` has no idea `infrastructure/` exists. This is what makes the rule engine's 100%
branch-coverage test suite possible without a database or FastAPI running at all.

---

## 3. Red-flag + urgency decision flow (Phase 2, the safety-critical piece)

```mermaid
flowchart TD
    START(["Selected symptoms + vitals + known conditions"]) --> RF{"For each symptom:<br/>is it flagged red_flag=true<br/>in the taxonomy?"}
    RF -->|no| SKIP["not a red flag"]
    RF -->|yes| THRESH{"severity >= threshold?<br/>(2 normally, 1 for<br/>syncope/loss_of_consciousness)"}
    THRESH -->|no| SKIP
    THRESH -->|yes| FLAG["RedFlag(code, severity)"]

    FLAG --> U1{"any red flag<br/>severity >= 3?<br/>OR vitals = critical?"}
    U1 -->|yes| CRIT(["urgency = CRITICAL"])
    U1 -->|no| U2{"any red flag present?<br/>OR vitals = high?"}
    U2 -->|yes| HIGH(["urgency = HIGH"])
    U2 -->|no| U3{">=2 symptoms severity>=2?<br/>OR known hypertension<br/>+ elevated BP?"}
    U3 -->|yes| MOD(["urgency = MODERATE"])
    U3 -->|no| LOW(["urgency = LOW"])

    CRIT --> COMPOSE["Phase 5 aggregator:<br/>final = max(rule_urgency, ml_urgency)<br/>— rule engine can only ESCALATE,<br/>never suppress"]
    HIGH --> COMPOSE
    MOD --> COMPOSE
    LOW --> COMPOSE
```

Verified end-to-end examples from the actual test suite / real container run:
- `chest_pain`(severity 3) + `shortness_of_breath`(severity 2) → **critical** (13/13 contract tests, real model)
- `syncope`(severity 1) alone → **high** ("fainting = emergency" scenario)
- `sudden_numbness` + `trouble_speaking` + `loss_of_balance` (all severity >=3) → **critical** ("stroke symptoms" scenario)

---

## 4. `POST /assessment` request flow (Phase 5, sequence diagram)

```mermaid
sequenceDiagram
    participant C as Client (Flutter, future Phase 7)
    participant API as api/v1/ai.py
    participant UC as run_assessment (use case)
    participant TAX as JsonTaxonomyRepository
    participant RULES as red_flag_rules + urgency_rules
    participant ML as LightGbmDiseaseClassifier
    participant PH as AssessmentPhraser
    participant MET as rollout_metrics

    C->>API: POST /assessment?lang=ar {symptoms, vitals, ...}
    API->>API: validate symptoms non-empty (else 400 no_symptoms_selected)
    API->>UC: run_assessment(assessment, taxonomy, classifier, lang)
    UC->>TAX: get_symptom(id) for each selected symptom
    TAX-->>UC: red_flag=true/false per symptom
    UC->>RULES: evaluate_red_flags(symptoms)
    RULES-->>UC: red_flags[]
    UC->>RULES: determine_urgency(assessment, red_flags)
    RULES-->>UC: rule_urgency
    UC->>ML: predict_top_k(assessment, k=3)
    alt classifier succeeds
        ML-->>UC: [DiseasePrediction, ...]
        UC->>TAX: get_disease(id) for each prediction (name, category, default_urgency)
    else classifier raises
        Note over UC: caught — top_predictions degrades to []<br/>red_flags/rule_urgency still computed
    end
    UC->>UC: final_urgency = max(rule_urgency, top1.default_urgency)
    UC->>UC: build localized DTO (urgency_label, action text, disclaimer)
    opt Phase 9 phrasing enabled
        UC->>PH: phrase(assessment, result, lang)
        PH-->>UC: same DTO with patient/caregiver text only
    end
    UC-->>API: AssessmentResultDTO
    API->>MET: record_assessment(result, latency, notified)
    API-->>C: 200 {top_predictions, urgency, urgency_label,<br/>red_flags, recommended_action_text, ...}
```

---

## 5. v1 vs v2 symptom checker — what changed and why

```mermaid
flowchart LR
    subgraph V1["v1 — still in production (ai_service.py)"]
        direction TB
        V1A["symptoms joined into<br/>one text string"] --> V1B["CountVectorizer<br/>(181 features)"] --> V1C["MLPClassifier"] --> V1D["ONE disease name<br/>no confidence, no urgency,<br/>no severity/duration/vitals input"]
    end

    subgraph V2["v2 — default when rollout flag is enabled"]
        direction TB
        V2A["symptoms + severity +<br/>duration + age + risk factors<br/>+ vitals"] --> V2B["build_features()<br/>232-dim structured vector"] --> V2C["LightGBM<br/>(41-class multiclass)"] --> V2D["top-3 diseases + confidence<br/>+ urgency (rule engine escalates)<br/>+ red flags + localized guidance"]
    end

    V1 -."architecturally cannot accept<br/>structured input — replacement,<br/>not patching (plan §2.2)".-> V2
```

---

## 6. Where each phase's real numbers live (for the writeup/slides)

| Phase | Chart(s) | Report |
|---|---|---|
| 1 — Migration | `analysis/01_taxonomy_before_after.png`, `02_diseases_per_category.png` | `Symptom-Checker/migration/migration_report.md` |
| 2 — Rule engine | (diagram 3 above) | 43 pytest tests, 100% branch coverage — `Back-end/tests/domain/rules_engine/` |
| 3 — Dataset | `analysis/03_dataset_class_balance.png`, `04_urgency_distribution.png` | `Symptom-Checker/Data/cases/dataset_report.md` |
| 4 — Training | `analysis/05_model_comparison.png` through `09_covid19_share_check.png` | `Symptom-Checker/Output/Production/evaluation_report_v2.md` |
| 5 — Backend | (diagrams 2 and 4 above) | 13 pytest contract tests — `Back-end/tests/api/v1/test_assessment_endpoints.py`; real Docker container run logged in `Plans/SYMPTOM_CHECKER_PROGRESS.md` |
| 6-8 — Persistence/Flutter/BP | (diagrams 2 and 4 above) | `Back-end/tests/api/v1/test_assessment_endpoints.py`, `Front-end/health_mate_app/test/widget_test.dart` |
| 9-12 — Phrasing/QA/Rollout | (diagrams 1, 2, and 4 above) | `Back-end/tests/application/test_assessment_phrasing.py`, `Back-end/tests/quality/test_encoding_audit.py`, `Back-end/tests/services/test_ai_service_phrase_extraction.py`, rollout tests in `test_assessment_endpoints.py` |

Regenerate all PNG charts any time the taxonomy/dataset/model changes:
```bash
cd Symptom-Checker
python analysis/generate_visualizations.py
```
