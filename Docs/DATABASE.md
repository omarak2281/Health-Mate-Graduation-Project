# Database

Health Mate's system of record is PostgreSQL 15, accessed through SQLAlchemy's
async ORM (`asyncpg` driver) and versioned with Alembic. This document is built
directly from the 21 model classes in `Back-end/app/models/` and the Alembic
migration history — not from any prior schema write-up — and it calls out a
couple of things the models reveal that aren't obvious from the API alone.

## 1. Entity-relationship diagram

```mermaid
erDiagram
    USERS ||--o{ PATIENT_CAREGIVER_LINKS : "as patient"
    USERS ||--o{ PATIENT_CAREGIVER_LINKS : "as caregiver"
    USERS ||--o{ VITAL_SIGNS : has
    USERS ||--o{ MEDICATIONS : has
    USERS ||--o{ MEDICATION_ADHERENCE : logs
    USERS ||--o{ MEDICAL_CONTACTS : has
    USERS ||--o{ NOTIFICATIONS : receives
    USERS ||--o{ CALL_SESSIONS : "as caller"
    USERS ||--o{ CALL_SESSIONS : "as callee"
    USERS ||--o{ IOT_DEVICES : owns
    USERS ||--o{ MEDICINE_BOX_DRAWERS : owns
    USERS ||--o{ REGISTERED_DEVICES : owns
    USERS ||--o| PATIENT_CALIBRATIONS : has
    USERS ||--o{ CALIBRATION_SAMPLES : has
    USERS ||--o{ BP_REMINDERS : has
    USERS ||--o{ AUDIT_LOGS : generates
    USERS ||--o{ ASSESSMENTS : "took (nullable)"
    USERS ||--o{ CHAT_SESSIONS : "owns (nullable)"
    USERS ||--o{ BP_ALERT_COOLDOWNS : has

    MEDICATIONS ||--o{ MEDICATION_ADHERENCE : "confirmed by"

    VITAL_SIGNS ||--o| ASSESSMENTS : "triggered (nullable)"

    ASSESSMENTS ||--o{ ASSESSMENT_SYMPTOMS : contains
    ASSESSMENTS ||--o{ RED_FLAGS_TRIGGERED : contains
    ASSESSMENTS ||--o{ CHAT_SESSIONS : "seeded (nullable)"
    CHAT_SESSIONS ||--o{ CHAT_MESSAGES : contains

    USERS {
        uuid id PK
        string email UK
        string firebase_uid UK
        enum role "patient | caregiver"
        boolean is_active
        boolean is_verified
        string fcm_token
    }

    PATIENT_CAREGIVER_LINKS {
        uuid id PK
        uuid patient_id FK
        uuid caregiver_id FK
        boolean is_active
        boolean is_primary "1 active primary per patient (partial unique index)"
    }

    VITAL_SIGNS {
        uuid id PK
        uuid user_id FK
        int systolic "nullable - pending device readings"
        int diastolic "nullable"
        int heart_rate
        int spo2
        enum risk_level "normal|low|moderate|high|critical"
        enum measurement_status "completed|completed_pending_bp|rejected"
        string rejection_reason
        float model_systolic "raw model output"
        float model_diastolic
        float calibrated_systolic
        float calibrated_diastolic
        string calibration_status
        string device_id
    }

    BP_ALERT_COOLDOWNS {
        uuid patient_id PK_FK
        string risk_level PK
        datetime last_sent_at
    }

    MEDICATIONS {
        uuid id PK
        uuid user_id FK
        string name
        string dosage
        array scheduled_times "HH:MM strings"
        boolean use_smart_box
        int drawer_number "1-6"
    }

    MEDICATION_ADHERENCE {
        uuid id PK
        uuid medication_id FK
        uuid user_id FK
        datetime taken_at
        string image_url "optional proof photo"
    }

    MEDICAL_CONTACTS {
        uuid id PK
        uuid user_id FK
        string name
        string phone
        enum contact_type "doctor|clinic|pharmacy|emergency|family"
    }

    NOTIFICATIONS {
        uuid id PK
        uuid user_id FK
        enum notification_type
        string title
        text message
        json data
        boolean is_read
    }

    CALL_SESSIONS {
        uuid id PK
        uuid caller_id FK
        uuid callee_id FK
        enum call_type "audio|video"
        enum status "idle|ringing|in_call|ended|rejected|busy|missed|failed"
        string offer_sdp
        string answer_sdp
        int duration_seconds
    }

    IOT_DEVICES {
        uuid id PK
        uuid user_id FK
        enum device_type "ppg_sensor|ecg_sensor|medicine_box"
        string device_serial UK
        enum status "connected|disconnected|unstable"
    }

    MEDICINE_BOX_DRAWERS {
        uuid id PK
        uuid user_id FK
        int drawer_number
        boolean is_occupied
        boolean led_active
    }

    REGISTERED_DEVICES {
        uuid id PK
        string device_id UK
        string token_hash
        uuid patient_id FK
        boolean last_leads_connected
        boolean last_finger_detected
    }

    PATIENT_CALIBRATIONS {
        uuid patient_id PK_FK
        float sbp_scale
        float sbp_offset
        float dbp_scale
        float dbp_offset
        int samples_count
        string calibration_status
        boolean drift_flag
        float baseline_raw_mean_sbp
        float baseline_raw_mean_dbp
    }

    CALIBRATION_SAMPLES {
        uuid id PK
        uuid patient_id FK
        float model_sbp
        float model_dbp
        float cuff_sbp
        float cuff_dbp
    }

    BP_REMINDERS {
        uuid id PK
        uuid patient_id FK
        string scheduled_time "HH:MM"
    }

    AUDIT_LOGS {
        uuid id PK
        uuid user_id FK "nullable"
        string event_type
        json event_data
        string ip_address
    }

    ASSESSMENTS {
        uuid id PK
        uuid user_id FK "nullable"
        uuid source_vital_id FK "nullable - links BP triage to its reading"
        json known_conditions
        json vitals
        json top_predictions
        string urgency
        boolean should_notify_caregiver
        boolean should_remeasure
    }

    ASSESSMENT_SYMPTOMS {
        uuid id PK
        uuid assessment_id FK
        string symptom_id
        int severity
    }

    RED_FLAGS_TRIGGERED {
        uuid id PK
        uuid assessment_id FK
        string code
        int severity
    }

    CHAT_SESSIONS {
        uuid id PK
        uuid user_id FK "nullable"
        uuid assessment_id FK "nullable"
        string state
        boolean seeded_from_assessment
    }

    CHAT_MESSAGES {
        uuid id PK
        uuid session_id FK
        string role
        text message
        json payload
    }
```

