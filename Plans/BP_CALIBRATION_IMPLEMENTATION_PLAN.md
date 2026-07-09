# BP Calibration & Drift Detection — Implementation Plan

Last updated: 2026-07-01

Purpose: turn the calibration decisions from `BP_FLOW_CALIBRATION_HANDOFF.md` into a concrete, buildable plan. This file assumes that handoff has already been read.

## Decisions Locked In This Session

- Calibration math: **linear (scale + offset)**, not additive-only.
- Recalibration trigger: **drift detection**, not a fixed calendar schedule alone.
- Execution: **backend and Flutter work happen in parallel**, on a shared API contract agreed up front.

Validation for why this matters: the final trained BP model (`BP_Prediction_Kaggle_Final.ipynb`, best model TCN) scored SBP MAE = 11.47 mmHg with no calibration, failing AAMI (limit 5 mmHg). Calibration is not an optional polish step — it is the only realistic path to clinically usable numbers for this project.

---

## 1. Data Model

Extend the calibration record (Firestore or Postgres, matching whatever the rest of `health_readings` uses):

```json
{
  "patient_id": "...",
  "calibration_points": [
    {
      "cuff_sbp": 132,
      "cuff_dbp": 86,
      "model_sbp": 125,
      "model_dbp": 82,
      "measured_at": "2026-07-01T08:00:00Z",
      "signal_quality": "good"
    }
  ],
  "sbp_scale": 1.05,
  "sbp_offset": 3.2,
  "dbp_scale": 0.98,
  "dbp_offset": 4.1,
  "calibration_quality": "cold_start | additive_only | linear | weak | stale",
  "samples_count": 3,
  "last_calibrated_at": "2026-07-01T08:00:00Z",
  "baseline_raw_mean_sbp": 128.4,
  "baseline_raw_mean_dbp": 83.1,
  "drift_flag": false,
  "drift_flagged_at": null,
  "last_drift_notification_at": null
}
```

`baseline_raw_mean_sbp/dbp` and the `drift_*` fields exist purely to support drift detection (Section 3) — they are not needed for the calibration math itself.

---

## 2. Calibration Algorithm (Additive-only by default; linear only with enough points)

**Revised decision, backed by simulation evidence.** The original version of this plan defaulted to a linear fit (`scale + offset`) as soon as 2+ calibration points existed. Testing this exact procedure in `BP_Prediction_v5_Final.ipynb` (Section 15, oracle calibration simulation) showed it makes accuracy *worse*, not better, at the point counts a real onboarding flow will realistically collect:

```
Simulation result (3 calibration points per patient, held-out oracle test):
                  No calibration    Linear (scale+offset)    Additive-only (offset)
  SBP MAE              9.05                14.49                    5.86
  DBP MAE              4.89                 6.62                    3.09
  DBP AAMI             PASS                 FAIL                    PASS
  DBP BHS                 B                    C                       A
```

**Why linear fails here:** fitting two parameters (`scale` and `offset`) from 3 points leaves only one residual degree of freedom. The underlying model has roughly 9 mmHg of per-reading noise, so the fitted slope is dominated by that noise rather than a real physiological relationship — it amplifies error on every subsequent reading instead of correcting it. A single-parameter fit (offset only) is far more resistant to this.

Formula: `adjusted = model_prediction + offset`

### Cold start (1 point) and general case (< 8 points)

```
offset = median(cuff_reading - model_reading) across all stored calibration points
offset = clip(offset, -25, +25)
scale is fixed at 1.0 - not fitted
quality = 'cold_start' if samples_count == 1 else 'additive'
```

Using the **median** rather than the mean across points is deliberate — it resists any single noisy calibration point pulling the offset off, which matters even more once patients accumulate several points over time.

### Upgrading to linear (8+ points only)

Once a patient has accumulated 8 or more calibration points (naturally, over weeks of normal use — not something the app should ask for upfront), the backend may attempt the linear fit as before:

