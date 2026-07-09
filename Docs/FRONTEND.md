# Frontend (Flutter)

`ARCHITECTURE.md` §3 already covers the app's high-level shape (Riverpod,
Dio/retrofit, three-tier local storage, `easy_localization`, and the real
gap between the declared `go_router` dependency and the imperative navigation
actually used). This document goes screen-by-screen and flow-by-flow, built
directly from `Front-end/health_mate_app/lib/`.

## 1. Folder structure

Feature-based, one directory per domain area under `lib/features/`, each
typically split into `data/` (repositories, data sources), `presentation/`
(pages, providers, widgets), and — for the two most recently built features
(`symptom_checker/`) — a proper `domain/` layer with entities and repository
interfaces, mirroring the backend's clean-architecture split for the same
feature. Shared code lives under `lib/core/`: `network/`, `services/`,
`storage/`, `providers/`, `localization/`, `theme/`, `constants/`, `models/`,
`repository/`, `error/`, `utils/`, `widgets/`.

Eleven feature directories exist: `auth`, `home`, `vitals`, `medications`,
`symptom_checker`, `ai`, `communication`, `contacts`, `linking`,
`notifications`, `settings`.

## 2. State management

Riverpod (`flutter_riverpod`) throughout. The pattern worth calling out:
several providers are built as **family providers** specifically so the same
screen logic can serve both a patient viewing their own data and a caregiver
viewing a linked patient's data, without a parallel set of "caregiver
version" widgets — e.g. the vitals provider family takes a target user ID and
resolves to either "self" or "linked patient" data depending on who's asking,
rather than the UI branching on role everywhere.

## 3. Networking

`Dio` + `retrofit`-generated clients, with a hand-written interceptor chain
in `core/network/dio_client.dart` doing real work, not boilerplate:

- **Automatic 401/403 recovery.** On a 401 or 403 response, the interceptor
  calls `_refreshToken()`, which reads the stored refresh token from
  `flutter_secure_storage`, calls `POST /auth/refresh`, and — if successful —
  persists the new access/refresh token pair and retries the original
  request transparently. A screen that makes an API call never has to know
  its token just expired mid-request.
- **`pretty_dio_logger`** for request/response logging in development.

## 4. Local persistence — three stores, three jobs

- **`flutter_secure_storage`** — JWT access/refresh tokens only.
- **`Hive`** — structured local data that needs to survive offline and
  support fast reads: the vitals repository (`features/vitals/data/
  vitals_repository.dart`) is a concrete, verified example of a genuine
  cache-then-network pattern, not just a label — `getLatestBP()` caches every
  successful network fetch via `_hiveCache.cacheLatestBP()`, and on a network
  failure falls back to `_hiveCache.getCachedLatestBP()` so the patient still
  sees their last known reading offline; the same pattern exists for BP
  history.
- **`SharedPreferences`** — simple app-wide flags (onboarding-seen, selected
  language, etc.).

## 5. Localization

`assets/translations/en.json` (613 keys) and `ar.json` (614 keys) — close to
1:1 parity, consistent with localization being treated as a first-class
concern rather than an incomplete afterthought. `easy_localization` drives
both string lookup and RTL layout switching for Arabic.

## 6. Error handling

`core/services/error_handling_service.dart` is a centralized error
classifier, not per-screen ad-hoc try/catch: `ErrorHandlingService.
detectErrorType()` takes any thrown exception and maps it to an `ErrorInfo`
(localized title/message/subtitle keys, plus a `canRetry` flag) — `DioException`
subtypes are mapped individually (connection timeout, bad response by status
code, cancelled request, connection error), so a screen can show "check your
internet connection, tap to retry" for a timeout and a different message for
a 404, without every screen re-implementing that branching itself.

## 7. Patient vs. caregiver — routing, not duplication

`SplashPage` reads the logged-in user's role directly and routes to either
`PatientHomePage` or `CaregiverHomePage` — two distinct home screens, but
built on the same underlying providers/repositories (Section 2) rather than
two independently maintained data layers. Caregiver-specific screens
(`caregiver_patient_detail_page.dart`, `linked_patients_page.dart`) reuse the
patient-facing widgets (BP cards, medication lists) against a different
target user ID.

## 8. Screens by feature

