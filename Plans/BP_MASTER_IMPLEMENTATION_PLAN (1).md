# Smart Box BP Feature — Master Implementation Plan (Self-Contained)

Last updated: 2026-07-01

This is the single source of truth for implementing the blood-pressure feature.
It supersedes and consolidates `BP_FLOW_CALIBRATION_HANDOFF.md` and
`BP_CALIBRATION_IMPLEMENTATION_PLAN.md` — read those only for background
narrative; every actionable decision from them is restated here with exact
schemas, file paths, and contracts. Nothing in this plan is deferred to later.

## 0. How to use this document (for the implementing agent)

Work top to bottom. Each section is self-contained: table schemas, file
paths, and endpoint contracts are exact — do not invent alternate names.
Where a file already exists in the repo, extend it; do not create a
duplicate. Sections are ordered so that later sections depend only on
earlier ones.

**Confirmed stack decisions:**
- Database: **PostgreSQL** with **Alembic** migrations (matches existing `Back-end/app/` setup).
- The IoT Mocker in `Back-end/` already provides a partial vitals/health API — **extend it**, do not replace it.
- State management (Flutter): **Riverpod** (matches existing app).
- Push notifications: **FCM**, delivered via the existing `notification_service.py` pattern.
- Scheduling: **APScheduler**, matches the existing `scheduler_service.py` pattern used for medications.

---

## 1. Non-Negotiables (safety rules — do not weaken these)

- The ESP8266 never runs the model and never decides alerts. It only collects and forwards raw samples.
- The backend is the only source of truth for BP values, calibration, and alert decisions.
- A `drift_flag` or poor signal quality **never hides a reading** — it adds a caution indicator. Fail open, not closed.
- Critical alerts are never blocked or delayed by the AI chat — the deterministic alert engine (Section 6) always fires independently of any AI/LLM step.
- Calibration is only computed from windows that pass the quality gate in Section 5.
- All new user-facing text ships with both `_en` and `_ar` copies from day one — no feature merges with English-only strings.

---

## 2. Model Artifact Contract

Source: `BP_Prediction_v5_Final.ipynb`, run on Kaggle. After training completes, copy these files from `/kaggle/working/checkpoints/` into the backend:

```text
Back-end/app/ml/bp_model/
├── bp_model_final.keras       # winning model (see notebook Section 14 "best_name")
├── scaler_features.pkl        # StandardScaler for the 21 hand-crafted features
├── scaler_targets.pkl         # StandardScaler for [SBP, DBP]
└── predict_bp.py              # runtime wrapper, see contract below
```

