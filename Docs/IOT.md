# IoT Hardware

Health Mate has two entirely separate hardware subsystems — a blood-pressure
sensing unit and a smart medicine box — built on different microcontrollers,
different firmware, and different interaction models. `ARCHITECTURE.md` §5
introduces both; this document covers each in full, straight from the
firmware source in `bp-hardware-code/` and `smart-box-hardware-code/`, plus
the backend/frontend code that talks to them.

## 1. Blood pressure sensing unit

### Hardware

- **ESP8266-12E NodeMCU** — WiFi microcontroller, no on-device model
  inference.
- **MAX30102** — PPG (photoplethysmography) sensor, wired over I2C.
  Configured with `ppg.setup(60, 1, 2, 100, 411, 4096)` — critically,
  `sampleAverage=1`, chosen specifically to produce raw, unaveraged 100 Hz
  output matching the trained model's expected input rate
  (`BP_PREDICTION.md` §10).
- **AD8232** — single-lead ECG front-end, analog output on `A0`, with
  dedicated lead-off detection pins (`D6`/`D7`) and a shutdown pin (`D5`,
  held high to keep the chip enabled).

### Firmware behavior (`bp-hardware-code.ino`)

This is real, working firmware, not a wiring test — the following behavior
is confirmed directly in the `.ino` source:

- Samples both channels at a precise 100 Hz (a 10ms loop check), buffering
  exactly 800 samples per channel (`BUFF_SIZE`) — an 8-second window matching
  `WINDOW_SIZE` in both the training notebook and `abp_prediction_service.py`.
- **Gates on signal presence before accepting any sample**: `checkGating()`
  requires both ECG leads connected (`LO_PLUS`/`LO_MINUS` both low) and a
  finger detected on the PPG sensor (IR reading > 50,000 counts). If gating
  fails for 50 consecutive checks (~500ms), the in-progress buffer is
  discarded rather than silently accepting a bad window.
- Computes **on-device SpO2** (ratio-of-ratios method from accumulated
  red/IR sum and sum-of-squares statistics, avoiding the memory cost of
  buffering the red channel) and **on-device heart rate** (simple
  peak-detection over the PPG buffer), both included in the uploaded JSON
  only when the computed value is physiologically plausible — an unusable
  SpO2/HR reading is omitted from the payload entirely rather than sent as a
  zero or placeholder.
- **Uploads the completed window** via `HTTP POST` to
  `/api/v1/vitals/bp/submit`, with `X-Device-ID`/`X-Device-Token` headers
  (checked against the `registered_devices` table, `BACKEND.md` §1) and an
  **exponential-backoff retry policy** (up to 4 attempts, doubling the delay
  each time) — except on a 401/403/422 response, which is treated as a
  permanent rejection and aborted immediately rather than retried.
- **Sends a heartbeat** to `/bp/heartbeat` — on a 10-second timer, or
  immediately (checked at most once per second) whenever the finger/lead
  state changes, so the backend's `RegisteredDevice.last_finger_detected`/
  `last_leads_connected` flags reflect a mid-measurement disconnection
  within about a second, not up to 10.

**A real, unresolved gap**: `deviceToken` in the current firmware is a
hardcoded placeholder string (`"test-token"`), not a per-device provisioned
secret — the authentication *mechanism* (hashed token compared server-side)
is real and correctly implemented, but the actual credential shipped in this
firmware file is not production-grade.

### Development tooling

Three supporting files exist purely to develop/debug the hardware without
needing the full Docker Compose stack running:

- **`bp_test_server.py`** — a standalone FastAPI server that loads the BP
  model and scalers directly from `Predict-ABP/1_BP_Prediction_v6_Final/
  BP_Deliverables/model_artifacts/`, independent of the main backend. Useful
  for testing the sensor pipeline against the model in isolation.
- **`bp_test_bench.html`** and **`health_monitor.html`** — browser-based
  dashboards (dark-themed, live-updating metric cards and a chart) for
  watching PPG/ECG/HR/SpO2/lead-status output while iterating on the
  firmware, without needing the Flutter app running.

### Product-level flow

The full guided-measurement sequence, calibration branching, and the
backend's resulting state machine (`COMPLETED` /
`COMPLETED_PENDING_BP` / `REJECTED`) are covered in `BP_PREDICTION.md` §14
and `FRONTEND.md` §9 — not repeated here.

## 2. Smart medicine box

### Hardware — and a correction worth being explicit about

- **ESP32**, running its own tiny `WebServer` on port 80.
- **A 74HC595 shift register** (`dataPin`/`clockPin`/`latchPin`) driving up
  to 6 LEDs, one per drawer.
- **A buzzer** (`buzzerPin`) for an audible alert.

**There is no motor, servo, solenoid, or any physical locking/dispensing
mechanism anywhere in the firmware** (`sketch_jun23a.ino`, and the two other
copies of the same logic, `smart-box-code.txt` and `Test-Smart-Box.txt`, all
confirm this — none import a servo library or drive any actuator beyond the
shift register and the buzzer). Concretely, this means:

