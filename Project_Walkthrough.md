# 🏥 Health Mate Project Walkthrough

This guide provides a step-by-step walkthrough for setting up, running, and testing the Health Mate system. It covers the Backend, Frontend, and optional external integrations (Cloudflare, Firebase, WebRTC).

---

## 🏗️ 1. Environment Setup

### 🔧 Backend (FastAPI + PostgreSQL + Redis)
The backend is the core of the system. It can run locally or with external cloud services.

1.  **Navigate**: `cd Back-end/`
2.  **Environment Variables**:
    -   Copy `.env.example` to `.env`.
    -   Update the following for basic local operation:
        ```ini
        DATABASE_URL=postgresql://healthmate:healthmate123@db:5432/healthmate_db
        REDIS_URL=redis://redis:6379/0
        IOT_MODE=mock  # Use 'mock' for testing without hardware
        ```
3.  **Start Services**:
    ```bash
    docker-compose up -d --build
    ```
4.  **Verify**:
    -   Health Check: [http://localhost:8000/health](http://localhost:8000/health)
    -   API Docs: [http://localhost:8000/docs](http://localhost:8000/docs)

### ☁️ External Integrations (Optional)
If you wish to enable advanced features like Image Storage, Push Notifications, or Video Calls, configure the following in `Back-end/.env`:

| Service | Stats | Env Variables Needed | Purpose |
| :--- | :--- | :--- | :--- |
| **Cloudflare** | Optional | `CLOUDFLARE_ACCOUNT_ID`<br>`CLOUDFLARE_API_TOKEN` | Secure image storage for medications/profiles. |
| **Firebase** | Optional | `FIREBASE_PROJECT_ID`<br>`FIREBASE_PRIVATE_KEY` | Push notifications for alarms/alerts. |
| **WebRTC** | Optional | `TURN_SERVER_URL`<br>`TURN_USERNAME`<br>`TURN_PASSWORD` | Reliable video calls over the internet. |

> **Note**: For local testing without these keys, the system will use local fallbacks or mock implementations where possible.

---

### 📱 Frontend (Flutter)
The mobile application for Patients and Caregivers.

1.  **Navigate**: `cd Front-end/health_mate_app/`
2.  **Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Configuration**:
    -   Ensure `lib/core/constants/api_constants.dart` points to your backend (default is localhost).
4.  **Run**:
    -   For Web (easiest for testing):
        ```bash
        flutter run -d chrome
        ```
    -   For Mobile (requires Emulator/Device):
        ```bash
        flutter run
        ```

---

## 🧪 2. Full-Cycle Testing Flow

### A. Authentication & Localization
1.  **Settings**: On the login screen or inside the app, go to Settings.
    -   Toggle **Language** (English/Arabic) to verify the new localization constants.
    -   Observe that all strings update instantly.
2.  **Register**: Create a **Patient** account.
3.  **Login**: Access the dashboard.

### B. Medications & Alarms (New Features)
1.  **Add Medication**:
    -   Go to the **Medications** tab.
    -   Tap **+ Add Medication**.
    -   Fille details: Name "Aspirin", Dosage "500mg".
    -   **Image**: Tap the camera icon to pick an image (uses Cloudflare or Local upload).
    -   **Smart Box**: Select "Drawer 1", Enable LED/Buzzer.
    -   Save.
2.  **Test Alarm**:
    -   On the Medications list, tap the **"Demo Alarm"** button (top right).
    -   **Verify UI**: 
        -   Full-screen alarm page appears.
        -   Colors match the theme (`AppColors`).
        -   Medication details and image are correct.
    -   **Action**: Tap **"Take Now"**.
        -   Snackbar confirms "Medication Confirmed" (Localized).
        -   Backend receives IoT deactivation signal (check Docker logs).

### C. Vitals Tracking
1.  **Add Reading**: Tap "+" on the BP card.
2.  **History**: Tap the card to view `BPHistoryPage`.
3.  **Details**: Tap any reading in the history list.
    -   **Verify UI**: `BPDetailPage` opens with localized "High/Normal" status and health tips.

### D. Caregiver Linking
1.  **Patient**: Settings -> QR Code.
2.  **Caregiver**: Login as caregiver -> Scan QR (or use mock linking if on simulator).
3.  **Verify**: Caregiver sees the Patient's vitals and medication status.

---

## 🛠️ 3. Verification Checklist

| Feature | Status | How to Verify |
| :--- | :--- | :--- |
| **Backend API** | ✅ Ready | `http://localhost:8000/docs` covers all endpoints. |
| **Medication Alarm** | ✅ Ready | Use "Demo Alarm" button in app. |
| **Localization** | ✅ Ready | Switch languages; no hardcoded strings visible. |
| **Theming** | ✅ Ready | Consistent colors (`AppColors`) across all screens. |
| **External APIs** | ⚠️ Config | Check `.env` for Cloudflare/Firebase keys if needed. |

---

## 📝 4. Troubleshooting

-   **"Connection Refused"**: Ensure the backend is running and `api_constants.dart` uses the correct IP (use `10.0.2.2` for Android Emulator, `localhost` for iOS/Web).
-   **Image Upload Fails**: If Cloudflare keys are missing, ensure the backend is configured to allow local uploads or mocked storage.
-   **Build Errors**: Run `flutter clean` then `flutter pub get`.

---
**Happy Testing!** 🚀