```
scale, offset = least_squares_fit(cuff=[...], model=[...])
SCALE_CLAMP  = (0.70, 1.30)
OFFSET_CLAMP = (-25.0, 25.0)
clamped = clip(scale) != scale or clip(offset) != offset
quality = 'weak' if clamped else 'linear'
```

The 8-point threshold is a starting assumption, not a validated number — revisit once real patient usage data exists. If the linear fit's residual error is not clearly better than the additive-only result on held-out points, stay on additive-only regardless of point count.

### Clamping (unchanged, still applies whenever linear is used)

```
scale  clamped to [0.70, 1.30]
offset clamped to [-25, +25] mmHg
```

### Quality flag logic (revised)

```
if samples_count == 1:                     calibration_quality = "cold_start"
elif samples_count < 8:                    calibration_quality = "additive"
elif samples_count >= 8 and fit in bounds: calibration_quality = "linear"
elif samples_count >= 8 and fit clamped:   calibration_quality = "weak"
```

### Gating (unchanged from the handoff — still applies)

Calibration points are only accepted when:
- signal quality is good
- cuff reading is physiologically valid
- model reading is accepted
- cuff and device measurements are close in time

---

## 3. Drift Detection

Goal: catch when a patient's calibration has gone stale (medication changes, weight changes, aging, sensor placement habits) without asking them to blindly re-calibrate on a fixed calendar.

### Rolling raw-signal tracking

On every accepted measurement (post quality gate), the backend logs the **raw, pre-calibration** model output (not the adjusted one) to a per-patient rolling window of the last 10 valid readings.

```
raw_recent_mean_sbp = mean(last 10 raw model SBP outputs)
raw_recent_mean_dbp = mean(last 10 raw model DBP outputs)
```

### Drift threshold

Compare the rolling mean against the `baseline_raw_mean` captured at calibration time:

```
if |raw_recent_mean_sbp - baseline_raw_mean_sbp| > 8 mmHg
   AND sustained across the last 5 readings (not a single outlier)
   => drift_flag = true, reason = "drift_detected"

if |raw_recent_mean_dbp - baseline_raw_mean_dbp| > 5 mmHg
   (same sustained condition)
   => drift_flag = true, reason = "drift_detected"
```

Using the **raw** model output (not the calibrated/adjusted one) is the key design point — the adjusted output can look stable even while drift is happening, because the old offset is still being applied on top of a shifted raw signal. Drift shows up in the raw signal first.

### Staleness ceiling (safety net alongside drift detection)

Even with no detected drift, flag calibration as due for a check-in after a hard ceiling:

```
if days_since(last_calibrated_at) > 90:
   => drift_flag = true, reason = "calibration_stale"
```

This is a light-touch fallback, not the primary mechanism — framed softer in the notification copy than an active drift detection ("you might want to double-check" vs "your readings pattern has changed").

### Notification behavior

- One notification per flag event, then a cooldown of 14 days before re-flagging the same patient (avoid nagging).
- Fail open, not closed: a drift flag does not block the app from showing the current adjusted BP. It adds a caution indicator ("Calibration needs review") — never hides the reading.
- Notification opens the same calibration entry screen used for first-time setup, pre-filled with context ("Last calibrated 91 days ago" or "Your readings pattern has shifted").

---

## 4. Backend Work Items

New/changed endpoints:

```text
POST /api/v1/bp/calibration/point
  - Adds one cuff-vs-device calibration pair
  - Runs the existing gating checks from the handoff
  - Triggers recompute of scale/offset

GET /api/v1/bp/calibration/status
  - Returns: calibration_quality, samples_count, last_calibrated_at,
    drift_flag, scale, offset (technical view only)

POST /api/v1/bp/calibration/recompute
  - Internal call, not user-facing
  - Refits scale/offset from all stored calibration_points
  - Applies clamping and quality flag logic (Section 2)
```

New scheduled job (reuse the existing `scheduler_service.py` / APScheduler pattern already used for medication reminders):

