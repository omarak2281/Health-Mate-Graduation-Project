# Health Mate

Health Mate is a remote patient-monitoring system for chronic cardiovascular
conditions, built around three parts: a Flutter mobile app for patients and
linked caregivers, a FastAPI backend, and two custom IoT devices (a cuffless
blood-pressure sensing unit and a smart medicine box). Two purpose-built AI
models are integrated into the backend: a deep learning model that estimates
blood pressure from PPG/ECG signals, and a symptom/disease triage system.

This README is a short orientation. Deeper, source-verified documentation
lives in the files listed in [Documentation](#documentation) below — each one
is built directly from the code, not from product notes, and each says so
plainly where something is only partially built or has a known gap.

## What's actually in this repository

- **`Back-end/`** — FastAPI backend: authentication, vitals, medications,
  notifications, calling, IoT integration, and both AI models. See
  `ARCHITECTURE.md` and `BACKEND.md`.
- **`Front-end/health_mate_app/`** — Flutter app (Riverpod, Dio, Hive,
  `easy_localization` for full Arabic/English support). See `FRONTEND.md`.
- **`Predict-ABP/1_BP_Prediction_v6_Final/`** — the blood-pressure model's
  training notebook and evaluation artifacts. See `BP_PREDICTION.md`.
- **`Symptom-Checker/`** — the symptom/disease triage model(s), training
  scripts, and taxonomy data. See `SYMPTOM_CHECKER.md`.
- **`bp-hardware-code/`** and **`smart-box-hardware-code/`** — firmware for
  the two IoT devices. See `IOT.md`.

## A note on accuracy

An earlier version of this README described the AI stack as "MLP / XGBoost /
LSTM" with a blanket "90.3% accuracy" figure and a "QR-code encrypted
handshake" for caregiver linking. Those descriptions do not match the current
code: the best-performing BP model is a 1D-CNN (not an LSTM), the production
symptom-checker model is LightGBM over structured features (an older
TF-IDF/MLP-style model still runs in parallel, not in its place), and the
caregiver-linking QR code carries a plain, unencrypted user ID. The documents
below reflect what the code actually does, including where results fall short
of that older description — see `BP_PREDICTION.md` §8 and
`SYMPTOM_CHECKER.md` §4 for both models' real, measured accuracy.

## Documentation

| Document | Covers |
|---|---|
| `PRD.md` | Product vision, objectives, requirements, business rules, known risks |
| `ARCHITECTURE.md` | System architecture, deployment topology, backend/frontend structure |
| `DATABASE.md` | Full schema, ER diagram, and real findings from the models |
| `BACKEND.md` | Auth, API layer, services, testing, and honest gaps found in the backend |
| `FRONTEND.md` | Flutter app structure, screens, state management, real gaps |
| `API_DOCUMENTATION.md` | Endpoint-by-endpoint reference with real request/response schemas |
| `BP_PREDICTION.md` | Blood-pressure model: data, training, results, calibration, limitations |
| `SYMPTOM_CHECKER.md` | Both symptom-checker generations, dataset, results, rule engine |
| `IOT.md` | Both hardware devices, firmware behavior, and what they don't do |
| `DOCUMENTATION_NOTES.md` | How this documentation set was produced and verified |

## Networking configuration

The backend, Flutter app, and both IoT devices all talk over plain HTTP on a
shared Wi-Fi network — no domain name, no HTTPS, no service discovery. Every
component that needs to reach another one has that other one's LAN IP
hardcoded in source. This is the single most common reason the app "doesn't
work" for a new team member, so here is exactly what talks to what, with the
IPs currently committed as a worked example.

### Who calls whom

```
                 same Wi-Fi network
┌──────────────┐   http://<backend-IP>:8000/api/v1   ┌──────────────┐
│  Flutter app │ ───────────────────────────────────▶│   Backend    │
│ (phone/emu)  │◀─────────────────────────────────── │ (Docker, PC) │
└──────────────┘         JSON responses               └──────┬───────┘
       │                                                      │
       │ http://<esp32-IP>/activate                           │ (backend also
       ▼                                                      │  polls/receives
┌──────────────┐                                              │  from devices)
│ Smart-box    │                                               ▼
│ ESP32        │                                        ┌──────────────┐
└──────────────┘   http://<backend-IP>:8000/api/v1/...  │  BP unit     │
                    (device pushes readings directly) ◀──│  (ESP32/ESP8266)│
                                                          └──────────────┘
```

- The **Flutter app** never talks to the IoT devices' backend endpoint
  directly for BP submission — the BP unit pushes straight to the backend.
  The app *does* call the smart-box ESP32 directly (to open/close drawers).
- The **backend binds `0.0.0.0:8000`** inside the Docker container (see
  `command: uvicorn app.main:app --host 0.0.0.0 --port 8000` in
  `docker-compose.yml`) and `docker-compose.yml` maps `8000:8000` to the
  host. That means once `docker-compose up` is running, the backend is
  already reachable from any other device on the same Wi-Fi at
  `http://<host-machine's-LAN-IP>:8000` — nothing to configure on the
  backend side itself.

### Worked example — what's committed right now

The repo currently has one developer's machine (`10.229.183.149`) and one
ESP32 device (`10.229.183.78`) hardcoded as the example values:

| Component | File | Current value | What it means |
|---|---|---|---|
| Backend API base URL | `Front-end/health_mate_app/lib/core/constants/api_constants.dart` (`devBaseUrl`, line ~21) | `http://10.229.183.149:8000/api/v1` | The Flutter app will try to reach the backend at this exact IP. If your laptop running Docker has a different LAN IP, every API call from the app fails silently or times out until you change this. |
| Smart-box ESP32 IP (frontend) | `Front-end/health_mate_app/lib/core/constants/iot_constants.dart` (`esp32BaseUrl`) | `http://10.229.183.78` | The app uses this to send drawer open/close commands directly to the smart-box hardware. |
| Smart-box ESP32 IP (backend) | `Back-end/app/core/config.py` (`esp32_local_ip`) | `10.229.183.78` | The backend also needs the smart-box's IP for server-initiated actions (reminders, etc). Must match the value above. |
| BP-unit backend target (firmware) | `bp-hardware-code/bp-hardware-code.ino` (`serverUrl`, line 10) | `http://10.229.183.149:8000/api/v1/vitals/bp/submit` | Baked into the ESP32/ESP8266 firmware at flash time — this is where the BP unit pushes readings. Must point at whoever is running the backend. |

### What you actually need to change to test on your own phone

1. **Find the LAN IP of the machine running `docker-compose up`** (not the
   phone). On Windows: `ipconfig` → look for the Wi-Fi adapter's IPv4
   address (e.g. `192.168.1.23`). It must be on the **same Wi-Fi network**
   the phone will use.
2. Update `devBaseUrl` in `api_constants.dart` to
   `http://<that-IP>:8000/api/v1`, replacing `10.229.183.149`.
3. Rebuild/hot-restart the Flutter app (a plain hot-reload won't pick up a
   `const` change).
4. You do **not** need to touch the backend, Docker, or `.env` for this —
   the backend already listens on `0.0.0.0:8000`, so it accepts connections
   from any device on the LAN as soon as it's running.
5. Only touch `iot_constants.dart` / `config.py` / the `.ino` files if
   you're also testing with the physical IoT hardware — for pure app +
   backend testing without the hardware, these two files are irrelevant.

Two gotchas that look like network bugs but aren't:
- **Phone on mobile data / a different Wi-Fi than the PC** → nothing will
  ever connect; there's no public tunnel. Phone and backend machine must be
  on the same network.
- **Windows Firewall blocking inbound port 8000** → the backend runs fine
  locally (`localhost:8000/docs` works) but other devices on the LAN get
  connection refused/timeout. Allow inbound TCP 8000 for Docker/the
  relevant process if this happens.

See `ARCHITECTURE.md` §6 for the full deployment picture.

## Firebase service account key

`Back-end/serviceAccountKey.json` is **not committed to git** and is listed
in `.gitignore`. This is deliberate: an earlier commit that included a real
copy of this file was auto-revoked by Google within minutes of being pushed
to GitHub — GitHub's secret scanning reports any recognized GCP service
account key to Google the moment it appears in a push, even on a private
repo and even if push protection is manually overridden, and Google
disables the key automatically as a security measure. There is no way to
keep a real key committed to git without it getting killed again.

Each team member who needs to run the backend must fetch their own copy:

1. Go to the [Firebase Console](https://console.firebase.google.com/) →
   select the `healt-mate-44e8b` project.
2. **Project Settings** (gear icon) → **Service Accounts** tab.
3. Click **Generate new private key** → confirm. A `.json` file downloads.
4. Rename it to `serviceAccountKey.json` and place it at
   `Back-end/serviceAccountKey.json` (same folder as `docker-compose.yml`).
5. That's it — `docker-compose.yml` already mounts this exact path into the
   container, and `.env` already points Firebase Admin SDK config at it.
   No other file needs to change.

If you don't have access to the Firebase project, ask the project owner to
add you as a member under **Project Settings → Users and permissions**, or
to send you a key file directly over a private channel (not git, not
Slack/WhatsApp in a public/shared channel).

## Running the project locally

### 1. Backend

Requires Docker Desktop.

```bash
cd Back-end
# verify .env exists (already provided in the repo)
# verify Back-end/serviceAccountKey.json exists — see "Firebase service
# account key" above if it doesn't
docker-compose up -d --build
```

Verify at `http://localhost:8000/docs` — the Swagger UI should load.

### 2. AI model artifacts

Both models' trained artifacts are already committed to the repository, so
no training step is required to run the app:

- Symptom checker: `Symptom-Checker/Output/Production/` (`best_model.pkl` +
  `vectorizer.pkl` for the legacy flow, `best_model_v2.pkl` +
  `label_encoder_v2.pkl` for the structured flow).
- Blood pressure model: `Back-end/app/services/models/` (`bp_model_final.keras`,
  `scaler_features.pkl`, `scaler_targets.pkl`).

To retrain the symptom checker's structured (v2) model:

```bash
cd Symptom-Checker
pip install -r requirements.txt
python training/train_final.py
```

Retraining the BP model requires running the notebook at
`Predict-ABP/1_BP_Prediction_v6_Final/BP_Prediction_v6_Final.ipynb` (GPU
recommended — the original run used a dual-T4 Kaggle session).

### 3. Flutter app

```bash
cd Front-end/health_mate_app
flutter pub get
```

If running on a physical device, update `devBaseUrl` in
`lib/core/constants/api_constants.dart` to your machine's current LAN IP, and
ensure the phone is on the same Wi-Fi network as the backend.

```bash
flutter run
```

## Contact

Omar Ashraf — omarak2281@gmail.com
Saif Eldeen Amr — saifeldeenamr10@gmail.com

Graduation Project, Zagazig University, Faculty of Computers and
Informatics, Artificial Intelligence and Data Science Program, 2025–2026.
