# BP Feature — Phase 1: Real Device-Ready Measurement Pipeline + Caregiver Safety Fixes

Status: **Approved for execution** (approved 2026-07-02). This is the plan the implementing model (any model, including a cheaper one picking this up later) should follow step by step. Progress against this plan is tracked incrementally in `Plans/BP_PROGRESS.md` (create it first, update it after every item — do not write it once at the end). Do not skip ahead without updating that log.

This plan mirrors `Plans/SYMPTOM_CHECKER_PROGRESS.md`'s proven format and sits alongside `Plans/BP_MASTER_IMPLEMENTATION_PLAN.md` (the full 13-section long-term plan) as the realistic, honestly-scoped first phase of it — read the master plan for full background/rationale on sections referenced below (e.g. "master plan §5"), but implement against *this* document.

---

## Context

`Plans/BP_MASTER_IMPLEMENTATION_PLAN.md` assumes a trained Keras BP model and working ESP8266 firmware. Neither exists yet: the ML model isn't trained, and the only firmware that exists (`bp-hardware-code/bp-hardware-code.ino`) is Serial-only — no WiFi, no HTTP POST, no 800-sample @ 100Hz collection, `sampleAverage=4` instead of the required `1`. It only proves the sensors are wired correctly. Today BP is 100% manual text entry in the app.

The user wants this fixed properly, not deferred wholesale: firmware + backend + Flutter should be built now so the pieces are **ready to connect over the network the moment the device is flashed** — not just documentation. Since the ML model that turns raw PPG/ECG into an actual SBP/DBP number doesn't exist yet, Phase 1 uses an honest hybrid: the **device** reliably measures **heart rate + SpO2 + signal quality** (the existing onboard `maxim_heart_rate_and_oxygen_saturation`algorithm already does this without any ML), and the **patient** still enters the cuff-measured **systolic/diastolic** to complete the reading — exactly the calibration-point shape (`cuff_sbp/cuff_dbp` + device `hr`/signal data) the master plan's real calibration phase will need later, so nothing here is thrown away once the model ships. Real raw-array transmission for BP prediction is explicitly deferred to when the model exists (see "Deferred" section).

Also fixed in this plan: the dead-code `abp_prediction_service.py` currently **fabricates random mock BP values** (`120 + np.random.normal(...)`) — this is actively dangerous if ever accidentally wired in and must be removed, not left as "harmless because unused."