## 2. Tables at a glance

| Table | Purpose | PK | Notable constraints |
|---|---|---|---|
| `users` | Patients and caregivers (same table, `role` discriminates) | `id` | unique `email`, unique `firebase_uid` |
| `patient_caregiver_links` | Many-to-many patient↔caregiver linking | `id` | partial unique index: only one active primary caregiver per patient |
| `vital_signs` | BP/HR/SpO2 readings, sensor or manual | `id` | FK `user_id` → `users` (cascade delete) |
| `bp_alert_cooldowns` | Prevents duplicate emergency alerts per risk tier | composite (`patient_id`, `risk_level`) | — |
| `medications` | Medication catalog + schedule + smart-box drawer assignment | `id` | FK `user_id` |
| `medication_adherence` | "Taken" confirmations, optional photo proof | `id` | FK `medication_id`, FK `user_id` |
| `medical_contacts` | Doctors/clinics/pharmacies/emergency/family contacts | `id` | FK `user_id` |
| `notifications` | All push/in-app notification records | `id` | FK `user_id` |
| `call_sessions` | WebRTC audio/video call state | `id` | FK `caller_id`, FK `callee_id` (both → `users`) |
| `iot_devices` | Generic sensor/medicine-box device registry | `id` | unique `device_serial` |
| `medicine_box_drawers` | Per-drawer occupancy/LED state | `id` | FK `user_id` |
| `registered_devices` | BP hardware device auth (device_id + hashed token → patient) | `id` | unique `device_id` |
| `patient_calibrations` | Current per-patient BP calibration coefficients | `patient_id` (1:1 with user) | — |
| `calibration_samples` | Historical cuff-vs-model reading pairs | `id` | FK `patient_id` |
| `bp_reminders` | Scheduled daily BP measurement reminder times | `id` | FK `patient_id` |
| `audit_logs` | Security/compliance event trail | `id` | FK `user_id` (nullable, `SET NULL` on delete) |
| `assessments` | Symptom-checker v2 assessment results | `id` | FK `user_id` (nullable), FK `source_vital_id` (nullable) |
| `assessment_symptoms` | Symptoms selected within one assessment | `id` | FK `assessment_id` (cascade) |
| `red_flags_triggered` | Red flags fired within one assessment | `id` | FK `assessment_id` (cascade) |
| `chat_sessions` | Symptom-checker chat session state (Postgres model exists — see Section 4) | `id` | FK `user_id`, FK `assessment_id` (both nullable) |
| `chat_messages` | Individual chat turns | `id` | FK `session_id` (cascade) |

