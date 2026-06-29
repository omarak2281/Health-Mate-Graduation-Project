# Smart Box — Full Project Memory & PRD
**Last updated:** June 2025  
**Status:** Phase 2 in progress — ML model training on Kaggle  
**Handoff note:** This document is the single source of truth. A new AI model reading this can pick up exactly where we left off.

---

## 1. Project Identity

| Field | Value |
|---|---|
| Name | Smart Box (صندوق الدواء الذكي) |
| Type | University graduation project |
| Domain | Healthcare / IoT / Machine Learning |
| Developer | Mohamed |
| Stage | Phase 2 — Health Monitoring |

---

## 2. Full Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Android + iOS) |
| Backend | FastAPI + Docker |
| Auth & database | Firebase (Auth + Firestore) |
| **Push notifications** | Firebase Cloud Messaging (FCM) ← MOST CRITICAL |
| Phase 1 hardware | ESP32 + 6 drawers + RGB LEDs + buzzers + 74HC595 shift registers |
| Phase 2 hardware | ESP8266-12E NodeMCU + MAX30102 (PPG) + AD8232 (ECG) |
| ML training | TensorFlow/Keras on Kaggle GPU T4 × 2 |
| ML dataset | Kachuee/MIMIC-II — mkachuee/BloodPressureDataset (Kaggle) |
| Data format | .mat files, 125 Hz → resampled to 100 Hz |
| Web test dashboard | HTML + Web Serial API (Chrome/Edge only) |

---

## 3. System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 1 (COMPLETE)                                                  │
│  ESP32 ← Firebase RTDB ← Flutter app                               │
│  6 drawers · RGB LED · buzzer · 74HC595 shift register             │
│  Medication reminder: app triggers drawer + buzzer alarm           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 2 (IN PROGRESS)                                              │
│                                                                     │
│  MAX30102 ──I2C──► ESP8266 ──WiFi/HTTP──► FastAPI (Docker)        │
│  AD8232   ──ADC──►    │                       │                    │
│                        │              ┌────────┴─────────┐         │
│                        │              │ Signal Processor │         │
│                        │              │ ML Model (BP)    │         │
│                        │              └────────┬─────────┘         │
│                        │                       │                   │
│                        │              Firebase Firestore           │
│                        │                       │                   │
│                        └──────────────► Flutter App ◄─────────── │
│                                              │                     │
│                                     FCM NOTIFICATIONS ← CRITICAL  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Phase 1 — Medication Reminder Box (COMPLETE ✓)

**Hardware:** ESP32 controls 6 medication drawers.  
Each drawer has: RGB LED + buzzer + 74HC595 Shift Register.  
**Trigger flow:** Flutter app → Firebase RTDB → ESP32 → LED lights + buzzer alarm.  
**Status:** Fully working. No changes needed.

---

## 5. Phase 2 — Health Monitoring (IN PROGRESS)

### 5.1 Hardware in Use

| Device | Purpose |
|---|---|
| ESP8266-12E NodeMCU | WiFi microcontroller — reads sensors, sends to FastAPI |
| MAX30102 Pulse Oximeter | PPG signal → Heart Rate + SpO2 |
| AD8232 ECG Sensor | ECG signal → real-time waveform + features for BP model |

### 5.2 Wiring (CONFIRMED AND TESTED)

**MAX30102 → ESP8266 (I2C)**
| MAX30102 | ESP8266 NodeMCU | GPIO | Note |
|---|---|---|---|
| VIN | 3V3 | — | 3.3V only — never 5V |
| GND | GND | — | shared with AD8232 |
| SDA | D2 | GPIO4 | I2C data |
| SCL | D1 | GPIO5 | I2C clock |
| INT | — | — | leave unconnected for testing |

**AD8232 → ESP8266 (Analog)**
| AD8232 | ESP8266 NodeMCU | GPIO | Note |
|---|---|---|---|
| 3.3V | 3V3 | — | shared with MAX30102 |
| GND | GND | — | shared |
| OUTPUT | A0 | ADC0 | only analog pin on ESP8266 |
| SDN | D5 | GPIO14 | HIGH=on, LOW=sleep |
| LO+ | D6 | GPIO12 | lead-off detection (+) |
| LO− | D7 | GPIO13 | lead-off detection (−) |