**Not part of this plan** (already done in the same session that produced this plan, unrelated feature): a dead `notifyMessage` field and a `copyWith` correctness bug were fixed in `Front-end/health_mate_app/lib/features/symptom_checker/presentation/providers/assessment_result_provider.dart`. Also already fixed in that same session, inside the BP-adjacent `bp_card.dart`/ `symptom_checker_wizard_page.dart`/`followup_questions_page.dart` files (symptom-checker &lt;-&gt; BP handoff flow, not this plan's scope): a dialog-context-reuse-after-pop bug in `bp_card.dart`, and a bug where BP vitals were silently dropped before submission to the symptom-checker's `/bp-triage` endpoint due to a widget-initState timing issue. Do not redo these.

---

## Decisions locked in with the user (do not re-litigate)

- **Alert cooldown: 30 min for HIGH, 15 min for CRITICAL** BP alerts, scoped per-patient, per-risk-level (a CRITICAL alert must never be suppressed by a still-open HIGH cooldown).
- **Alert routing stays "all active caregivers always get notified."** `is_primary` is NOT used to filter/prioritize who gets alerted — that was explicitly rejected by the user. It exists as backend-only bookkeeping matching the master plan's schema (§3.6), with **no UI surface** in Phase 1 and **no manual "set primary" endpoint**.
- **The guide pages are not generic BP-health education.** They are the live guided **device measurement flow**: hardware setup steps, finger placement, a countdown while measuring, handling error scenarios (finger missing, poor signal, lead-off) with in-the-moment guidance, ending in the manual cuff-BP entry step described above.
- **Firmware is in scope this phase** (rewrite `bp-hardware-code.ino` into real WiFi+POST firmware) — this was explicitly confirmed, not assumed.

## Open items needing a quick confirmation at implementation time (flagged, not silently guessed)

1. **Measurement window length**: master plan §2 requires exactly **800 samples @ 100Hz = 8.0 seconds** for the eventual ML model's input shape. This plan uses **\~8 seconds** (not the "\~10 seconds" mentioned conversationally at one point) so firmware and UI stay consistent with the model's real input contract. Firmware and Flutter must both read this from one shared constant (define once, e.g. `MEASUREMENT_WINDOW_SECONDS = 8`), not hardcode it twice.
2. **Real WiFi credentials** (SSID/password) for the ESP8266 — same pattern as the existing medication ESP32 sketch (`smart-box-hardware-code/sketch_jun23a.ino`, hardcoded `ssid`/ `password` consts). Use placeholder consts with a clear `// TODO: set real network credentials before flashing` comment until the user supplies real values.
3. **No physical device is available to test against in this environment.** Firmware work must be verified by structural/compile-logic review only (correct pin mapping vs. `bp-hardware-code/wiring_table_esp8266_max30102_ad8232.html`, correct sample-rate math, valid JSON payload shape matching the Pydantic schema exactly). State this limitation plainly in `Plans/BP_PROGRESS.md` — never claim a real hardware test happened when it didn't.

---

## Work breakdown

### A — Firmware (`bp-hardware-code/bp-hardware-code.ino`, rewritten)

Reuse the WiFi-connect boilerplate style from `smart-box-hardware-code/sketch_jun23a.ino`(`WiFi.begin(ssid, password)`, wait loop, print IP), but data flows the **other direction**: this device is an HTTP **client** POSTing to the cloud backend, not a local server being called into (unlike the medication box, which runs its own local `WebServer`).

- Keep the existing MAX30105/AD8232 sensor code, fix `ppg.setup(60, 1, 2, 100, 411, 4096)`(`sampleAverage` 4→1, per master plan §8 — this is a confirmed, named requirement, not a guess).
- Add finger-presence and lead-off gating **before** starting a measurement window — don't collect a window at all if finger missing or leads off (master plan §5 "fail fast").
- Collect the \~8s window, run the already-present `maxim_heart_rate_and_oxygen_saturation` to get HR/SpO2 (no ML needed for this part), and POST a small JSON payload (not raw sample arrays yet — see "Deferred") to `POST /api/v1/vitals/bp/submit`:

  ```json
  {"device_id": "...", "patient_id": "...", "hr": 78, "spo2": 97,
   "finger_detected": true, "leads_ok": true, "signal_quality": "good",
   "collected_at": "..."}
  ```
- Retry with exponential backoff on network failure, cap at 3 attempts, then report `"device_offline"` over Serial. A local status endpoint for the app to poll is optional/later, not required for Phase 1.
- **Never compute or invent a BP value on-device** (master plan §1 non-negotiable: the device never decides anything, it only measures/forwards raw or lightly-processed signal data).

### B — Backend

| File | Change |
| --- | --- |
| `Back-end/app/api/v1/vitals.py` | Add `POST /vitals/bp/submit` (device-originated) alongside the existing manual `POST /vitals/bp`. Runs the quality gate, on pass persists a `VitalSign` with `source="sensor"`, `heart_rate`, `signal_quality`, `measurement_status="completed_pending_bp"` (new status — HR/SpO2 known, systolic/diastolic still awaited), on fail persists nothing and returns a stable `rejection_reason` code (`finger_missing`|`leads_off`|`poor_signal`). Add `POST /vitals/bp/{reading_id}/complete` for the patient to attach cuff systolic/diastolic to a pending device reading (reuses `calculate_risk_level()` once both values are present, then follows the existing alert path). |
| `Back-end/app/schemas/vital_sign.py` | Add `VitalSignDeviceSubmit` (hr, spo2, finger_detected, leads_ok, signal_quality, device_id) and `VitalSignComplete` (systolic, diastolic) schemas. Add a `systolic > diastolic` cross-field validator to the existing `VitalSignCreate` too (applies to manual entry). |
| `Back-end/app/models/vital_sign.py` | Add `measurement_status` column (`completed` | `completed_pending_bp` | `rejected`) and `device_id` (nullable string); keep existing columns otherwise — additive only. |
| `Back-end/app/services/abp_prediction_service.py` | **Delete the mock-random-value fabrication.** Replace with a clearly-named stub that explicitly returns/raises "not ready" — never a fake number. Left wired for a later phase to fill in once the real model exists. |
| `Back-end/app/models/patient_caregiver_link.py` + migration | Add `is_primary BOOLEAN NOT NULL DEFAULT false` + a partial unique index (`WHERE is_primary AND is_active`) — bookkeeping only, per the locked decision above. |
| `Back-end/app/services/patient_caregiver_service.py` (new) | Shared `assign_is_primary_for_new_link()` used by **all three** call sites: `users.py::link_user`'s create branch, `users.py::link_user`'s reactivate branch (easy to miss), and `auth.py`'s auto-link-on-signup path. On unlink of a primary with other active links remaining, promote the oldest remaining active link to primary. |
| `Back-end/app/services/notification_service.py` | Add a cooldown gate inside `send_emergency_bp_alert`: new `bp_alert_cooldowns` table keyed `(patient_id, risk_level)`, upsert `last_sent_at` via `postgresql.insert(...).on_conflict_do_update(...)`, skip sending if within the 30min(HIGH)/15min(CRITICAL) window. Alert recipients stay "all active caregivers" — unchanged. |
| `Back-end/alembic/versions/<ts>_bp_phase1.py` | One migration: `is_primary` column + partial unique index, `bp_alert_cooldowns` table, `vital_signs.measurement_status`/`device_id` columns. **Run** `alembic heads` **first** to get the true `down_revision` — do not hardcode it from memory of past migration names. |
| `Back-end/tests/...` | `test_vital_sign_validation.py` (cross-field + range boundaries), `test_patient_caregiver_link_primary.py` (all 3 call sites + unlink promotion + DB-level unique-index enforcement via a raw-insert IntegrityError test), `test_bp_alert_cooldown.py` (suppresses duplicates, per-risk-level independence — CRITICAL not suppressed by HIGH's cooldown, per-patient scoping), `test_vitals_device_submit.py` (quality-gate accept/reject cases, pending-then-complete flow). |

### C — Flutter

| File | Change |
| --- | --- |
| `lib/features/vitals/presentation/pages/bp_measurement_guide_page.dart` (new) | The guided flow: connect → place finger/attach leads → live \~8s countdown with real-time status ("hold still", "signal weak, adjust finger") → on success, transitions straight into the existing manual-entry step *pre-filled with the device's HR* to collect cuff systolic/diastolic → submits via the new complete-reading call. On device-offline/quality-fail, shows a clear localized retry state (mirrors master plan §9.2's state list: `no_device`/`finger_missing`/`leads_off`/`measuring`/`poor_signal_retry`). |
| `lib/features/vitals/data/vitals_repository.dart` | Add `submitDeviceReading(...)` and `completeReading(readingId, systolic, diastolic)`, mirroring the existing `createBPReading` pattern (Hive/SharedPrefs cache + rethrow). |
| `lib/core/constants/api_constants.dart` | Add `bpSubmit`, `bpComplete(readingId)` following the existing `bpCreate`/`patientBPCurrent(...)` naming style. |
| `lib/features/vitals/presentation/widgets/bp_card.dart` | Add client-side range + `systolic>diastolic` validation to the existing manual dialog (mirrors backend bounds); fix the dialog to read and show `VitalsNotifier`'s existing `errorMessage` on failure (already captured in the notifier, just never displayed — no new try/catch needed); add an entry point into the new guided measurement flow as the primary "Add Reading" action, keeping quick-manual-entry as a secondary option for when the device isn't handy. |
| `lib/features/home/presentation/pages/caregiver_patient_detail_page.dart` | Replace 3 hardcoded English strings (around lines 119, 535, 555) with `LocaleKeys` entries; fix the misleading "requesting from device" copy — that button only calls `loadCurrentBP()` (a cache/API refresh), not a live device push. |
| `lib/core/constants/locale_keys.dart` + `assets/translations/{en,ar}.json` | New keys under `vitals.*` for guide steps/states/errors and `home.*` for the 3 caregiver-page fixes (matching neighboring key namespaces in each file). Arabic copy for the guide steps should be reviewed by the user before shipping — this plan defines the key structure and English placeholders only, not final wording. |
| `test/features/vitals/...` | Widget/unit tests for the new validation logic and the error-surfacing fix. |

---

## Verification

- Backend: `cd Back-end && pytest tests/ -v` — must stay green (77 existing + new tests), reusing the async-DB-session fixture style already in `tests/api/v1/test_assessment_endpoints.py`.
- Firmware: no physical device available — verified by structural/compile-logic review only (pin mapping vs. the wiring doc, sample-rate math, JSON payload shape matching the Pydantic schema exactly). State this limitation explicitly in `Plans/BP_PROGRESS.md`.
- Flutter: `flutter analyze` clean, `flutter test` green, manual smoke test covering: reject invalid manual entry, cooldown suppresses a second caregiver alert within the window but the reading still saves, guided flow's error states render correctly and in Arabic, primary-caregiver DB invariant holds across link/relink/unlink sequences (checked via test, no UI to eyeball since there's no Phase-1 UI surface for it).
- `Plans/BP_PROGRESS.md`: created first as a skeleton (status table, all "Not started"), updated after each item completes — mirrors `SYMPTOM_CHECKER_PROGRESS.md`'s structure (phase table, dated "Execution note" entries, explicit Deviations log, explicit Deferred-to-later-phases list, explicit Known-gaps-at-end list) so a different/cheaper model can resume from it directly without re-reading this whole conversation.