| Feature | Screens |
|---|---|
| `auth` | Splash → onboarding (language, welcome) → login/register → email verification |
| `home` | `PatientHomePage`, `CaregiverHomePage`, `LinkedPatientsPage`, `PatientDetailPage`, `CaregiverPatientDetailPage`, `IotScreen` |
| `vitals` | `BPMeasurementGuidePage` (guided measurement + calibration), `BPHistoryPage`, `BPDetailPage` |
| `medications` | `MedicationsPage`, `MedicationAlarmPage` (418 lines — full-screen alarm UI), `MedicationBoxPage`, `MedicineFormPage`, a 3-step `MedicineTutorialPage` sequence |
| `symptom_checker` | 5-step wizard — see `SYMPTOM_CHECKER.md` §8 |
| `ai` | `AiSymptomChatPage`, legacy `SymptomCheckerPage` — see `SYMPTOM_CHECKER.md` §8 |
| `communication` | `CallPage` (487 lines, WebRTC peer connection), `IncomingCallPage`, `EmergencyCallActionPage` |
| `contacts` | `MedicalContactsPage` |
| `linking` | `QrCodePage` (displays own UUID as a QR code), `QrScannerPage` (`mobile_scanner`-based scan → link) |
| `notifications` | `NotificationsPage` |
| `settings` | `SettingsPage` (includes a "Recalibrate now" action that opens `BPMeasurementGuidePage(quickRecalibration: true)`), `EditProfilePage`, `ChangePasswordPage` |

## 9. The guided BP measurement flow, in detail

`BPMeasurementGuidePage` is one of the more carefully built screens in the
app — it directly mirrors the backend calibration state machine described in
`BP_PREDICTION.md` §14, not just a generic "take a reading" screen:

- **Two distinct entry modes**, both routing to the same widget:
  `forceCalibration` (manual opt-in from Settings, forces the cuff-entry step
  even for an already-calibrated patient) and `quickRecalibration` (the
  Settings → "Recalibrate now" action). The code's own comment is explicit
  that recalibration still walks through the device-intro and sensor-
  placement steps rather than jumping straight to measurement — an earlier
  version apparently skipped straight to measurement and left patients
  trying to measure with the sensor not even attached yet, and this was
  fixed to always show the setup steps.
- **Live sensor status polling** every 2 seconds during setup (finger
  detected, leads connected) via `iotNotifierProvider`, driving the same
  gating feedback the ESP8266 firmware itself checks before accepting a
  window (`BP_PREDICTION.md` §10).
- **A calibration-status-driven branch**: `_loadCalibrationStatus()` decides,
  based on the patient's actual calibration state from the backend, whether
  the post-measurement screen shows the raw device result or forces a manual
  cuff-entry step — the same `not_calibrated`/`weak`/`recalibration_due` →
  `needs_cuff_confirmation` logic documented in `BP_PREDICTION.md` §9 and
  `BACKEND.md`'s calibration service description, now visibly present on the
  client side too, not just inferred from the backend.
- Status polling continues after submission (`_statusPollTimer`) to reflect
  a `COMPLETED_PENDING_BP` → `COMPLETED` transition once the patient supplies
  a cuff reading, without the patient needing to manually refresh.

## 10. Medication / smart box flow

`MedicationAlarmPage` is a dedicated full-screen alarm UI (distinct from the
regular medications list), triggered by the same FCM/local-notification path
described in `ARCHITECTURE.md` §7.2 for scheduled medication reminders. A
3-step `MedicineTutorialPage` sequence exists specifically to walk a new user
through smart-box drawer assignment before they rely on it — a real onboarding
investment for the hardware-dependent part of the medication feature, beyond
just a form to add a pill name and schedule.

## 11. Communication (calls)

Real `flutter_webrtc` usage (`RTCPeerConnection`, `createOffer`) in
`call_page.dart`, paired with the Socket.IO signaling events described in
`ARCHITECTURE.md` §2.3 (`make_offer`/`make_answer`/`send_ice_candidate`).
`IncomingCallPage` and `EmergencyCallActionPage` are separate screens from
the in-call UI, giving the incoming-call and "call for help" entry points
their own dedicated, simpler surfaces rather than reusing the full call
screen's state machine for what is really a different interaction.

## 12. Known gaps, stated plainly

- **`go_router` is an unused dependency** (`ARCHITECTURE.md` §3) — all
  navigation is imperative `Navigator.push`. Anyone extending navigation
  should not assume a route table exists.
- **The QR-linking flow has no cryptographic protection** (`BACKEND.md` §1) —
  the QR code is a bare UUID; the Flutter side does nothing to add
  expiry, signing, or a challenge/response step on top of what the backend
  already lacks.
- **Two parallel AI surfaces** (`features/ai/` and `features/symptom_checker/`)
  exist side by side with no shared navigation entry point unifying them —
  `SYMPTOM_CHECKER.md` §8 has the full detail.

[IMAGE REQUIRED] Description: Screenshots of the core patient and caregiver home screens, the BP measurement guide's setup/measuring/result states, and the medication alarm screen. Suggested Location: Illustrative Examples chapter of the main thesis. Purpose: this document is built entirely from source and has no way to produce actual rendered UI without a build/run pass against a device or emulator.