**AD8232 Electrodes (IEC colours)**
- RA (Red) → upper right chest
- LA (Yellow) → upper left chest
- RL (Green) → lower left chest

### 5.3 Arduino Firmware (Combined — FINAL VERSION)

**Board:** NodeMCU 1.0 (ESP-12E Module) on COM4  
**Driver:** Silicon Labs CP210x USB to UART Bridge  
**Arduino IDE Board Manager URL:** `http://arduino.esp8266.com/stable/package_esp8266com_index.json`

**MAX30102 Library:** `MAX30105 by SparkFun Electronics`  
**MAX30102 setup:** `ppg.setup(60, 1, 2, 100, 411, 4096)` — sampleAverage=**1** (NOT 4) → 100 Hz output

**Data format sent over Serial / HTTP:**
```
ECG:512          ← raw ECG value 0-1023, sent at 100 Hz
LEADS:1          ← lead-off detection status (sent every 500ms)
BPM:72,SpO2:98   ← HR and SpO2 (sent every 1 second)
PAUSED / RESUMED ← control commands
```

**Commands received from Serial:**
- `s` → pause sampling
- `r` → resume sampling

**Key Arduino code pins:**
```cpp
#define ECG_PIN  A0
#define SDN_PIN  D5   // GPIO14
#define LO_PLUS  D6   // GPIO12
#define LO_MINUS D7   // GPIO13
```

### 5.4 Web Test Dashboard (health_monitor.html)

- Built with HTML + Web Serial API (Chrome/Edge only)
- Connects to ESP8266 via COM4 at 115200 baud
- Shows: real-time ECG waveform + BPM + SpO2 + ECG Leads status
- Waveform colour: green = leads OK, red = leads disconnected
- Pause/Resume button
- **This is a TEST tool only — not part of the final Flutter app**

### 5.5 ML Model Training

**Notebook:** `BP_Prediction_v4_final.ipynb` (on Kaggle)  
**Dataset:** mkachuee/BloodPressureDataset — MIMIC-II, 125 Hz, ECG + PPG + ABP

**Key preprocessing decisions:**
1. Resample 125 Hz → 100 Hz using `resample_poly(signal, 4, 5)` — matches sensor rate
2. Bandpass filters: PPG 0.5–8 Hz, ECG 0.5–40 Hz (at 125 Hz BEFORE resampling)
3. Per-window **z-score normalisation** — CRITICAL — makes training and sensor data same scale
4. Window: 800 samples = 8 seconds at 100 Hz, 50% overlap

**Model architecture:** TCN-Encoder → Bidirectional LSTM → Multi-Head Attention → Autoencoder regulariser  
**Targets:** SBP (systolic) and DBP (diastolic) in mmHg  
**Expected performance:** SBP MAE ≈ 1–2.5 mmHg, DBP MAE ≈ 0.9–1.5 mmHg  
**Clinical standards:** AAMI (MAE ≤ 5, SD ≤ 8), BHS Grade A/B

**Kaggle settings:**
- Accelerator: GPU T4 × 2
- MirroredStrategy(["GPU:0", "GPU:1"]) — both GPUs used
- Batch size: 64 global (32/GPU)
- Internet: ON
- Persistence: **Files only** (saves model + scalers + plots)

**Output files from Kaggle:**
- `bp_model_final.keras` — trained Keras model
- `scaler_features.pkl` — sklearn StandardScaler for features
- `scaler_targets.pkl` — sklearn StandardScaler for SBP/DBP targets
- `training_log.csv` — epoch-by-epoch history
- `*.png` — 7 visualisation figures

**Inference function (FastAPI-ready):**
```python
def predict_bp(ppg_raw_100hz, ecg_raw_100hz) -> dict:
    # Returns: {'sbp': 120.5, 'dbp': 78.2, 'hr': 72.0, 'ptt': 0.23, 'finger': True}
    # Input: 800 samples at 100 Hz from MAX30102 and AD8232
    # Applies: bandpass → z-score → feature extraction → model inference
```

---

## 6. ⚠️ MOST CRITICAL FEATURE: Real-Time Notifications