## Explicitly deferred (stated up front, not silently dropped)

- Raw PPG/ECG array transmission + actual `predict_bp()` ML inference — needs the trained model first (master plan §2). Phase 1's payload/schema is designed so adding this later only extends the payload and fills in the prediction step, without re-architecting the endpoint.
- Calibration fitting (`bp_calibration_service.py`, least-squares scale/offset) — depends on having several real model-vs-cuff pairs, which this phase starts collecting (`measurement_status='completed_pending_bp'` rows are exactly future calibration points) but does not yet fit.
- Drift detection, full multi-tier escalation state machine (cooldown-only in Phase 1), scheduled measurement reminders, caregiver per-severity `alert_preferences` UI, `features/vitals/` Clean Architecture restructure (bringing it in line with `features/symptom_checker/`'s domain/data/ presentation split), app-wide push-notification localization (no `User.language` field exists anywhere in the app — pre-existing, cross-cutting, not BP-specific).

---

## Critical files

- `bp-hardware-code/bp-hardware-code.ino`
- `Back-end/app/api/v1/vitals.py`, `app/schemas/vital_sign.py`, `app/models/vital_sign.py`
- `Back-end/app/services/notification_service.py`, `app/services/patient_caregiver_service.py` (new), `app/services/abp_prediction_service.py`
- `Back-end/app/models/patient_caregiver_link.py`
- `Front-end/health_mate_app/lib/features/vitals/presentation/pages/bp_measurement_guide_page.dart` (new)
- `Front-end/health_mate_app/lib/features/vitals/presentation/widgets/bp_card.dart`
- `Front-end/health_mate_app/lib/features/home/presentation/pages/caregiver_patient_detail_page.dart`
- `Plans/BP_PROGRESS.md` (new — create before writing any code)