**The smart box indicates which drawer to open — it does not open it.**
`handleActivateDrawer()` receives a JSON payload like `{"drawers": [3]}`,
lights the corresponding LED(s) via the shift register, and — only if the
drawer list is non-empty — runs a 100-pulse intermittent buzzer alert. An
empty list (`{"drawers": []}`) turns everything off. The patient still has to
physically open the correct drawer themselves once the LED points them to
it. Any description of this feature as "automatically dispensing" medication
overstates what the current hardware does; it is a guided-indicator system,
which is still a real and useful piece of assistive hardware for an elderly
or memory-impaired patient, but a materially different (and simpler, more
reliable) mechanism than a motorized dispenser.

### Firmware behavior

- On boot, connects to WiFi and starts a local HTTP server, printing its
  assigned IP to serial (which then has to be manually copied into
  `Back-end/app/core/config.py`'s `esp32_local_ip` and
  `Front-end/.../iot_constants.dart`'s `esp32BaseUrl` — the same
  hand-maintained IP coupling noted in `ARCHITECTURE.md` §6).
- `POST /activate` is the only real endpoint — validates the request has a
  JSON body and a `drawers` key, and returns a structured JSON error
  (`{"status":"error", ...}`) for a missing body, invalid JSON, or a missing
  `drawers` array, rather than a bare HTTP error with no explanation.
- The **test-bench version** of the same firmware (`Test-Smart-Box.txt`)
  replaces the HTTP server with a serial command interface (type `1`–`6` to
  light one drawer, `7` for all, `0` for off) — clearly a hardware
  bring-up/debug tool, used before the HTTP-driven version was wired in.

### Who talks to it, and how

Two independent callers can activate the box, not just one:

1. **The backend scheduler** (`app/services/scheduler_service.py` →
   `app/services/iot_service.py`'s `ESP32Service`) — when a medication alarm
   fires, the scheduler collects the drawers assigned to medications due at
   that time and calls `activate()`. This call is deliberately fail-soft: any
   connection error is logged and swallowed, never raised, so an unreachable
   medicine box can never crash the scheduled alarm job
   (`BACKEND.md` §5).
2. **The Flutter app directly** (`core/services/iot_service.dart`'s
   `controlDrawers()`) — makes its own HTTP call straight to the ESP32's
   local IP, bypassing the backend entirely. This means drawer control is
   not exclusively backend-mediated; the app can turn LEDs on/off directly
   as long as the phone is on the same network as the box, independent of
   whether the backend API is reachable at all.

### Real-world reliability characteristics

- **No acknowledgment of physical retrieval.** Because there is no sensor
  detecting whether a drawer was actually opened, the system has no way to
  know if a patient responded to the LED/buzzer alert — medication adherence
  (`medication_adherence` table, `DATABASE.md`) is logged from the patient
  explicitly confirming "taken" in the app, not from any drawer-open signal
  from the hardware.
- **Offline behavior**: if the ESP32 is unreachable when an alarm fires, the
  LED/buzzer step is silently skipped (fail-soft, above), but the
  app-side push/local notification for the same medication reminder is
  unaffected — the patient still gets notified on their phone even if the
  physical box never lights up.
- **Multiple medications at the same scheduled time** are handled by
  collecting all matching drawers into one `activate()` call
  (`{"drawers": [2, 5]}`), lighting multiple LEDs simultaneously rather than
  sequencing them one at a time.

## 3. Summary comparison

| | BP sensing unit | Smart medicine box |
|---|---|---|
| MCU | ESP8266-12E | ESP32 |
| Talks to backend how | Pushes data (`POST /bp/submit`, `/bp/heartbeat`) | Receives commands (`POST /activate`) |
| Authentication | Device ID + hashed token (real, if using a placeholder credential today) | None — plain HTTP, same-network trust only |
| Actuation | None (pure sensor) | LEDs + buzzer only — no physical dispensing |
| Failure mode | Retries with backoff, aborts cleanly on auth rejection | Fail-soft: errors logged, alarm job continues regardless |
| Also reachable directly from | Nothing else — only the firmware itself POSTs to the backend | The Flutter app, bypassing the backend entirely |

`bp-hardware-code/body.jpg` already exists in the repository and is directly
usable here: it's an AD8232 3-lead electrode placement diagram (red/yellow/
green lead positions on the torso and limbs, shown in two equivalent
placement variants), consistent with the AD8232's standard RA/LA/RL lead
convention. This is the reference a patient or setup technician would use to
correctly attach the ECG leads described in Section 1 — it should be reused
directly rather than redrawn.

[IMAGE REQUIRED] Description: Photos of the actual assembled BP sensing unit (ESP8266 + MAX30102 + AD8232 wired together) and the smart medicine box (drawer LEDs + buzzer + 74HC595 wiring), since no photo of the assembled electronics (as opposed to the lead-placement diagram above) exists in the repository. Suggested Location: IoT chapter of the main thesis, alongside `bp-hardware-code/body.jpg`. Purpose: firmware code doesn't convey the physical assembly; a photo would show drawer/LED layout and sensor wiring that the code alone can't.