The entire project's clinical value depends on this. Without real-time alerts, the health monitoring is just display — not life-saving.

### 6.1 Notification Triggers (Thresholds)

| Condition | Threshold | Alert Message | Priority |
|---|---|---|---|
| High systolic BP | SBP > 140 mmHg | "High Blood Pressure — SBP {value}" | 🔴 HIGH |
| Very high systolic BP | SBP > 160 mmHg | "Hypertensive Crisis — Seek help now" | 🚨 CRITICAL |
| Low systolic BP | SBP < 90 mmHg | "Low Blood Pressure Detected" | 🔴 HIGH |
| High diastolic BP | DBP > 90 mmHg | "Elevated Diastolic Pressure" | 🟡 MEDIUM |
| Tachycardia | HR > 100 bpm | "Fast Heart Rate Detected ({value} bpm)" | 🟡 MEDIUM |
| Bradycardia | HR < 50 bpm | "Slow Heart Rate Detected ({value} bpm)" | 🟡 MEDIUM |
| Low SpO2 | SpO2 < 94% | "Low Oxygen Saturation ({value}%)" | 🔴 HIGH |
| Critical SpO2 | SpO2 < 90% | "Critical: Seek emergency help" | 🚨 CRITICAL |

### 6.2 Notification Flow

```
ESP8266 (sensor data)
    │
    ▼ HTTP POST every 8 seconds
FastAPI /health/submit endpoint
    │
    ▼ 1. Run ML model → predict SBP, DBP
    │  2. Check all thresholds
    │  3. Save to Firebase Firestore
    │
    ├── If threshold exceeded:
    │       ▼
    │   Firebase Admin SDK → FCM
    │       ▼
    │   Flutter app receives push notification
    │   (even when app is in background/closed)
    │
    └── Always:
            ▼
        Firebase Firestore → Flutter real-time listener
        Flutter updates ECG chart + vitals display
```

### 6.3 FastAPI Endpoints Needed

```python
POST /health/submit          # ESP8266 sends raw sensor data
GET  /health/latest          # Flutter polls for latest reading
GET  /health/history/{days}  # History for charts
WS   /health/stream          # WebSocket for real-time ECG waveform
POST /notifications/test     # Test FCM notification
```

### 6.4 Flutter Packages for Notifications

```yaml
# pubspec.yaml additions needed:
firebase_messaging: ^14.x.x    # FCM push notifications
flutter_local_notifications: ^16.x.x  # Show notification UI
```

**Flutter notification setup:**
```dart
// Request permission
FirebaseMessaging.instance.requestPermission(alert: true, sound: true);

// Handle foreground notifications
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Show local notification
  // Update vitals display if relevant
});

// Handle background/terminated notifications
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

### 6.5 FastAPI FCM Code (needs firebase-admin package)

```python
import firebase_admin
from firebase_admin import credentials, messaging

def send_health_alert(fcm_token: str, title: str, body: str, data: dict):
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in data.items()},
        token=fcm_token,
    )
    messaging.send(message)
