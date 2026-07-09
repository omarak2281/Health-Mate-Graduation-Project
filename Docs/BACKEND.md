# Backend

The backend is a FastAPI application under `Back-end/app/`. `ARCHITECTURE.md`
covers the high-level split between the service-layer style (most features)
and the clean-architecture layer (symptom checker v2); this document goes one
level deeper into authentication, the API surface, each service, and — since
the goal here is an accurate picture rather than a flattering one — the real
gaps found by reading the code, not assumed from any prior write-up.

## 1. Authentication & authorization

### JWT (human users)

`app/core/security.py` implements password hashing (bcrypt, 12 rounds),
access-token issuance (`create_access_token`, default expiry from
`settings.access_token_expire_minutes`), and refresh-token issuance
(`create_refresh_token`, longer-lived, tagged `"type": "refresh"` in the
payload so it can't be reused as an access token). `POST /auth/login` returns
both tokens; `POST /auth/refresh` verifies the refresh token's type/signature,
confirms the user still exists and is active, and mints a **new** access +
refresh token pair.

`app/api/dependencies.py` provides the enforcement layer: `get_current_user`
(decodes the bearer token, loads the user, 401s on anything wrong or 403s if
inactive), and a `require_role()` factory used to build `require_patient`/
`require_caregiver` guards for role-restricted routes.

**Two real, verifiable gaps, not hypothetical ones:**

- **`POST /auth/logout` does not invalidate anything.** Its own docstring
  says so directly: *"In production, should blacklist token in Redis. For
  now, client should delete token."* The endpoint returns a success message
  and does nothing else — a token obtained before logout remains valid until
  its natural expiry.
- **Refresh tokens are not rotated server-side.** `POST /auth/refresh` issues
  a new refresh token but never invalidates the one that was just used —
  there is no token store/blacklist checked anywhere in the refresh path, so
  an old refresh token continues to work after being "replaced." This is a
  standard stateless-JWT tradeoff, but it means a leaked refresh token has no
  remediation path short of changing `jwt_secret` for everyone.

### Device authentication (IoT hardware)

Separate from user JWTs: `get_device_from_headers()` in `dependencies.py`
authenticates the BP hardware via two headers, `X-Device-ID` and
`X-Device-Token`, checked against the `registered_devices` table (device
lookup by ID, then `bcrypt.checkpw` against the stored `token_hash`). This is
what protects `POST /vitals/bp/submit` and `/vitals/bp/heartbeat` — a
completely separate trust boundary from user login, appropriate for a
headless device that can't hold a refreshable session.

### Patient–caregiver linking — implemented, but not encrypted

`POST /api/v1/users/link/{user_id}` links a patient and caregiver by target
user ID directly — the endpoint's own docstring states plainly, *"In
production, this should use QR code scanning"*, meaning the backend itself
does not treat the current mechanism as fully hardened. The Flutter app does
have a real QR flow (`features/linking/`, `qr_code_page.dart` +
`qr_scanner_page.dart`), but the QR code simply encodes the user's raw UUID
(`QrImageView(data: user?.id)`) and the scanner passes the scanned string
straight through — there is no encryption, signing, or expiry on the QR
payload itself. Linking a stranger's UUID (if somehow obtained) would work
identically to scanning their QR code. On a successful link, the caregiver's
phone number is automatically added to the patient's medical contacts as a
`FAMILY`-type contact (`_sync_caregiver_into_patient_contacts`, with
phone-number de-duplication), and a database-level partial unique index
(`DATABASE.md` §3) ensures a patient has at most one active *primary*
caregiver even though they can have several linked caregivers overall.

## 2. API surface

Routers registered in `main.py`, all under `/api/v1`:

| Router | Representative endpoints | Purpose |
|---|---|---|
| `auth` | `/register`, `/login`, `/refresh`, `/social`, `/verify-email`, `/logout` | Account creation and session issuance |
| `users` | `/me`, `/me/fcm-token`, `/me/password`, `/linked`, `/link/{user_id}` | Profile management, patient↔caregiver linking |
| `vitals` | `/bp`, `/bp/submit`, `/bp/complete`, `/bp/heartbeat`, `/bp/history`, `/bp/stats`, `/patient/{id}/*` | BP reading ingestion (manual, sensor), calibration completion, caregiver views |
| `medications` | CRUD + adherence logging | Medication catalog, schedules, smart-box drawer assignment |
| `bp_reminders` | `/schedule-daily`, list | Derives up to 3 daily BP reminder times from one patient-chosen start time |
| `notifications` | list, unread-count, mark-read, delete | In-app notification inbox |
| `contacts` | CRUD | Medical contacts (doctor/clinic/pharmacy/emergency/family) |
| `calls` | create, offer, accept, reject, busy, end | WebRTC call session lifecycle (paired with the Socket.IO signaling layer in `main.py`) |
| `iot` | `/sensors/status`, `/sensors/data`, `/medicine-box/*` | Generic sensor telemetry (mock) + real medicine-box control (see Section 4) |
| `hardware` | `/status` | ESP32 medicine-box reachability ping |
| `upload` | `/public/image`, `/image`, `/profile-picture`, `/medication-image` | Cloudinary-backed image upload |
| `ai` | `/chat`, `/symptom-checker`, `/assessment`, `/bp-triage`, `/categories`, `/taxonomy/symptoms`, `/chat/from-assessment`, `/assessment/notify-caregiver`, `/model-info`, `/assessment/rollout-metrics` | Both symptom-checker generations — fully detailed in `SYMPTOM_CHECKER.md` |

Full request/response schemas belong in `API_DOCUMENTATION.md`; this table is
the map of what exists and why, cross-referenced to the documents that go
deep on each area (`BP_PREDICTION.md` for the BP endpoints' model/calibration
behavior, `SYMPTOM_CHECKER.md` for `ai`, `IOT.md` for hardware detail).

## 3. Services layer

| Service | Real responsibility |
|---|---|
| `abp_prediction_service.py` | Loads and runs the BP Keras model (`BP_PREDICTION.md` §10) |
| `calibration_service.py` | Per-patient scale/offset fitting, median-then-linear upgrade path (`BP_PREDICTION.md` §9) |
| `bp_drift_service.py` | Scheduled daily job flagging calibration drift/staleness (`BP_PREDICTION.md` §9) |
| `bp_reminder_service.py` | Computes/schedules the 3 daily BP reminder times |
| `scheduler_service.py` | APScheduler jobs for medication alarms — looks up due medications, triggers smart-box drawers, sends notifications |
| `notification_service.py` | Creates `Notification` rows, sends FCM pushes, manages per-risk-level alert cooldowns (15 min critical / 30 min high-or-low) via the `bp_alert_cooldowns` table |
| `patient_caregiver_service.py` | Assigns/reassigns the "primary caregiver" flag when links are created |
| `redis_cache.py` | Generic app-level Redis cache wrapper |
| `cloudinary_service.py` | Image upload to Cloudinary, fails closed with a 503 if credentials aren't configured rather than silently no-op'ing |
| `iot_service.py` | The **real** ESP32 medicine-box HTTP client — `activate()`, `deactivate_all()`, `ping()`, all fail-soft (log a warning, never raise, so an unreachable box never crashes a scheduled alarm job) |
| `iot_mock.py` | A **simulated** sensor/medicine-box service — randomly degrades signal quality/connection status on ~10% of calls, used to back the generic `/iot/sensors/*` endpoints even in `production` IoT mode (see Section 4) |
| `ai_service.py` | Legacy (v1) symptom checker — `SYMPTOM_CHECKER.md` |

## 4. A real split worth being explicit about: two IoT code paths, not one

There are, in effect, three separate hardware integrations in this backend,
and they are not unified under one "IoT service":

1. **BP hardware** — real device, authenticated via `registered_devices` +
   bcrypt token, ingested through `vitals.py`'s `/bp/submit` and
   `/bp/heartbeat`. This path is genuinely real end-to-end (`BP_PREDICTION.md`
   §10).
2. **Smart medicine box** — real device, controlled via `iot_service.py`
   (`ESP32Service`), which POSTs to the box's own `/activate` HTTP endpoint.
   Used by both the medication-alarm scheduler and `iot.py`'s
   `/medicine-box/*` routes and `hardware.py`'s `/status` route. This path is
   also real.
3. **Generic sensor telemetry** (`/iot/sensors/status`, `/iot/sensors/data`)
   — this is `iot.py` importing `iot_mock.get_iot_service()` directly, with
   the router's own inline comment marking it "Still used for sensors." This
   endpoint pair returns simulated PPG/ECG connection status and signal
   quality with randomized degradation, regardless of `settings.iot_mode`. It
   is not reading from the real BP sensor at all — that data comes in through
   path (1) above, as part of a completed/rejected `VitalSign`, not through
   this endpoint.

Anyone building a dashboard against `/iot/sensors/*` expecting live BP-sensor
telemetry would be looking at demo data; the real sensor readings surface
through the vitals endpoints instead.

## 5. Error handling conventions

Two consistent, deliberate patterns recur across the services, not just in
the BP path:

- **User-facing operations raise `HTTPException`** with a specific status
  code and detail string (auth failures → 401, permission failures → 403,
  not-found → 404, unconfigured dependency like Cloudinary → 503). Callers get
  an actionable error, not a generic 500.
- **Background/best-effort operations fail soft.** `ESP32Service._post()`
  catches `httpx.ConnectError` and any other exception, logs a warning, and
  returns a `{"status": "error", ...}` dict rather than raising — explicitly
  so an unreachable medicine box never takes down a scheduled alarm job
  (`scheduler_service.trigger_medication_alarm` calls `iot_service.activate()`
  without a surrounding try/except, relying on this contract). The same
  fail-soft posture appears in `abp_prediction_service.py` (`model_not_ready`
  dict instead of a raised exception) and in the LLM phrasing layer
  (`SYMPTOM_CHECKER.md` §6, malformed response → fall back to the static
  result).

## 6. Testing

`Back-end/tests/` contains 15 test files, concentrated heavily on the newer,
safety-relevant code rather than spread evenly:

- `domain/rules_engine/` — dedicated unit tests for `bp_rules.py`,
  `red_flag_rules.py`, and `urgency_rules.py` (277 lines combined) — the
  rule engine that both the symptom checker and BP-triage integration depend
  on for their safety guarantees is the most thoroughly unit-tested part of
  the backend.
- `api/v1/test_bp_endpoints.py` (291 lines) and `test_bp_drift.py` — endpoint-
  level tests for the BP submission/calibration/drift flow.
- `api/v1/test_assessment_endpoints.py`, `application/test_assessment_phrasing.py` —
  symptom-checker v2 assessment and LLM-phrasing-fallback behavior.
- `infrastructure/test_redis_chat_session_repository.py` — confirms at least
  one of the two `ChatSessionRepository` implementations is exercised by
  tests, even though (per `DATABASE.md` §4) the Postgres-backed
  `chat_sessions`/`chat_messages` tables are not.
- `quality/test_encoding_audit.py` — a dedicated test scanning for
  mojibake/broken-encoding Arabic text, i.e. an automated check for exactly
  the kind of Arabic-string corruption that is easy to introduce when editing
  UTF-8 files on Windows tooling.
- `models/test_medical_contact_enum.py`, `test_vital_sign_enum.py` — guard
  against the enum-casing class of bug the Alembic history shows already bit
  the `family` contact type once (`DATABASE.md` §5).

**Not covered by any test file found**: the legacy v1 symptom-checker
service (`ai_service.py` has one narrow test,
`services/test_ai_service_phrase_extraction.py`, for phrase extraction only —
no test exercises `predict_disease()` or the TF-IDF path end-to-end), the
auth flows in `auth.py`, and the medication/scheduler/notification services
outside of the BP-specific ones. Test investment clearly tracked the newer,
safety-critical BP and symptom-checker-v2 work, not the codebase evenly.

## 7. Deployment

Covered in full in `ARCHITECTURE.md` §6 (single-host Docker Compose,
bind-mounted model directories, manual IP configuration across four files).
Not repeated here.

## 8. Summary of honest gaps found in this pass

- Logout does not invalidate tokens (stated in the code's own docstring).
- Refresh tokens are not rotated/blacklisted server-side.
- Patient–caregiver linking has a working QR flow on the frontend, but the
  QR payload is an unencrypted raw UUID, and the backend endpoint's own
  docstring flags the mechanism as not production-hardened.
- `/iot/sensors/*` always returns simulated data regardless of `iot_mode`,
  which could be mistaken for a live sensor feed if read from the API
  surface alone.
- Test coverage is real but concentrated on the newer BP/symptom-checker-v2
  work; large parts of the older service layer (auth, legacy AI, medication
  scheduling itself) have thin or no test coverage.
