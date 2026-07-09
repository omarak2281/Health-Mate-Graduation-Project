# Product Requirements Document

This PRD is reconstructed from the implementation, not written ahead of it.
Every requirement below is backed by a feature, model, endpoint, or rule that
actually exists in the codebase (cross-referenced to `ARCHITECTURE.md`,
`BACKEND.md`, `FRONTEND.md`, `DATABASE.md`, `BP_PREDICTION.md`,
`SYMPTOM_CHECKER.md`, and `IOT.md`). Where something is only partially built
or explicitly flagged as unresolved in the code, this document says so rather
than rounding up to a finished feature.

## 1. Product vision

Health Mate is a remote monitoring system for patients managing chronic
cardiovascular conditions (primarily hypertension) at home, with a linked
caregiver able to see the same data in near-real time. The product's central
bet is that continuous, low-friction blood-pressure monitoring — captured via
low-cost PPG/ECG hardware rather than a cuff, guided by scheduled reminders,
and backed by an AI model plus a rule-based safety layer — surfaces
deteriorating BP trends and acute risk earlier than periodic clinic visits or
inconsistent home cuff use would.

## 2. Business problem

Hypertension and related cardiovascular disease require sustained monitoring
to catch dangerous trends (or acute crises) between clinical visits, but
patients — particularly elderly patients — are inconsistent about manual
cuff measurement, and family caregivers typically have no visibility into
readings unless the patient reports them manually. Health Mate's answer,
as actually built, is threefold: (1) a wearable-style sensor unit that
reduces measurement friction, (2) a caregiver-linking system that gives a
family member or carer a live view of BP trends and emergency alerts without
the patient needing to relay anything, and (3) a symptom-triage layer that
can escalate concerning symptom combinations (independent of or alongside a
BP reading) toward a caregiver notification.

## 3. Objectives (as evidenced by what was actually built)

- Deliver cuffless BP estimation accurate enough to be clinically useful,
  measured against the AAMI/BHS standards (`BP_PREDICTION.md`) — currently
  achieved for DBP, not yet for SBP.
- Make BP measurement a guided, low-friction routine via scheduled
  reminders and a step-by-step in-app flow, rather than a manual, easy-to-skip
  task (`FRONTEND.md` §9).
- Give caregivers real-time visibility into a linked patient's vitals,
  medication adherence, and risk alerts without requiring the patient to
  actively share anything after the initial link (`ARCHITECTURE.md`,
  `BACKEND.md` §2).
- Improve real-world BP accuracy per patient via a calibration mechanism that
  learns from occasional reference cuff readings (`BP_PREDICTION.md` §9).
- Reduce missed medication doses via scheduled reminders plus an optional
  physical indicator (LED + buzzer) on a smart medicine box (`IOT.md` §2).
- Provide a symptom-triage capability that can stand alone or be triggered
  directly from a concerning BP reading, with a safety-first rule engine that
  can escalate urgency independently of the ML prediction and never let the
  model suppress a red flag (`SYMPTOM_CHECKER.md` §5).
- Support Arabic and English as first-class, parallel experiences rather than
  a translated afterthought (`FRONTEND.md` §5).

## 4. Stakeholders

- **Patients** — primary data source and primary beneficiary of early risk
  detection and medication support.
- **Caregivers** (family members or informal carers, not clinical staff —
  there is no separate "clinician" role anywhere in the system) — secondary
  users who monitor one or more linked patients.
- **Development team** — building and evaluating both the product and the
  underlying ML models as a graduation project.
- **Academic supervisors** — evaluating the project's technical depth and
  completeness.

There is no evidence in the codebase of a third user type (e.g., a doctor
or clinic-staff role, a hospital admin console, or a billing/subscription
actor) — `UserRole` is a two-value enum (`PATIENT`, `CAREGIVER`), and no
schema, endpoint, or screen suggests a broader role model was built or even
partially scaffolded.

## 5. Target users / personas

