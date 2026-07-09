# Health Mate Backend API

Medical-grade healthcare monitoring system with FastAPI.

## Features

✅ **Authentication**: JWT-based auth with role-based access control (Patient/Caregiver)  
✅ **Vitals Management**: Blood pressure monitoring with automatic risk calculation  
✅ **Medications**: Medicine tracking with medicine box integration  
✅ **IoT Integration**: Mock layer for development, production-ready architecture  
✅ **Patient-Caregiver Linking**: Many-to-many relationship management  
✅ **Audit Logging**: Complete event tracking for compliance  

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f api

# Stop services
docker-compose down
```

API will be available at: `http://localhost:8000`  
API Documentation: `http://localhost:8000/docs`

### Manual Setup

1. Create Python virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Start PostgreSQL and Redis

5. Run the API:
```bash
uvicorn app.main:app --reload
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/refresh` - Refresh token

### Users
- `GET /api/v1/users/me` - Get current user profile
- `PUT /api/v1/users/me` - Update profile
- `PUT /api/v1/users/me/password` - Change password
- `GET /api/v1/users/linked` - Get linked users
- `POST /api/v1/users/link/{user_id}` - Link with user

### Vitals
- `POST /api/v1/vitals/bp` - Create BP reading
- `GET /api/v1/vitals/bp/current` - Get current BP
- `GET /api/v1/vitals/bp/history` - Get BP history
- `GET /api/v1/vitals/bp/stats` - Get BP statistics

### Medications
- `POST /api/v1/medications` - Create medication
- `GET /api/v1/medications` - List medications
- `GET /api/v1/medications/{id}` - Get medication
- `PUT /api/v1/medications/{id}` - Update medication
- `DELETE /api/v1/medications/{id}` - Delete medication

### IoT Devices
- `GET /api/v1/iot/sensors/status` - Get sensors status
- `GET /api/v1/iot/sensors/data` - Get sensor readings
- `GET /api/v1/iot/medicine-box/drawers` - Get all drawers
- `POST /api/v1/iot/medicine-box/drawer/{num}/activate` - Activate drawer

### AI / Symptom Checker (`app/api/v1/ai.py`)
Two generations of endpoints live side by side — see
`Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md` for the full rationale. Both stay live; nothing
below is deprecated yet.

**v1 (original, text-based, still used by `AiSymptomChatPage`/`SymptomCheckerPage` in the Flutter app):**
- `GET /api/v1/ai/available-symptoms` - Categorized symptom list (legacy shape)
- `POST /api/v1/ai/symptom-checker` - Predict from a flat symptom list
- `POST /api/v1/ai/chat` - Free-text conversational symptom chat
- `GET /api/v1/ai/model-info` - v1 model metadata
- `GET /api/v1/ai/symptom-checker/history/{session_id}` - Chat history (still mocked response shape)

**v2 (new structured assessment flow — Clean Architecture layers, `app/domain`/`app/application`/`app/infrastructure`):**
- `GET /api/v1/ai/categories?lang=` - The 9 fixed symptom categories
- `GET /api/v1/ai/taxonomy/symptoms?category_id=&lang=` - Symptoms with `red_flag` flags, filterable by category
- `POST /api/v1/ai/assessment?lang=` - Structured assessment: symptoms+severity+vitals in, top-3 predictions + urgency + red flags out
- `POST /api/v1/ai/bp-triage?lang=` - Same as `/assessment`, adds `should_remeasure` for vitals-driven triage and can persist `source_vital_id`
- `POST /api/v1/ai/chat/from-assessment?lang=` - Seeds a chat session from an assessment result, returns `{"assessment_id"}`
- `POST /api/v1/ai/assessment/notify-caregiver?lang=` - Sends the current structured assessment summary to all active linked caregivers
- `GET /api/v1/ai/assessment/rollout-metrics` - Phase-12 in-process rollout counters/latency snapshot

All v2 endpoints take `lang` as a **query parameter** (not request body) and return
`urgency`/`recommended_action_text` at the **top level** of the response — this was a deliberate
fix over the v1 mismatches documented in the plan §1.6.
Set `SYMPTOM_CHECKER_V2_ENABLED=false` to disable only these v2 structured endpoints while keeping
the original v1 endpoints available.

### Symptom Checker v2 Persistence
Phase 6 persists the structured flow without changing the API response contracts:

- `app/models/symptom_assessment.py` defines `assessments`, `assessment_symptoms`,
  `red_flags_triggered`, `chat_sessions`, and `chat_messages`. `assessments.source_vital_id`
  links BP-originated triage assessments back to `vital_signs.id`.
- `alembic/versions/20260701_1000_phase6_symptom_checker_persistence.py` creates those tables.
- `app/infrastructure/persistence/postgres_assessment_repository.py` saves `/assessment`,
  `/bp-triage`, and `/chat/from-assessment` results to Postgres, including `source_vital_id`
  when a BP reading launched the flow.
- `app/infrastructure/persistence/redis_chat_session_repository.py` stores active chat session
  state in Redis. The original `/ai/chat` endpoint now uses the same repository instead of the
  old process-local dict.
- High-risk `/assessment` results automatically notify active linked caregivers using
  `NotificationService.send_symptom_assessment_alert`; the manual
  `/assessment/notify-caregiver` route uses the same notification/FCM path. The notification enum
  value is added by
  `alembic/versions/20260701_1100_add_symptom_assessment_notification_type.py`.
