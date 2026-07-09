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

The backend, Flutter app, and both IoT devices communicate over plain HTTP on
a shared Wi-Fi network, with IP addresses hardcoded in source rather than
resolved dynamically. If the network changes, update all of the following:

| Component | File | Value |
|---|---|---|
| Backend API base URL | `Front-end/health_mate_app/lib/core/constants/api_constants.dart` | `devBaseUrl` |
| Smart-box ESP32 IP (frontend) | `Front-end/health_mate_app/lib/core/constants/iot_constants.dart` | `esp32BaseUrl` |
| Smart-box ESP32 IP (backend) | `Back-end/app/core/config.py` | `esp32_local_ip` |
| BP-unit backend target (firmware) | `bp-hardware-code/bp-hardware-code.ino` | `serverUrl` |

See `ARCHITECTURE.md` §6 for the full deployment picture.

## Running the project locally

### 1. Backend

Requires Docker Desktop.

```bash
cd Back-end
# verify .env exists (already provided in the repo)
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
