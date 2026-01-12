# 🏥 Health Mate: Medical-Grade Healthcare Monitoring System

![Project Status](https://img.shields.io/badge/Status-71%25%20Complete-green.svg?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Frontend-Flutter%203.19%2B-blue.svg?style=for-the-badge&logo=flutter)
![FastAPI](https://img.shields.io/badge/Backend-FastAPI-teal.svg?style=for-the-badge&logo=fastapi)
![AI/ML](https://img.shields.io/badge/AI-MLP%20%2F%20XGBoost%20%2F%20LSTM-orange.svg?style=for-the-badge)
![Docker](https://img.shields.io/badge/Cloud-Docker%20%2F%20Redis-blue.svg?style=for-the-badge&logo=docker)

---

## 🌟 Project Overview
**Health Mate** is an integrated medical software ecosystem designed as a graduation project to demonstrate the power of AI and mobile technology in healthcare. It provides a multi-layered solution for **Patients** tracking chronic conditions and **Caregivers** monitoring them remotely. The system features a highly responsive Flutter app, a high-performance backend, and dedicated AI engines for symptom analysis and vital sign prediction.

---

## 🏛️ System Architecture

### 📱 1. Flutter Mobile Client (Professional Grade)
The frontend is built using **Clean Architecture** principles, ensuring high maintainability and testability.
-   **State Management**: Optimized with **Riverpod** for robust data flow.
-   **Localization Engine**: 100% Arabic & English support with automatic **RTL (Right-to-Left)** layout inversion using `EasyLocalization`.
-   **Storage Persistence**:
    -   `FlutterSecureStorage`: Encrypted storage for JWT and biometric tokens.
    -   `Hive DB`: NoSQL local database for high-volume vitals and medication logs.
    -   `SharedPrefs`: User preferences and app-wide flags.
-   **Network**: Custom `Dio` interceptors for automatic JWT token refreshing and request logging.

### ⚡ 2. FastAPI Backend & IoT Bridge
A containerized Python ecosystem providing the core logic and real-time connectivity.
-   **Async Core**: Built on **FastAPI** for non-blocking I/O, vital for real-time health data telemetry.
-   **Database Layer**: **PostgreSQL** for relational data (Users, Vitals, Meds) with **Alembic** migrations.
-   **Caching Layer**: **Redis** for session management and real-time vital sign temporary caching.
-   **Security**: Professional-grade JWT implementation with **OAuth2 Password Grant Flow**.
-   **IoT Service**: A built-in "Mocker" that simulates:
    -   **PPG/ECG Sensors**: Generating realistic cardiac telemetry.
    -   **Smart Medicine Box**: Control signals for physical hardware drawers (Simulated via API).

### 🧠 3. AI Predictive Engines
The system incorporates three distinct AI modeling approaches:
-   **Symptom Checker (Neural Network)**: Uses a **Standard MLP** model (scikit-learn) with **TF-IDF Vectorization** to predict diseases from free-text or selected symptoms with **90.3% accuracy**.
-   **ABP Predictor (LSTM)**: Long Short-Term Memory neural network designed to analyze time-series BP data to predict future spikes.
-   **Report Generator**: An automated clinical reporting engine that translates AI results into professional PDFs with Arabic RTL support.

---

## 🚀 Technical Innovation Features

-   **Offline-First Sync**: Patients can log readings in the desert; the app caches data and syncs automatically when a signal is found.
-   **Smart Linking Engine**: Caregivers link to patients via **QR-code encrypted handshakes**, enabling instant data access.
-   **Critical Threshold Alerts**: Backend "Notification Service" monitors BP readings and triggers priority Firebase alerts if a hypertensive crisis is detected.
-   **UI Aesthetics**: Premium design system featuring Vibrant Teal medical colors, Tajawal typography, and interactive SVG animations.

---

## 📂 Repository Structure

```bash
Health_Mate_v4/
├── Back-end/                # FastAPI, Docker, and IoT Mock Logic
├── Front-end/
│   └── health_mate_app/     # Flutter Cross-Platform Application
├── Predict-ABP/             # LSTM Blood Pressure Prediction Models
└── Symptom-Checker/         # MLP Diagnostic Model Training & Deployment
```

---

## 🚦 Installation & Execution Guide (Step-by-Step)

Follow these steps exactly in the order listed below to ensure a successful local deployment.

### 1️⃣ Step 1: Backend & Database Deployment
You must have **Docker Desktop** installed and running on your PC.

1.  **Open Terminal** in the project root.
2.  Navigate to the backend:
    ```bash
    cd Back-end
    ```
3.  Load environment variables: (Already provided in the repo)
    ```bash
    # Verify .env exists in the Back-end folder
    ```
4.  **Build & Run with Docker**:
    ```bash
    docker-compose up -d --build
    ```
5.  **Verify**: Open your browser to [http://localhost:8000/docs](http://localhost:8000/docs). If the Swagger UI loads, the backend is correct.

---

### 2️⃣ Step 2: AI Model Status (Pre-Bundled)
For your convenience, the trained AI models (`best_model.pkl` and `vectorizer.pkl`) are **already included** in the repository. Your team does **not** need to train them to run the project.

-   If you wish to retrain or update the models:
    ```bash
    cd ../Symptom-Checker
    pip install -r requirements.txt
    python train_model.py
    ```
-   The backend will automatically detect and load these models from the `Symptom-Checker/Output/Production/` directory.

---

### 3️⃣ Step 3: Flutter Application Setup
Ensure you have the latest **Flutter SDK** and **Android Studio / Xcode**.

1.  Navigate to the Flutter project:
    ```bash
    cd ../Front-end/health_mate_app
    ```
2.  Get Packages:
    ```bash
    flutter pub get
    ```
3.  **⚠️ CONFIGURATION FOR EXTERNAL PHONE (IMPORTANT)**:
    If you are running the app on a **Real Physical Phone**, update the IP address inside the code:
    -   Open `lib/core/constants/api_constants.dart`.
    -   Find your computer's IP (type `ipconfig` in CMD, look for `IPv4 Address`).
    -   Change `devBaseUrl` to: `return 'http://YOUR_LOCAL_IP:8000/api/v1';`.
4.  **Pairing**: Ensure your PC and Phone are on the **Same Wi-Fi Network**.

---

### 4️⃣ Step 4: Launching the App
1.  Connect your device or start an emulator.
2.  Run the app:
    ```bash
    flutter run
    ```

---

## 👨‍💻 Developed By
**Omar Ashraf**  
*Graduation Project - 2026*  
Contact: omarak2281@gmail.com

---
🚀 **Health Mate** - *Your Life, Our Mission.*