**Patient** — typically an older adult managing hypertension, who benefits
from large, simple UI, minimal steps to take a reading, guided instructions
for hardware use, and reminders that don't require them to remember a
schedule (`FRONTEND.md` §9's onboarding-first calibration flow, and
`BACKEND.md`'s medication-alarm scheduler). Arabic-language support is
treated as equally important as English, not a secondary market.

**Caregiver** — a family member or informal carer, potentially managing
multiple linked patients (`patient_caregiver_links` supports many-to-many,
`DATABASE.md` §3), who needs an at-a-glance risk view, emergency alerting,
and a way to reach the patient quickly (the calling feature,
`FRONTEND.md` §11).

## 6. Functional requirements (implemented)

Grouped by the features that actually exist:

- **Authentication**: email/password and Firebase-based (social) sign-up and
  login, JWT access + refresh tokens, role selection at registration.
- **Patient–caregiver linking**: link by user ID (with a QR-code UI on top,
  `BACKEND.md` §1), multiple caregivers per patient, one designated primary
  caregiver, unlinking.
- **Blood pressure monitoring**: manual entry, sensor-driven guided
  measurement (8-second PPG+ECG capture), AI-based SBP/DBP estimation,
  per-patient calibration (median-offset then linear-fit, `BP_PREDICTION.md`
  §9), calibration drift/staleness detection with re-calibration prompts,
  risk classification (normal/low/moderate/high/critical), history and
  statistics views, caregiver read access to a linked patient's data.
- **BP measurement reminders**: up to 3 daily reminder times derived from one
  patient-chosen start time.
- **Medication management**: medication catalog with dosage/schedule,
  optional smart-box drawer assignment, scheduled alarms (push + local
  notification + optional physical LED/buzzer indicator), adherence logging
  with optional photo proof.
- **Symptom checker / triage**: two parallel implementations — a free-text
  chat and category-based flow (v1), and a structured, severity/duration/
  vitals-aware assessment wizard with a red-flag/urgency rule engine and a
  direct BP-reading-to-triage handoff (v2) (`SYMPTOM_CHECKER.md`).
- **Emergency alerting**: automatic caregiver push notification on
  high/critical BP readings (with per-risk-tier cooldowns), and an explicit
  "notify caregiver" trigger from the symptom-checker flow.
- **Medical contacts**: doctor/clinic/pharmacy/emergency/family contact list
  per patient, with auto-added caregiver-as-family-contact on linking.
- **Audio/video calling**: WebRTC calls between a patient and a linked
  caregiver, with incoming-call and emergency-call-specific screens.
- **Notifications inbox**: in-app list of all past notifications, read/unread
  state.
- **Localization**: full English/Arabic parity with RTL support.
- **Offline support**: cached last-known BP reading and history for offline
  viewing (Hive-backed, `FRONTEND.md` §4); reminders continue to fire locally
  without connectivity.

## 7. Non-functional requirements

- **Bilingual by default** — not a toggle bolted onto an English-first app;
  translation parity is close to 1:1 (613 vs. 614 keys, `FRONTEND.md` §5).
- **Fail-soft hardware integration** — an unreachable medicine box or a
  not-yet-loaded AI model must never crash a request or a scheduled job
  (`BACKEND.md` §5); this is implemented consistently, not aspirational.
- **Physiological safety clamping** — model outputs are clamped to
  physiologically plausible ranges before ever reaching a patient screen
  (`BP_PREDICTION.md` §10).
- **Escalate-only safety rule** — the symptom-checker rule engine may raise
  urgency above what the ML model implies but must never lower it
  (`SYMPTOM_CHECKER.md` §5) — a hard non-functional safety constraint, not a
  soft guideline.
- **Device authentication separate from user authentication** — hardware
  does not share the user JWT trust boundary (`BACKEND.md` §1).

Two non-functional expectations that a production medical product would
normally have are **not** currently met, and this PRD records that plainly
rather than assuming them:
- **Session revocation** — logout and refresh-token rotation do not actually
  invalidate anything server-side (`BACKEND.md` §1).
- **Linking-request integrity** — the QR-based linking flow has no
  cryptographic protection (`BACKEND.md` §1).

## 8. Representative user stories

- *As a patient*, I want to be reminded to measure my blood pressure at
  consistent times each day, so I don't have to remember on my own.
- *As a patient*, I want the app to walk me through attaching the sensor
  correctly before measuring, so a bad reading isn't due to my own setup
  mistake.
- *As a patient*, I want a critical reading to immediately notify my
  caregiver, so I don't have to make that call myself in an emergency.
- *As a caregiver*, I want to see a linked patient's latest reading and risk
  level without asking them, so I can check in proactively.
- *As a caregiver*, I want to be notified if a patient's calibration has
  drifted or gone stale, so their readings stay trustworthy over time.
- *As a patient*, I want to describe my symptoms and get a red-flag warning
  if something urgent is present, even if I haven't measured my BP that day.
- *As a patient or caregiver*, I want to reach the other person by call
  directly from the app during a concerning reading, without switching apps.
- *As a patient*, I want the entire app, including reminders and alerts, in
  Arabic if that's my preferred language, with no English fallback text
  leaking through.

## 9. Business rules (as encoded in the domain layer, not assumed)

- BP risk tiers: Low < 90/60; Normal 90/60–120/80; Moderate 120–139/80–89;
  High 140–179/90–119; Critical ≥ 180/120 (`vital_sign.py`).
- Symptom-checker urgency: Critical if any red flag severity ≥ 3 or vitals
  cross the critical BP/SpO2 threshold; High if any red flag or vitals cross
  the high threshold; Moderate if ≥ 2 symptoms at severity ≥ 2, or known
  hypertension plus elevated vitals; else Low (`urgency_rules.py`).
- Red flags: most trigger at severity ≥ 2; syncope/loss-of-consciousness
  variants trigger at any severity ≥ 1 (`red_flag_rules.py`).
- BP-triage override: a vitals-driven assessment scoring moderate/high
  (not yet critical) recommends resting 5 minutes and re-measuring, in
  addition to the standard urgency response (`run_bp_triage.py`).
- Calibration: fewer than 8 cuff-vs-model sample pairs → median-offset only;
  8+ → least-squares linear fit; both paths clamp scale to [0.70, 1.30] and
  offset to [-25, +25] mmHg (`calibration_service.py`).
- Calibration drift: flagged if the mean of the last 5+ raw readings
  sustains a shift of > 8 mmHg (SBP) or > 5 mmHg (DBP) from baseline, or if
  the calibration is older than 90 days; re-notification is throttled to
  once per 14 days (`bp_drift_service.py`).
- Emergency alert cooldown: 15 minutes for critical readings, 30 minutes for
  high/low, per patient per risk tier (`notification_service.py`).
- One active primary caregiver per patient, enforced at the database level,
  not just in application code (`DATABASE.md` §3).

## 10. Success metrics (only the ones the project actually measures)

- **BP model**: SBP/DBP MAE, AAMI pass/fail, BHS grade, per-class MAE
  (`BP_PREDICTION.md` §8) — the only quantitative model-quality metrics that
  exist in the project.
- **Symptom checker**: top-1/top-3 classification accuracy on a held-out
  split (`SYMPTOM_CHECKER.md` §4).
- **Symptom-checker rollout metrics** (in production, not just offline):
  assessment count, red-flag trigger rate, caregiver-notification rate,
  average/max latency — tracked live via `symptom_checker_metrics.py` and
  exposed at `GET /ai/assessment/rollout-metrics`.

No business-level success metrics (adoption, retention, clinical outcome
tracking) are implemented or instrumented anywhere in the codebase; this PRD
does not invent any.

## 11. Constraints

- Single-host Docker Compose deployment; no staging/production split, no
  reverse proxy/TLS, no orchestration (`ARCHITECTURE.md` §6).
- Hardware and app must share a Wi-Fi network, with IP addresses
  hand-maintained across four separate files (`ARCHITECTURE.md` §6).
- The BP model's clinical evidence is limited to a held-out split of a
  MIMIC-derived ICU dataset — not yet validated against the actual sensor
  hardware or an ambulatory/healthy population (`BP_PREDICTION.md` §12).
- The symptom-checker v2 dataset is entirely synthetic
  (`SYMPTOM_CHECKER.md` §9).

## 12. Assumptions

- Patient and caregiver share a trusted relationship once linked — the
  system does not model consent withdrawal beyond unlinking, nor does it
  support a patient restricting *which* data a linked caregiver can see.
- The deployment environment (developer's home Wi-Fi, in the evidence
  available) is a stand-in for a more controlled network in an eventual
  production deployment.
- A caregiver checking the app periodically, rather than requiring 24/7
  live monitoring, is an acceptable model of "remote monitoring" for this
  product's current scope.

## 13. Risk analysis (grounded in findings from the other documents)

| Risk | Evidence | Severity |
|---|---|---|
| SBP estimation fails the clinical AAMI standard | `BP_PREDICTION.md` §8 | High — affects the product's core clinical claim |
| Symptom checker is weakest on cardiac subtypes | `SYMPTOM_CHECKER.md` §4 | High — the project's target specialty |
| No server-side session/token revocation | `BACKEND.md` §1 | Medium — standard JWT tradeoff, but real |
| Unencrypted QR-based linking | `BACKEND.md` §1 | Medium — a stranger's scanned/guessed UUID would link identically |
| `/iot/sensors/*` always returns simulated data | `BACKEND.md` §4 | Low-medium — could mislead anyone building against that endpoint expecting live telemetry |
| Calibration simulation used non-representative sample spacing | `BP_PREDICTION.md` §9 | Medium — the deployed calibration service's real-world accuracy is unverified either way |
| Two independent symptom-checker implementations increase maintenance surface | `SYMPTOM_CHECKER.md` §9 | Medium — a fix to one doesn't propagate to the other |

## 14. Use cases

1. Patient takes a scheduled BP reading via guided sensor flow → reading
   stored, caregiver alerted if risk-tier warrants it.
2. Patient enters a cuff reading to complete a pending sensor reading →
   calibration sample recorded, future readings adjusted.
3. Caregiver opens a linked patient's detail page → sees latest BP, risk
   badge, calibration status, history.
4. Patient reports symptoms via the structured wizard → rule engine +
   ML model jointly determine urgency → caregiver notified if warranted.
5. Medication alarm fires → notification sent, smart-box LED/buzzer
   activated if assigned, patient confirms "taken" (with optional photo).
6. Caregiver calls a linked patient (or vice versa) directly from the app
   during a concerning reading.

## 15. System scope

In scope, and built: everything in Section 6.

## 16. Out of scope (not built, and not implied by anything in the code)

- Clinical staff / doctor role or clinic-facing dashboard.
- Billing, subscriptions, or multi-tenant organization accounts.
- Continuous (always-on) BP monitoring — the implementation is
  reminder-plus-manual-measurement, not continuous wear: `bp_reminder_service.py`
  schedules up to 3 discrete daily reminder windows, and the sensor firmware
  itself only captures an 8-second window per invocation rather than
  streaming continuously (`IOT.md` §1).
- Server-side session/token revocation (flagged as a gap, not shipped).
- Encrypted or expiring caregiver-linking credentials.

## 17. Feature priority (as evidenced by build depth and test investment)

Highest evident investment: the BP measurement/calibration/drift pipeline and
the symptom-checker v2 rule engine — both have the deepest test coverage
(`BACKEND.md` §6) and the most layered architecture (`ARCHITECTURE.md` §2.2).
Lower evident investment: the legacy v1 symptom checker (kept running but
with a single narrow test) and the generic `/iot/sensors/*` mock endpoints.

## 18. Release scope / roadmap (inferable, not invented)

What exists today functions as a single, un-versioned release rather than a
staged rollout with feature flags for end users (the one exception being
`symptom_checker_v2_enabled`, a backend-only settings flag, not a user-facing
release toggle). The clearest forward-looking signal in the code itself is
the symptom-checker's own architecture comment referencing a "Phase 6"
(swapping the JSON taxonomy repository for a Postgres-backed one,
`ARCHITECTURE.md` §2.2) as the next planned structural step for that one
subsystem specifically — no broader roadmap artifact exists in the code for
the rest of the product.