## 3. Relationships worth calling out specifically

- **`patient_caregiver_links` is the only many-to-many junction table** in the
  schema — every other user-owned table (vitals, medications, devices,
  calibration, etc.) is a straightforward one-to-many from `users`. A single
  patient can have multiple caregivers, and a single caregiver can monitor
  multiple patients, but a **partial unique index**
  (`uq_patient_active_primary_caregiver`, `WHERE is_primary = true AND
  is_active = true`) enforces that a patient can have at most one *active
  primary* caregiver at a time, while still allowing any number of
  non-primary or inactive links — this is a real database-level invariant,
  not just an application-level check.
- **`assessments.source_vital_id`** is a nullable foreign key straight to
  `vital_signs` — this is the literal database trace of the BP-triage
  handoff described in `SYMPTOM_CHECKER.md`: when `/bp-triage` runs off a real
  BP reading, the resulting assessment row can be linked directly back to the
  vital sign that triggered it. Most assessments (run from the standalone
  symptom-checker wizard) will have this column `NULL`.
- **`vital_signs.systolic`/`diastolic` are nullable by design, not by
  oversight** — the model file's own inline comments (a developer visibly
  reasoning through the constraint live, not a formal docstring) walk through
  why: a sensor-submitted reading can exist in a `completed_pending_bp` state
  (HR/SpO2 known, BP not yet confirmed — see `BP_PREDICTION.md` Section 14)
  before a cuff-confirmed value ever arrives, so the column cannot be
  `NOT NULL` at the database level even though a "real," validated reading
  always has both.
- **Two separate device-registry tables exist for two different purposes.**
  `iot_devices` is a generic sensor/medicine-box registry (used by the
  mock/legacy `iot_service.py` path), while `registered_devices` is the table
  actually used for BP-hardware authentication in production — it maps a
  `device_id` + hashed token to a specific patient and is what
  `get_device_from_headers()` checks in `POST /vitals/bp/submit`. The two do
  not reference each other, and a given physical device is not guaranteed to
  have a row in both.

## 4. A table that exists in the schema but isn't where chat data actually lives