```

---

## 7. Next Steps — Priority Order

### Step 1 — Wait for Kaggle training to finish (no action needed)
- Session runs ~2-3 hours
- Download: `bp_model_final.keras`, `scaler_features.pkl`, `scaler_targets.pkl`
- Check: SBP MAE and DBP MAE from evaluation output

### Step 2 — FastAPI: Build the health prediction endpoint
- Load the Keras model + scalers on startup
- POST `/health/submit` endpoint receives raw PPG + ECG arrays
- Run `predict_bp()` function → SBP, DBP, HR
- Save result to Firebase Firestore

### Step 3 — FastAPI: Add notification logic
- After every prediction, check all thresholds
- If exceeded → call Firebase Admin SDK → send FCM
- Add cooldown: don't repeat same alert within 5 minutes

### Step 4 — FastAPI: WebSocket for real-time ECG
- `WS /health/stream` endpoint
- ESP8266 connects, streams ECG values at 100 Hz
- FastAPI rebroadcasts to connected Flutter clients

### Step 5 — Flutter: Health monitoring screen
- Real-time ECG chart (line chart, scrolling, 100 Hz)
- Vitals cards: SBP · DBP · HR · SpO2
- Leads status indicator (green/red)
- History chart (last 24 hours)

### Step 6 — Flutter: Notifications integration
- Request FCM permission on first launch
- Store FCM token in Firestore under user profile
- Handle notification tap → navigate to health screen
- Show badge/colour on vitals card when alert is active
- **Test on real device — NOT just emulator (FCM requires real device)**

### Step 7 — ESP8266: Update firmware for HTTP POST
- Change from Serial output to HTTP POST to FastAPI
- POST body: `{"ppg": [...800 values...], "ecg": [...800 values...]}`
- Headers: `Authorization: Bearer <firebase_token>`
- Retry on failure (WiFi drop handling)

### Step 8 — Integration testing with real hardware
- End-to-end test: finger on sensor → notification on phone
- Measure end-to-end latency target: < 10 seconds
- Test all alert types

---

## 8. Flutter Screens Plan

| Screen | Status | Description |
|---|---|---|
| Login / Register | Existing | Firebase Auth |
| Home / Dashboard | Existing | Overview of all features |
| Medication Box | Complete ✓ | 6 drawers, alarms |
| **Health Monitor** | To build | Real-time ECG + vitals |
| **Health History** | To build | BP/HR trends over time |
| **Notifications** | To build | Alert log + settings |
| Settings | Existing | Profile, preferences |

---

## 9. Firebase Firestore Schema

```
/users/{uid}/
  /health_readings/{timestamp}/
    sbp: 120.5
    dbp: 78.2
    hr: 72.0
    spo2: 98.0
    ptt: 0.23
    timestamp: Timestamp
    alert_triggered: false
  /fcm_token: "device_token_string"
  /alert_settings/
    sbp_high_threshold: 140
    sbp_low_threshold: 90
    hr_high_threshold: 100
    hr_low_threshold: 50
    spo2_low_threshold: 94
```

---

## 10. Known Issues and Solutions Applied

| Issue | Solution Applied |
|---|---|
| Kernel crash during training | MirroredStrategy + tf.data + BATCH_SIZE=64 + MAX_EPOCHS=80 |
| Scale mismatch sensor vs training | Per-window z-score normalisation in both training and inference |
| MAX30102 only 25 Hz output | Changed sampleAverage=1 → 100 Hz output |
| Sample rate mismatch (125 vs 100) | resample_poly(signal, 4, 5) before window extraction |
| COM4 busy error in Arduino IDE | Disconnect Web Serial dashboard before uploading |
| ESP8266 CP2102 driver missing | Silicon Labs CP210x driver (not CH340) |

---

## 11. Repository / File Structure

```
smart_box/
├── firmware/
│   ├── phase1_esp32/          # COMPLETE — medication box
│   └── phase2_esp8266/
│       └── combined_sensors.ino  # MAX30102 + AD8232 combined
├── ml/
│   └── BP_Prediction_v4_final.ipynb   # Kaggle notebook (training)
├── backend/
│   └── (FastAPI — to be built in Step 2)
├── flutter/
│   └── (existing app — health screen to be added in Step 5)
└── tools/
    └── health_monitor.html     # Web Serial test dashboard (Chrome only)
```

---

## 12. Important Technical Notes for Next AI

1. **Do NOT change sampleAverage in MAX30102 back to 4** — must stay at 1 for 100 Hz
2. **Z-score normalisation is mandatory** at inference time — see `predict_bp()` function
3. **The model expects (1, 800, 2) input** — stack PPG and ECG: `np.stack([ppg_n, ecg_n], axis=-1)`
4. **FCM needs real device** for testing — emulator won't receive FCM notifications
5. **WebSocket for ECG** — don't use HTTP polling for ECG (too slow); use WS for real-time waveform
6. **Notification cooldown** — implement in FastAPI to avoid notification spam (5-min cooldown per alert type)
7. **The dataset is ICU patients** — model trained on MIMIC-II which has unusual BP ranges; may need subject-specific calibration for healthy users in production
8. **ESP8266 has only ONE analog pin (A0)** — AD8232 uses it; MAX30102 uses I2C — no conflict
9. **T4 × 2 MirroredStrategy** — if retraining, always explicitly pass ["GPU:0", "GPU:1"]