- The same Alembic revision also adds `assessments.source_vital_id`, its index, and the
  `vital_signs(id)` foreign key for Phase 8 BP triage linking.
- `app/infrastructure/phrasing/assessment_phraser.py` contains the optional Phase-9 LLM phrasing
  adapter. It is off by default and can only rewrite `patient_message` and `caregiver_summary`;
  static text is returned if disabled or failing.
- `app/application/services/symptom_checker_metrics.py` stores Phase-12 rollout metrics in memory:
  assessment count, top-prediction distribution, urgency distribution, red-flag trigger rate,
  caregiver-notification rate, and avg/max assessment latency.

Run migrations in an existing database with:

```bash
alembic upgrade head
```

In the current Docker development setup, `app.main` also calls `Base.metadata.create_all` on
startup, so newly added model tables are created automatically for local `docker compose up`.
If an older local Docker volume already has tables created by `create_all` but Alembic is behind,
stamp it to the last applied schema before upgrading, for example:

```bash
alembic stamp phase6_symptom_checker
alembic upgrade head
```

Use that only for the existing development-volume mismatch; fresh databases should just run
`alembic upgrade head`.

## Environment Variables

See `.env.example` for all configuration options.

Key variables:
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `JWT_SECRET` - Secret key for JWT tokens
- `IOT_MODE` - `mock` or `production`
- `SYMPTOM_CHECKER_V2_ENABLED` - defaults to `true`; set `false` to keep v1 fallback only
- `SYMPTOM_CHECKER_LLM_PHRASING_ENABLED` - defaults to `false`
- `SYMPTOM_CHECKER_LLM_API_KEY`, `SYMPTOM_CHECKER_LLM_MODEL`,
  `SYMPTOM_CHECKER_LLM_BASE_URL`, `SYMPTOM_CHECKER_LLM_TIMEOUT_SECONDS` - optional Phase-9 phrasing

## Project Structure

```
app/
├── api/
│   ├── dependencies.py     # Auth dependencies
│   ├── schemas/            # v2 request/response wire shapes (assessment_schemas.py, category_schemas.py)
│   └── v1/                 # API v1 routes
│       ├── auth.py, users.py, vitals.py, medications.py, iot.py
│       └── ai.py           # v1 (legacy) + v2 (structured assessment) AI routes, side by side
├── core/
│   ├── config.py           # Settings (incl. symptom_checker_taxonomy_path / _root_path for v2)
│   ├── database.py         # DB session
│   ├── security.py         # JWT & hashing
│   └── di.py               # Lightweight Depends()-compatible providers for the v2 layers
├── domain/                 # v2 only — Clean Architecture core, pydantic/stdlib only, no framework deps
│   ├── entities/           # category, disease, symptom, assessment (SelectedSymptom/Vitals/AssessmentInput), red_flag
│   ├── value_objects/      # urgency.py (Urgency literal + max_urgency), age_group.py
│   ├── rules_engine/       # red_flag_rules.py, urgency_rules.py, bp_rules.py — pure functions, 100% branch-tested
│   └── interfaces/         # taxonomy_repository, disease_classifier, assessment_repository, chat_session_repository
├── application/             # v2 only
│   ├── dto/assessment_dto.py       # plan §6.1 response shape + static localized urgency/action-text templates
│   └── use_cases/                  # run_assessment, get_categories, get_available_symptoms,
│                                     # start_chat_from_assessment, run_bp_triage
├── infrastructure/          # v2 only
│   ├── persistence/         # json_taxonomy_repository.py, postgres_assessment_repository.py,
│   │                         # redis_chat_session_repository.py
│   └── ml/                  # model_registry.py (loads best_model_v2.pkl, warns on sklearn version mismatch),
│                             # structured_feature_builder.py (wraps Symptom-Checker/training/feature_engineering.py),
│                             # disease_classifier_impl.py (LightGbmDiseaseClassifier)
├── models/                 # SQLAlchemy models
├── schemas/                # Pydantic schemas (v1 AI schemas: app/schemas/ai.py)
├── services/               # Business logic
│   ├── ai_service.py        # v1 symptom checker (text-based, still production)
│   └── iot_mock.py
└── main.py                 # FastAPI app
```

## Development

### Run tests
```bash
pytest tests/ -v
```
`tests/domain/rules_engine/` covers the v2 rule engine (100% branch coverage target — this is
the safety-critical red-flag/urgency logic). `tests/api/v1/test_assessment_endpoints.py` covers
the v2 endpoint contracts (en/ar, `lang` as query param, red-flags-survive-ML-failure, error
contract) by mounting just the `ai` router with dependency overrides — no live Postgres/Redis
needed to run this file. `tests/infrastructure/test_redis_chat_session_repository.py` covers
Redis chat-session serialization with a fake Redis client.

**Dependency note:** `scikit-learn` and `lightgbm` versions in `requirements.txt` must match
`Symptom-Checker/requirements.txt` exactly (currently `scikit-learn>=1.9.0`, `lightgbm>=4.6.0`)
or `infrastructure/ml/model_registry.py` will fail to unpickle `best_model_v2.pkl` — see the
inline comment in `requirements.txt` for why.

### Code quality
```bash
black app/
flake8 app/
mypy app/
```

## Production Deployment

1. Set `ENVIRONMENT=production` in `.env`
2. Set strong `JWT_SECRET`
3. Use managed PostgreSQL and Redis
4. Set `IOT_MODE=production` and connect real hardware
5. Configure CORS origins properly
6. Enable HTTPS

## License

Proprietary - Health Mate Project 2026