`chat_sessions` and `chat_messages` are real SQLAlchemy models with real
migrations (`20260701_1000_phase6_symptom_checker_persistence.py`), including
foreign keys back to `users` and `assessments`. But the `ChatSessionRepository`
interface that the symptom checker's use cases actually depend on
(`app/core/di.py`'s `get_chat_sessions()`) resolves to either
`RedisChatSessionRepository` or `InMemoryChatSessionRepository` — neither of
which touches these Postgres tables at all; both store chat state as
Redis keys or plain in-process Python objects respectively. The tables are not
dead code (they're created by a real migration and could be wired in as a
third `ChatSessionRepository` implementation later, which is exactly the kind
of swap the interface exists to make easy), but as of the current code, no
runtime path writes to `chat_sessions`/`chat_messages` — chat state lives in
Redis or memory, and would not survive a container restart under the
`InMemoryChatSessionRepository` configuration.

## 5. Schema evolution, from the migration history itself

The `alembic/versions/` directory's own filenames trace a real, rapid
build-out rather than a single upfront design — worth reading as a timeline,
not just a folder listing:

`001_initial` → `002_add_firebase_auth_fields` → `003_add_family_to_contact_type`
→ `004_add_user_profile_fields` → `..._add_medication_adherence_table` →
`..._fix_medication_columns` → `20260701_..._phase6_symptom_checker_persistence`
→ `20260701_..._add_symptom_assessment_notification_type` →
`20260702_..._bp_phase1` → `20260702_..._bp_pipeline_fixes` →
`20260702_..._add_calibration_drift_columns` →
`20260702_..._add_device_heartbeat_columns` →
`20260703_..._add_bp_reminders_table` → `20260703_..._add_spo2_rejection_reason`
→ `20260704_..._add_uppercase_family_contact_type` →
`20260705_..._add_call_sessions_table`.

Two things stand out from this sequence: the BP calibration/drift/heartbeat
machinery (Sections in `BP_PREDICTION.md` and `ARCHITECTURE.md`) was all added
within a two-day window (July 2), consistent with it being built as one
connected feature rather than incrementally bolted on; and there are two
separate migrations touching the `family` contact type
(`003_add_family_to_contact_type`, then
`20260704_add_uppercase_family_contact_type` a month-plus later) — a real,
minor sign of an enum-casing bug needing a follow-up fix, not a hypothetical
one.

## 6. Connection and session management

`app/core/database.py` creates a single async SQLAlchemy engine
(`postgresql+asyncpg://`, converted from the `postgresql://` URL in
`.env`) with `pool_size=10`, `max_overflow=20`, and `pool_pre_ping=True` (so a
dropped connection is detected and replaced rather than surfacing as a query
failure). `get_db()` is the FastAPI dependency every route uses to obtain a
session; it commits on clean exit and rolls back on any exception, so a
router does not need to manage transactions manually in the common case.

[IMAGE REQUIRED] Description: A polished, exported version of the ER diagram in Section 1 (e.g. rendered via a dedicated ERD tool from the live schema) for inclusion in the printed thesis, since the Mermaid source above renders correctly in Markdown viewers but a dedicated export may read more cleanly at print resolution for a 21-table diagram. Suggested Location: Chapter on Database Design in the main thesis document. Purpose: the Mermaid diagram in this file is the authoritative, code-derived source — this image request is only about print/typeset formatting, not missing content.

## 7. Note on the pre-existing `Database-Tables.png`

The repository root already contains a `Database-Tables.png` (a `dbdiagram.io`
export). It is **out of date** relative to the current models and should not
be used in place of Section 1's diagram: it is missing `registered_devices`,
`patient_calibrations`, `calibration_samples`, `bp_reminders`,
`bp_alert_cooldowns`, and the entire `assessments`/`chat_sessions` family, and
it shows `medications` with a materially different, older column set
(`time_slots`, `frequency`, `start_date`/`end_date`,
`enable_led`/`enable_buzzer`/`enable_notification`) that does not match the
`Medication` model in the current codebase (`scheduled_times`,
`times_per_day`, `use_smart_box`, `drawer_number` — no `enable_*` flags, no
`start_date`/`end_date`). It reflects an earlier snapshot of the schema, from
before the BP hardware/calibration and symptom-checker-v2 features were
built. The Mermaid diagram in Section 1 is generated directly from the models
as they exist today and should be treated as the current source of truth.