```text
daily_drift_check_job
  - Iterates patients with an active calibration
  - Updates rolling raw-signal window
  - Applies drift threshold + staleness ceiling logic
  - Sets drift_flag and triggers FCM notification via existing
    notification_service.py pattern, respecting the 14-day cooldown
```

Database migration needed for the new calibration fields (Section 1).

---

## 5. Flutter Work Items

Screens/components:

- **Calibration entry screen** (shared between first-use and recalibration flows) — cuff reading input, immediate device measurement trigger, result display (offset/scale computed, in plain language for the patient).
- **Calibration status widget** — extends the existing patient dashboard "calibration status" item to show quality (`good` / `needs another reading` / `check recommended`) in localized text, not raw enum values.
- **Recalibration prompt flow** — triggered by the drift notification, opens the same calibration entry screen with context copy explaining why ("It's been a while" or "Your readings have shifted").
- **Caregiver technical view** — raw model BP alongside adjusted BP, plus calibration quality, per the existing caregiver detail page spec in the handoff.

---

## 6. Parallel Execution Plan

Backend and Flutter proceed together; the API contract in Sections 4-5 is the shared handoff point — freeze it before either side starts wiring real network calls.

**Phase 1 — Foundation (parallel start)**
- Backend: DB migration for calibration fields; implement and unit-test the linear fit function in isolation (pure function, no API yet) — feed it known point sets and verify clamping behavior.
- Flutter: build the calibration entry screen UI against mock data; agree on the exact JSON shapes above so both sides build against the same contract.

**Phase 2 — Core calibration flow**
- Backend: wire `POST /calibration/point`, `GET /calibration/status`, `POST /calibration/recompute`; reuse the existing signal-quality gating logic from the measurement flow.
- Flutter: connect the calibration entry screen to the real endpoints; wire the calibration status widget into the patient dashboard.

**Phase 3 — Drift detection**
- Backend: rolling raw-signal window, `daily_drift_check_job`, staleness ceiling, notification trigger via the existing notification service.
- Flutter: recalibration prompt screen, notification tap handling, caregiver technical view showing calibration quality.

**Phase 4 — Testing and polish**
- Both: run the testing checklist below; Arabic/English pass on all new strings (stable IDs + localized labels, per the existing localization plan); confirm no endpoint depends on translated text.

---

## 7. Testing Checklist

- Cold start: single calibration point produces additive-only offset, `calibration_quality = "cold_start"`.
- 2-7 points produce additive-only (median offset), `calibration_quality = "additive"` — verify accuracy improves over uncalibrated, not just "some adjustment happened".
- 8+ points with a stable fit switch to `calibration_quality = "linear"`; verify the linear result is actually better than staying additive-only before trusting it in production.
- Clamping actually rejects an out-of-bounds fit (test with deliberately extreme synthetic points).
- Drift detection fires after 5 sustained readings past the threshold, not after a single outlier reading.
- Staleness ceiling fires at 90+ days with zero drift signal.
- Notification cooldown prevents re-flagging within 14 days.
- Adjusted BP is still shown (not hidden) when `drift_flag = true`.
- Recalibration flow correctly appends a new point rather than discarding calibration history.
- Caregiver technical view shows both raw and adjusted BP correctly labeled.
- Full flow tested in Arabic and English with identical underlying decisions (only display text changes).

---

## 8. Open Items / Risks

- The 8 mmHg SBP / 5 mmHg DBP drift thresholds and the 90-day staleness ceiling are starting points, not validated numbers — expect to tune them once real usage data exists.
- Drift detection needs at least 10 valid readings in the rolling window before it can flag anything; a patient who measures rarely will rely on the staleness ceiling as the only safety net for longer.
- This plan does not address escalation for unacknowledged critical alerts or multi-caregiver notification routing — both were raised as open questions but are out of scope for this specific calibration plan and belong in a separate alerts/escalation doc if prioritized later.