**`predict_bp.py` contract** (port the notebook's `predict_bp()` function verbatim, this is not a rewrite):

```python
def predict_bp(ppg_raw_100hz: np.ndarray, ecg_raw_100hz: np.ndarray) -> dict:
    """
    ppg_raw_100hz: last >=800 samples, MAX30102 IR channel, 100 Hz, sampleAverage=1
    ecg_raw_100hz: last >=800 samples, AD8232 OUTPUT via analogRead, 100 Hz
    Returns: {"sbp": float, "dbp": float, "hr": float, "ptt": float}
    Internally: bandpass -> per-window z-score -> extract 21 features -> model(..., training=False)
    Uses direct __call__, NOT .predict() (avoids MirroredStrategy single-sample issue if
    the exported model retains a distribution wrapper).
    """
```

If the winning model in the notebook's final comparison table is a classical ML model (Ridge/XGBoost/etc., not a `.keras` model), the notebook's export cell automatically falls back to exporting the `TCN+BiLSTM+Attn (ours)` model instead, since only Keras models are deployable in this on-demand inference shape. Confirm which model was actually exported by checking for `bp_model_final.keras` in the notebook's final file listing before wiring the backend.

**Known numbers as of this plan** (v4 baseline, pending v5 retraining results): SBP MAE 9.13 mmHg, DBP MAE 5.19 mmHg, both AAMI-FAIL uncalibrated. The calibration simulation in the v5 notebook (Section 15) is expected to bring these down substantially — use the notebook's actual printed numbers, not these placeholders, when documenting the shipped model in-app (e.g. any "about this feature" screen).

---

## 3. Database Schema (PostgreSQL + Alembic)

Create one Alembic migration per numbered group below (`alembic revision -m "..."`, then hand-write the upgrade/downgrade — do not blindly trust autogenerate for enum types). All new tables use `BIGSERIAL` primary keys and `TIMESTAMPTZ` for all timestamps.

### 3.1 `vitals_readings`

Extends whatever table the IoT Mocker currently writes to. If a `health_readings` or `vital_signs` table already exists from the Mocker, add these columns via migration rather than creating a parallel table; otherwise create fresh with this shape.

```sql
CREATE TABLE vitals_readings (
    id                  BIGSERIAL PRIMARY KEY,
    patient_id          BIGINT NOT NULL REFERENCES users(id),
    device_id           VARCHAR(64),
    sbp_raw             REAL,           -- model output, pre-calibration
    dbp_raw             REAL,
    sbp_adjusted        REAL,           -- post-calibration (null if no calibration yet)
    dbp_adjusted        REAL,
    hr                  REAL,
    spo2                REAL,
    ptt                 REAL,
    snr_db              REAL,
    signal_quality      VARCHAR(16) NOT NULL DEFAULT 'unknown', -- good | poor | unknown
    measurement_status  VARCHAR(16) NOT NULL,                   -- completed | rejected
    rejection_reason    VARCHAR(64),    -- finger_missing | leads_off | poor_signal | out_of_range
    source              VARCHAR(16) NOT NULL DEFAULT 'device',  -- device | calibration_point
    ecg_lead_status     BOOLEAN,
    measured_at         TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_vitals_patient_time ON vitals_readings (patient_id, measured_at DESC);
```

### 3.2 `bp_calibrations` (one active row per patient)

```sql
CREATE TABLE bp_calibrations (
    id                          BIGSERIAL PRIMARY KEY,
    patient_id                  BIGINT NOT NULL UNIQUE REFERENCES users(id),
    sbp_scale                   REAL NOT NULL DEFAULT 1.0,
    sbp_offset                  REAL NOT NULL DEFAULT 0.0,
    dbp_scale                   REAL NOT NULL DEFAULT 1.0,
    dbp_offset                  REAL NOT NULL DEFAULT 0.0,
    calibration_quality         VARCHAR(16) NOT NULL DEFAULT 'none', -- none | cold_start | additive | linear | weak | stale
    samples_count                INT NOT NULL DEFAULT 0,
    last_calibrated_at          TIMESTAMPTZ,
    baseline_raw_mean_sbp       REAL,
    baseline_raw_mean_dbp       REAL,
    drift_flag                  BOOLEAN NOT NULL DEFAULT false,
    drift_reason                VARCHAR(32),  -- drift_detected | calibration_stale
    drift_flagged_at            TIMESTAMPTZ,
    last_drift_notification_at  TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 3.3 `bp_calibration_points` (history, used to refit on each new point)

```sql
CREATE TABLE bp_calibration_points (
    id           BIGSERIAL PRIMARY KEY,
    patient_id   BIGINT NOT NULL REFERENCES users(id),
    cuff_sbp     REAL NOT NULL,
    cuff_dbp     REAL NOT NULL,
    model_sbp    REAL NOT NULL,
    model_dbp    REAL NOT NULL,
    reading_id   BIGINT REFERENCES vitals_readings(id),
    measured_at  TIMESTAMPTZ NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 3.4 `bp_reminders` and `bp_reminder_logs`

```sql
CREATE TABLE bp_reminders (
    id             BIGSERIAL PRIMARY KEY,
    patient_id     BIGINT NOT NULL REFERENCES users(id),
    scheduled_time TIME NOT NULL,
    days_of_week   SMALLINT[] NOT NULL DEFAULT '{0,1,2,3,4,5,6}', -- 0=Mon .. 6=Sun
    is_active      BOOLEAN NOT NULL DEFAULT true,
    created_by     BIGINT NOT NULL REFERENCES users(id), -- patient or caregiver
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE bp_reminder_logs (
    id            BIGSERIAL PRIMARY KEY,
    reminder_id   BIGINT NOT NULL REFERENCES bp_reminders(id),
    patient_id    BIGINT NOT NULL REFERENCES users(id),
    fired_at      TIMESTAMPTZ NOT NULL,
    status        VARCHAR(16) NOT NULL DEFAULT 'pending', -- pending | completed | snoozed | missed
    completed_at  TIMESTAMPTZ,
    snoozed_until TIMESTAMPTZ,
    reading_id    BIGINT REFERENCES vitals_readings(id)
);
```

### 3.5 `bp_alerts` (includes escalation state)

```sql
CREATE TABLE bp_alerts (
    id                BIGSERIAL PRIMARY KEY,
    patient_id        BIGINT NOT NULL REFERENCES users(id),
    reading_id        BIGINT NOT NULL REFERENCES vitals_readings(id),
    risk_level        VARCHAR(16) NOT NULL,   -- medium | high | critical
    alert_type        VARCHAR(32) NOT NULL,   -- high_bp | critical_bp | low_spo2 | tachycardia | bradycardia
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged      BOOLEAN NOT NULL DEFAULT false,
    acknowledged_at   TIMESTAMPTZ,
    acknowledged_by   BIGINT REFERENCES users(id),
    escalation_level  SMALLINT NOT NULL DEFAULT 0,  -- 0=primary notified, 1=re-notified, 2=broadcast to all
    escalated_at      TIMESTAMPTZ,
    next_escalation_at TIMESTAMPTZ,
    cooldown_until    TIMESTAMPTZ  -- prevents duplicate alerts of the same type within cooldown
);
CREATE INDEX idx_alerts_unacked ON bp_alerts (patient_id, acknowledged, next_escalation_at);
```

### 3.6 Extend `caregiver_patient_links` (existing table)

Add columns via migration — do not recreate this table:

```sql
ALTER TABLE caregiver_patient_links
    ADD COLUMN is_primary BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN alert_preferences JSONB NOT NULL DEFAULT '{"medium": true, "high": true, "critical": true}';

-- Enforce exactly one primary caregiver per patient at the application layer
-- (Postgres partial unique index):
CREATE UNIQUE INDEX idx_one_primary_per_patient
    ON caregiver_patient_links (patient_id)
    WHERE is_primary = true;
```

`critical` in `alert_preferences` is enforced server-side regardless of the stored value — a caregiver cannot opt out of critical alerts. The column exists so the UI can still show the toggle as informational, but the alert service ignores it for `critical`.

### 3.7 `bp_symptom_assessments` (AI triage link)

```sql
CREATE TABLE bp_symptom_assessments (
    id                        BIGSERIAL PRIMARY KEY,
    patient_id                BIGINT NOT NULL REFERENCES users(id),
    reading_id                BIGINT NOT NULL REFERENCES vitals_readings(id),
    selected_symptoms         JSONB NOT NULL DEFAULT '[]',  -- array of stable symptom IDs
    triage_level              VARCHAR(16),
    symptom_checker_response  JSONB,
    red_flags                 JSONB NOT NULL DEFAULT '[]',
    caregiver_summary         TEXT,
    should_notify_caregiver   BOOLEAN NOT NULL DEFAULT false,
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 4. Backend Architecture

### 4.1 File placement

```text
Back-end/app/
├── api/v1/
│   ├── vitals.py                   # extend existing IoT Mocker router with BP endpoints
│   ├── bp_calibration.py           # new
│   ├── bp_reminders.py             # new
│   └── bp_alerts.py                # new
├── services/
│   ├── bp_measurement_service.py   # new - wraps predict_bp.py, runs quality gate
│   ├── bp_calibration_service.py   # new - fit/clamp/quality logic (Section 5)
│   ├── bp_drift_service.py         # new - rolling window + staleness (Section 5.5)
│   ├── bp_alert_service.py         # new - threshold classification + cooldown (Section 6)
│   ├── bp_escalation_service.py    # new - escalation timers + caregiver routing (Section 6.3)
│   ├── bp_reminder_service.py      # new - reuses scheduler_service.py APScheduler pattern
│   ├── scheduler_service.py        # EXTEND: register the 3 new jobs from Section 4.4
│   └── notification_service.py     # EXTEND: add BP-specific notification templates
├── schemas/
│   └── bp.py                       # new - all Pydantic request/response models
├── models/
│   └── bp.py                       # new - SQLAlchemy models for Section 3 tables
└── ml/bp_model/                    # new - see Section 2
```

### 4.2 Measurement pipeline (`bp_measurement_service.py`)

```text
def process_measurement(patient_id, ppg_samples, ecg_samples, device_id) -> VitalsReading:
    1. Validate: len(ppg_samples) >= 800, len(ecg_samples) >= 800, all finite
    2. Run quality checks (Section 5): finger detected, leads on, SNR, peak counts
       -> if failed: save reading with measurement_status='rejected', rejection_reason=<code>, return early
    3. raw = predict_bp(ppg_samples, ecg_samples)   # from Section 2 contract
    4. calibration = bp_calibration_service.get_active(patient_id)
    5. adjusted_sbp = calibration.sbp_scale * raw['sbp'] + calibration.sbp_offset
       adjusted_dbp = calibration.dbp_scale * raw['dbp'] + calibration.dbp_offset
    6. Save VitalsReading with both raw and adjusted values, status='completed'
    7. bp_drift_service.update_rolling_window(patient_id, raw['sbp'], raw['dbp'])  # uses RAW, not adjusted
    8. bp_alert_service.evaluate(reading)  # may create a bp_alerts row and fire notifications
    9. Return the saved reading
```

### 4.3 Calibration logic (`bp_calibration_service.py`)

**Revised algorithm — additive-only by default.** Simulation evidence in `BP_Prediction_v5_Final.ipynb` (Section 15) showed the originally-planned linear fit (scale+offset) from 2-3 points makes SBP accuracy worse, not better (9.05 -> 14.49 mmHg MAE), because two parameters fit from that few points are dominated by the model's own ~9 mmHg per-reading noise rather than real signal. A single-parameter additive offset (median-based) tested on the same data instead improved accuracy substantially (9.05 -> 5.86 mmHg SBP, and reached DBP AAMI PASS + BHS Grade A). Full comparison and rationale: `BP_CALIBRATION_IMPLEMENTATION_PLAN.md` Section 2.

```text
SCALE_CLAMP  = (0.70, 1.30)      # only used once 8+ points exist
OFFSET_CLAMP = (-25.0, 25.0)
LINEAR_UPGRADE_THRESHOLD = 8      # starting assumption, tune once real usage data exists

def add_calibration_point(patient_id, cuff_sbp, cuff_dbp, reading_id):
    1. Validate gates: reading.signal_quality == 'good', reading.measurement_status == 'completed',
       cuff values physiologically valid (SBP 70-200, DBP 40-130, cuff_sbp > cuff_dbp),
       reading.measured_at within 5 minutes of now (cuff and device close in time).
    2. Insert into bp_calibration_points using reading.sbp_raw / dbp_raw as model_sbp/model_dbp.
    3. Call recompute(patient_id).

def recompute(patient_id):
    points = all bp_calibration_points for patient_id
    if len(points) < LINEAR_UPGRADE_THRESHOLD:
        # Additive-only: median offset, resists noisy individual points
        sbp_offset = clip(median(p.cuff_sbp - p.model_sbp for p in points), *OFFSET_CLAMP)
        dbp_offset = clip(median(p.cuff_dbp - p.model_dbp for p in points), *OFFSET_CLAMP)
        sbp_scale, dbp_scale = 1.0, 1.0
        quality = 'cold_start' if len(points) == 1 else 'additive'
    else:
        # Enough points to attempt a linear fit - but only trust it if it's not clamped
        sbp_scale, sbp_offset = least_squares_fit(cuff=[p.cuff_sbp...], model=[p.model_sbp...])
        dbp_scale, dbp_offset = least_squares_fit(cuff=[p.cuff_dbp...], model=[p.model_dbp...])
        clamped = clip(sbp_scale, *SCALE_CLAMP) != sbp_scale or clip(sbp_offset, *OFFSET_CLAMP) != sbp_offset
        sbp_scale, sbp_offset = clip(sbp_scale, *SCALE_CLAMP), clip(sbp_offset, *OFFSET_CLAMP)
        dbp_scale, dbp_offset = clip(dbp_scale, *SCALE_CLAMP), clip(dbp_offset, *OFFSET_CLAMP)
        quality = 'weak' if clamped else 'linear'
    update bp_calibrations row: scale/offset/quality/samples_count/last_calibrated_at=now()
    also set baseline_raw_mean_sbp/dbp = mean of model_sbp/dbp across the last min(10, len(points)) points
        (this seeds the drift baseline — see Section 5.5)
```

### 4.4 Scheduled jobs (register in `scheduler_service.py`)

```text
1. daily_drift_check_job         — runs once/day, calls bp_drift_service.check_all_patients()
2. escalation_check_job          — runs every 5 minutes, calls bp_escalation_service.process_pending()
3. bp_reminder_dispatch_job      — reuses the exact APScheduler pattern already used for
                                    medication reminders in scheduler_service.py; one job per
                                    active bp_reminders row, rescheduled whenever a reminder is
                                    created/edited/deleted (same mechanism as medications.py)
```

### 4.4.1 Missed-job behavior on container restart (known limitation, intentional)

APScheduler logs `Run time of job "..." was missed by H:MM:SS` when the container is down
(or paused) at a job's scheduled fire time and comes back up after that time has passed.
This is expected `AsyncIOScheduler` behavior, not a bug: APScheduler does not retroactively
fire missed cron jobs once `misfire_grace_time` has elapsed — it logs the miss and waits
for the job's next scheduled occurrence.

This is the correct behavior for medication and BP reminders (nobody wants a "take your
medication" push notification arriving 9 hours late). **Operational implication:** if the
backend is down during a scheduled medication or BP reminder window in a real deployment,
the patient will miss that specific reminder with no automatic catch-up. This is a known
limitation to live with, not something to silently fix by adding retroactive-fire logic
unless explicitly decided otherwise later.

---

## 5. Measurement & Quality Gate

Guided measurement flow (unchanged from the original handoff, restated for completeness):

```text
Patient taps "Start Measurement"
  -> App: "Sit calmly. Place your finger on the sensor. Make sure ECG electrodes are attached. Keep still for 8 seconds."
  -> Check: ESP8266 online, finger detected, leads connected
  -> Collect 800 PPG + 800 ECG samples @ 100 Hz (8 seconds)
  -> Backend quality gate:
       - sample count == 800 for both channels
       - all values finite
       - PPG SNR check (same Welch-based method as the training notebook)
       - ABP-equivalent peak/trough plausibility is not available at inference time (no ABP sensor) —
         instead validate HR extracted from PTT features falls in 40-180 bpm as a sanity bound
     -> if any check fails: rejection_reason set, patient sees "poor signal, please retry" (localized),
        NOT saved as a valid reading, does not enter calibration or alerts
  -> If quality good: proceed through Section 4.2 pipeline
```

### 5.5 Drift detection (`bp_drift_service.py`)

Restated exactly from the calibration plan:

```text
Rolling window: last 10 valid RAW (pre-calibration) sbp/dbp values per patient, stored as a
small JSONB array on bp_calibrations or a lightweight side table — either is fine, pick one
and use it consistently.

def check_all_patients():
    for each patient with an active calibration:
        recent_mean_sbp = mean(last 10 raw sbp)
        recent_mean_dbp = mean(last 10 raw dbp)
        sbp_drifted = abs(recent_mean_sbp - baseline_raw_mean_sbp) > 8  AND sustained over last 5 readings
        dbp_drifted = abs(recent_mean_dbp - baseline_raw_mean_dbp) > 5  AND sustained over last 5 readings
        stale = (now() - last_calibrated_at) > 90 days

        if (sbp_drifted or dbp_drifted or stale) and last_drift_notification_at is
           more than 14 days ago (or null):
            set drift_flag=true, drift_reason = 'drift_detected' if (sbp_drifted or dbp_drifted) else 'calibration_stale'
            drift_flagged_at = now(); last_drift_notification_at = now()
            send FCM notification (localized) -> opens calibration entry screen
        # never clear drift_flag automatically - only clears when patient completes a new calibration
```

---

## 6. Alert Engine, Escalation, and Multi-Caregiver Routing

### 6.1 Risk thresholds (unchanged from the original handoff)

```text
Critical: SBP >= 180  OR  DBP >= 120  OR  SpO2 < 90
High:     SBP >= 140  OR  DBP >= 90   OR  SBP < 90  OR  SpO2 < 94
Medium:   HR > 100  OR  HR < 50
```

Alerts use the **adjusted** (calibrated) BP, only when `measurement_status == 'completed'`. A poor-quality reading never triggers an alert — ask the patient to remeasure instead.

### 6.2 Cooldown

Per `(patient_id, alert_type)`: do not create a new `bp_alerts` row if one of the same type exists with `cooldown_until > now()`. Set `cooldown_until = now() + 30 minutes` for medium/high, `now() + 10 minutes` for critical (critical repeats sooner since it matters more if it's still happening).

### 6.3 Escalation (`bp_escalation_service.py`) — in scope, not deferred

```text
On critical alert creation:
    escalation_level = 0
    next_escalation_at = now() + 15 minutes
    notify primary caregiver immediately (ignore alert_preferences.critical - always true)

escalation_check_job (every 5 min):
    for each bp_alerts row where acknowledged=false AND next_escalation_at <= now():
        if escalation_level == 0:
            notify primary caregiver again (re-send, in case first push was missed)
            escalation_level = 1
            next_escalation_at = now() + 15 minutes
        elif escalation_level == 1:
            notify ALL caregivers linked to this patient (broadcast), regardless of is_primary
            escalation_level = 2
            next_escalation_at = now() + 30 minutes
        else:  # escalation_level >= 2
            notify ALL caregivers again (repeat every 30 min)
            next_escalation_at = now() + 30 minutes
        # stops entirely once acknowledged=true is set via the acknowledge endpoint
```

High/medium alerts do not escalate — they notify the primary caregiver once (subject to cooldown) and stop.

### 6.4 Multi-caregiver routing summary

```text
Medium alert  -> primary caregiver only (if alert_preferences.medium == true for them)
High alert    -> primary caregiver (if alert_preferences.high == true), secondary caregivers
                 get a lower-priority/silent notification if their alert_preferences.high == true
Critical alert -> primary caregiver always, escalating per Section 6.3 to all caregivers
                 regardless of their alert_preferences (critical cannot be muted)
```

### 6.5 Acknowledge endpoint

`POST /api/v1/bp/alerts/{id}/acknowledge` — callable by the patient or any linked caregiver. Sets `acknowledged=true, acknowledged_at=now(), acknowledged_by=<user_id>`. This immediately stops further escalation checks for that alert (the `escalation_check_job` query filters on `acknowledged=false`).

---

## 7. API Endpoint Reference (complete)

```text
POST   /api/v1/vitals/bp/submit              # device submits raw window, runs full pipeline (Section 4.2)
GET    /api/v1/vitals/bp/current?lang=       # latest reading + device/calibration/reminder status
GET    /api/v1/vitals/bp/history?range=&lang= # paginated history for trend charts

POST   /api/v1/bp/calibration/point          # add one cuff-vs-device pair
GET    /api/v1/bp/calibration/status         # quality, samples_count, last_calibrated_at, drift_flag

GET    /api/v1/bp/reminders
POST   /api/v1/bp/reminders
PUT    /api/v1/bp/reminders/{id}
DELETE /api/v1/bp/reminders/{id}
POST   /api/v1/bp/reminders/{id}/snooze
POST   /api/v1/bp/reminders/{id}/skip

GET    /api/v1/bp/alerts?patient_id=&status=
POST   /api/v1/bp/alerts/{id}/acknowledge
GET    /api/v1/bp/alerts/history

PUT    /api/v1/caregivers/{link_id}/preferences   # {is_primary, alert_preferences}

POST   /api/v1/ai/bp-triage                  # per BP_FLOW_CALIBRATION_HANDOFF.md schema:
                                              # input: systolic, diastolic, heart_rate, bp_risk_level,
                                              #   signal_quality, calibration_status, selected_symptoms,
                                              #   patient_age, known_hypertension, medications_taken_today
                                              # output: triage_level, symptom_checker_prediction, red_flags,
                                              #   patient_message, caregiver_summary, should_notify_caregiver,
                                              #   should_remeasure, recommended_next_action
                                              # NOTE: build this against whichever symptom-checker endpoints
                                              # exist TODAY (ai.py / ai_service.py). Do not wait for the
                                              # Symptom-Checker retraining plan to land - wire it now, and
                                              # accept that prediction quality will improve automatically
                                              # once that separate track (SYMPTOM_CHECKER_IMPROVEMENT_PLAN.md)
                                              # ships its own new model, with no changes needed here.
```

Every endpoint above follows the localization contract from `BP_FLOW_CALIBRATION_HANDOFF.md`: accept `lang=en|ar` or use the user's saved preference, return stable IDs plus localized display text, never use translated strings as logic keys.

---

## 8. Firmware (ESP8266) Requirements

```text
Current state: test/wiring firmware only (per BP_FLOW_CALIBRATION_HANDOFF.md). Final firmware must:

- Connect to WiFi (existing pattern from the medication box ESP32 firmware, adapted for ESP8266)
- MAX30102 config: ppg.setup(60, 1, 2, 100, 411, 4096)  <- sampleAverage MUST be 1, not 4
- Collect exactly 800 PPG + 800 ECG samples at a maintained 100 Hz rate
- Detect finger presence (MAX30102 DC level threshold) before starting collection
- Detect ECG lead-off status (AD8232 LO+/LO- pins) before starting collection
- POST the 800+800 sample window as JSON to POST /api/v1/vitals/bp/submit
  {"device_id": "...", "patient_id": ..., "ppg_samples": [...800 floats...],
   "ecg_samples": [...800 floats...], "collected_at": "..."}
- Retry on network failure (exponential backoff, cap at 3 retries, then surface a
  "device offline" state that the next app poll will pick up)
- Never run the Keras model and never decide alerts (Section 1)

Wiring (unchanged, confirmed): see fig_37_hardware_wiring.png in BP_Prediction_v5_Final.ipynb
  MAX30102: VIN->3V3, GND->GND, SCL->D1(GPIO5), SDA->D2(GPIO4)
  AD8232:   3.3V->3V3, GND->GND, OUTPUT->A0, SDN->D5(GPIO14), LO+->D6(GPIO12), LO-->D7(GPIO13)
```

---

## 9. Flutter Architecture

### 9.1 File placement

```text
Front-end/health_mate_app/lib/features/vitals/
├── data/
│   ├── models/bp_reading_model.dart
│   ├── models/bp_calibration_model.dart
│   ├── models/bp_alert_model.dart
│   └── repositories/bp_repository.dart
├── presentation/
│   ├── pages/
│   │   ├── bp_dashboard_page.dart          # patient home for this feature
│   │   ├── bp_measurement_guide_page.dart  # guided 8-second measurement flow
│   │   ├── bp_calibration_page.dart        # shared first-use + recalibration entry screen
│   │   ├── bp_history_page.dart            # trend charts
│   │   ├── bp_reminder_settings_page.dart
│   │   └── caregiver_bp_detail_page.dart   # raw + adjusted BP, calibration quality, alert history
│   ├── providers/
│   │   ├── bp_dashboard_provider.dart      # Riverpod, matches existing app pattern
│   │   ├── bp_measurement_provider.dart
│   │   └── bp_calibration_provider.dart
│   └── widgets/
│       ├── bp_reading_card.dart
│       ├── calibration_status_widget.dart
│       ├── device_connection_status_widget.dart
│       ├── measurement_countdown_widget.dart
│       └── caregiver_alert_badge.dart      # shows escalation_level visually if unacknowledged
```

### 9.2 Patient dashboard states (unchanged from the handoff, restated)

```text
no device connected | device connected, ready | finger missing | ECG leads disconnected |
measuring countdown | poor signal retry | normal reading | elevated/high/critical reading |
caregiver notified | calibration needed | calibration weak (ask for another point) |
drift check recommended
```

### 9.3 Caregiver dashboard additions for multi-caregiver + escalation

```text
- Badge showing "You are the primary caregiver for [Patient]" vs secondary
- Alert list shows escalation_level for any unacknowledged critical alert
  (localized: "Notified 15 min ago" / "Escalated to all caregivers")
- Preferences screen: toggle medium/high notifications on/off (critical toggle
  is shown but disabled/greyed with an explanatory tooltip - cannot be turned off)
```

### 9.4 Localization

Every string introduced by this feature needs both `assets/translations/en.json` and `ar.json` entries before the corresponding screen is considered done. Follow the stable-ID pattern from `BP_FLOW_CALIBRATION_HANDOFF.md` — never branch business logic on the display string.

---

## 10. End-to-End Flows (for QA / demo scripting)

```text
Flow A - Manual measurement:
  Dashboard -> "Measure Now" -> guide screen -> 8s collection -> backend pipeline ->
  result shown -> if high/critical -> BP symptom triage screen -> caregiver notified if needed

Flow B - Scheduled reminder:
  Reminder fires (local + FCM) -> tap -> guide screen -> same as Flow A

Flow C - First-time calibration:
  Onboarding -> "Calibrate your device" -> cuff reading entered -> immediate device measurement ->
  cold_start offset computed -> shown to patient in plain language

Flow D - Recalibration (drift-triggered):
  daily_drift_check_job flags patient -> FCM notification -> calibration entry screen (recalibration mode) ->
  new point added -> recompute -> quality shown

Flow E - Critical alert with escalation:
  Critical reading -> primary caregiver notified -> 15 min unacknowledged -> re-notify primary ->
  15 min more unacknowledged -> broadcast to all caregivers -> repeats every 30 min until acknowledged

Flow F - AI triage handoff:
  High/critical reading -> BP-specific symptom category pre-opened -> patient selects symptoms ->
  POST /api/v1/ai/bp-triage -> patient_message + caregiver_summary returned -> optional AiSymptomChatPage
  opened with prepared clinical context message
```

---

## 11. Testing Checklist (comprehensive, merges all prior lists)

**Model / calibration math**
- Cold start (1 point) -> additive-only offset, quality=cold_start
- 2-3 points spanning a real BP range -> quality=linear
- Points too close together -> clamping triggers, quality=weak
- Deliberately extreme synthetic points -> clamp actually rejects out-of-bounds fit

**Drift**
- Sustained 5-reading drift past threshold -> flags correctly
- Single outlier reading -> does NOT flag
- 90+ days with zero drift signal -> staleness ceiling still flags
- 14-day cooldown prevents re-flagging
- `drift_flag=true` never hides the current adjusted reading

**Alerts / escalation / multi-caregiver**
- Each risk tier (medium/high/critical) classifies correctly at threshold boundaries
- Cooldown prevents duplicate alerts of the same type
- Critical alert escalates 0 -> 1 -> 2 on schedule when unacknowledged
- Acknowledgment at any escalation level stops further escalation
- Exactly one `is_primary` caregiver enforced (DB constraint + API validation)
- Secondary caregiver cannot mute critical alerts even if they try via preferences

**Measurement flow**
- Finger missing / leads off correctly blocks measurement start
- Poor SNR window is rejected, not saved as a valid reading, no alert fires from it
- Full flow works with WiFi retry (simulate network failure on device)

**AI triage**
- `bp-triage` endpoint responds using whatever symptom-checker version is live at test time
- Red flags trigger caregiver notification independently of the AI chat response

**Localization**
- Every flow in this section tested once in Arabic, once in English
- Identical underlying decisions and saved data in both languages (only display text differs)
- No endpoint fails because a label was Arabic instead of a stable ID

---

## 12. Phased Execution Plan (backend + Flutter in parallel)

**Phase 1 — Foundation**
- Backend: all Alembic migrations from Section 3; SQLAlchemy models; copy model artifacts per Section 2
- Flutter: build all screens from Section 9.1 against mock data; freeze the API contract from Section 7 before either side wires real calls

**Phase 2 — Core measurement + calibration**
- Backend: `bp_measurement_service.py`, `bp_calibration_service.py`, `/vitals/bp/submit`, `/bp/calibration/*`
- Flutter: measurement guide screen, calibration entry screen, wired to real endpoints

**Phase 3 — Reminders + alerts + escalation**
- Backend: `bp_reminder_service.py` + scheduler registration, `bp_alert_service.py`, `bp_escalation_service.py`, drift job
- Flutter: reminder settings screen, alert badges, caregiver preferences screen

**Phase 4 — AI triage + caregiver dashboard**
- Backend: `/ai/bp-triage` wired to current symptom-checker endpoints
- Flutter: triage handoff screens, `caregiver_bp_detail_page.dart`

**Phase 5 — Testing, localization, polish**
- Full Section 11 checklist, Arabic/English pass, firmware final integration test with real hardware

---

## 13. Definition of Done

- Every endpoint in Section 7 implemented and returns the documented shape.
- Every table in Section 3 migrated and populated by real flows (not just seed data).
- Escalation and multi-caregiver routing verified against the Section 11 checklist, not just code-reviewed.
- Every screen in Section 9.1 exists in both languages.
- A physical device produces a reading that flows through calibration and shows correctly on both patient and caregiver dashboards.
- A simulated critical reading demonstrates the full escalation chain (0 -> 1 -> 2) without manual intervention.
