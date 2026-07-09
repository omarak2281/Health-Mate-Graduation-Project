import os
import json
import numpy as np
import scipy.signal
from scipy.stats import skew, kurtosis
import joblib
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# -------------------------------------------------------------
# Configuration and Standalone Model Loading
# -------------------------------------------------------------
# We load the model and scalers directly from the Predict-ABP deliverables folder
WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(WORKSPACE_DIR, "Predict-ABP", "1_BP_Prediction_v6_Final", "BP_Deliverables", "model_artifacts")
MODEL_PATH = os.path.join(MODEL_DIR, "bp_model_final.keras")
SCALER_X_PATH = os.path.join(MODEL_DIR, "scaler_features.pkl")
SCALER_Y_PATH = os.path.join(MODEL_DIR, "scaler_targets.pkl")

CALIBRATION_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_calibration.json")

FS = 100
WINDOW_SIZE = 800
HR_MAX = 180.0
HR_MIN = 40.0

# -------------------------------------------------------------
# Signal Preprocessing and Feature Extraction
# -------------------------------------------------------------
def bandpass(sig: np.ndarray, lo: float, hi: float, fs: float, order: int = 4) -> np.ndarray:
    """Butterworth bandpass filter"""
    nyq = 0.5 * fs
    b, a = scipy.signal.butter(order, [max(lo / nyq, 1e-5), min(hi / nyq, 0.9999)], btype='band')
    return scipy.signal.filtfilt(b, a, sig).astype(np.float32)

def normalize_wave(sig: np.ndarray) -> np.ndarray:
    """Z-score normalization"""
    return ((sig - sig.mean()) / (sig.std() + 1e-8)).astype(np.float32)

def extract_features(ppg_w: np.ndarray, ecg_w: np.ndarray) -> np.ndarray:
    """Extract 21 physiological features matching the model definition"""
    feats = np.zeros(21, np.float32)
    min_d = int(FS * 60 / HR_MAX)
    eps = 1e-8
    
    pks, _ = scipy.signal.find_peaks(ppg_w, distance=min_d, prominence=0.2)
    trs, _ = scipy.signal.find_peaks(-ppg_w, distance=min_d, prominence=0.2)
    rpks, _ = scipy.signal.find_peaks(ecg_w, distance=min_d, prominence=0.5)
    
    # 0, 1, 2: Heart rate and RR from PPG
    if len(pks) >= 2:
        rr = np.diff(pks) / FS
        feats[0] = 60 / (rr.mean() + eps)
        feats[1] = rr.mean()
        feats[2] = rr.std()
        
    # 3, 4: Pulse transit time (PTT)
    ptts = [(pks[pks > rp][0] - rp) / FS for rp in rpks if len(pks[pks > rp])]
    if ptts:
        feats[3] = np.mean(ptts)
        feats[4] = np.std(ptts)
        
    # 5: PPG rise time
    rise = [(p - trs[trs < p][-1]) / FS for p in pks if len(trs[trs < p])]
    feats[5] = np.mean(rise) if rise else 0.0
    
    # 6, 7: PPG amplitude mean and std
    amps = [ppg_w[p] - ppg_w[trs[trs < p][-1]] for p in pks if len(trs[trs < p])]
    if amps:
        feats[6] = np.mean(amps)
        feats[7] = np.std(amps)
        
    # 8, 9, 10, 11: PPG basic statistics
    feats[8] = ppg_w.mean()
    feats[9] = ppg_w.std()
    feats[10] = float(skew(ppg_w))
    feats[11] = float(kurtosis(ppg_w))
    
    # 12, 13: Velocity VPG
    vpg = np.diff(ppg_w)
    feats[12] = vpg.mean()
    feats[13] = vpg.std()
    
    # 14, 15: Acceleration APG
    apg = np.diff(vpg)
    feats[14] = apg.mean()
    feats[15] = apg.std()
    
    # 16, 17: ECG heart rate and RR
    if len(rpks) >= 2:
        rre = np.diff(rpks) / FS
        feats[16] = rre.mean()
        feats[17] = rre.std()
        
    # 18: ECG QRS width
    qrs = [(min(len(ecg_w), rp + int(0.06 * FS)) - max(0, rp - int(0.06 * FS))) for rp in rpks]
    feats[18] = np.mean(qrs) / FS if qrs else 0.0
    
    # 19, 20: ECG basic statistics
    feats[19] = ecg_w.mean()
    feats[20] = ecg_w.std()
    
    # Clean NaNs and infs
    feats[~np.isfinite(feats)] = 0.0
    return feats

# -------------------------------------------------------------
# Standalone Model Server
# -------------------------------------------------------------
app = FastAPI(title="Standalone BP Hardware and Model Test Bench Server")

# Allow CORS for direct HTML file opening
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global State: In-Memory cache for the latest measurement and heartbeat
class LiveState:
    def __init__(self):
        self.latest_ppg = []
        self.latest_ecg = []
        self.raw_sbp = None
        self.raw_dbp = None
        self.cal_sbp = None
        self.cal_dbp = None
        self.heart_rate = None
        self.ptt = None
        self.leads_connected = False
        self.finger_detected = False
        self.last_seen = None
        self.status = "No data received yet"

state = LiveState()

# Load Model Lazy Wrapper
class ModelManager:
    def __init__(self):
        self.model = None
        self.sc_x = None
        self.sc_y = None
        self.loaded = False
        self.error = None

    def ensure_loaded(self):
        if self.loaded:
            return True
        try:
            if not os.path.exists(MODEL_PATH):
                raise FileNotFoundError(f"Model file not found at: {MODEL_PATH}")
            if not os.path.exists(SCALER_X_PATH) or not os.path.exists(SCALER_Y_PATH):
                raise FileNotFoundError("Scaler pkl files not found.")
            
            import tensorflow as tf
            self.model = tf.keras.models.load_model(MODEL_PATH)
            self.sc_x = joblib.load(SCALER_X_PATH)
            self.sc_y = joblib.load(SCALER_Y_PATH)
            self.loaded = True
            self.error = None
            print("Keras model and scalers loaded successfully!")
            return True
        except Exception as e:
            self.error = str(e)
            print(f"Failed to load Keras model: {e}")
            return False

model_manager = ModelManager()

# -------------------------------------------------------------
# Calibration Storage & Formulas (Strictly Standalone)
# -------------------------------------------------------------
def load_calibration_config() -> Dict:
    if os.path.exists(CALIBRATION_FILE):
        try:
            with open(CALIBRATION_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "status": "not_calibrated",
        "samples_count": 0,
        "sbp_scale": 1.0,
        "sbp_offset": 0.0,
        "dbp_scale": 1.0,
        "dbp_offset": 0.0,
        "samples": []
    }

def save_calibration_config(cfg: Dict):
    with open(CALIBRATION_FILE, "w") as f:
        json.dump(cfg, f, indent=4)

def calculate_offset_fit(cfg: Dict) -> Dict:
    samples = cfg.get("samples", [])
    n = len(samples)
    cfg["samples_count"] = n
    
    if n == 0:
        cfg["status"] = "not_calibrated"
        cfg["sbp_scale"] = 1.0
        cfg["sbp_offset"] = 0.0
        cfg["dbp_scale"] = 1.0
        cfg["dbp_offset"] = 0.0
        return cfg
        
    # Implement clean additive/regression calibration directly
    if n < 8:
        # Additive (median offset)
        sbp_diffs = [s["cuff_sbp"] - s["model_sbp"] for s in samples]
        dbp_diffs = [s["cuff_dbp"] - s["model_dbp"] for s in samples]
        
        cfg["sbp_scale"] = 1.0
        cfg["sbp_offset"] = float(np.median(sbp_diffs))
        cfg["dbp_scale"] = 1.0
        cfg["dbp_offset"] = float(np.median(dbp_diffs))
        cfg["status"] = "cold_start" if n == 1 else "additive"
    else:
        # Least squares linear regression fit
        x_sbp = np.array([s["model_sbp"] for s in samples], dtype=np.float64)
        y_sbp = np.array([s["cuff_sbp"] for s in samples], dtype=np.float64)
        x_dbp = np.array([s["model_dbp"] for s in samples], dtype=np.float64)
        y_dbp = np.array([s["cuff_dbp"] for s in samples], dtype=np.float64)
        
        sbp_scale = 1.0 if np.std(x_sbp) < 1e-4 else float(np.polyfit(x_sbp, y_sbp, 1)[0])
        sbp_offset = float(np.mean(y_sbp) - sbp_scale * np.mean(x_sbp))
        
        dbp_scale = 1.0 if np.std(x_dbp) < 1e-4 else float(np.polyfit(x_dbp, y_dbp, 1)[0])
        dbp_offset = float(np.mean(y_dbp) - dbp_scale * np.mean(x_dbp))
        
        # Clamping coefficients to safe physiological boundaries
        c_sbp_scale = float(np.clip(sbp_scale, 0.7, 1.3))
        c_sbp_offset = float(np.clip(sbp_offset, -25.0, 25.0))
        c_dbp_scale = float(np.clip(dbp_scale, 0.7, 1.3))
        c_dbp_offset = float(np.clip(dbp_offset, -25.0, 25.0))
        
        cfg["sbp_scale"] = c_sbp_scale
        cfg["sbp_offset"] = c_sbp_offset
        cfg["dbp_scale"] = c_dbp_scale
        cfg["dbp_offset"] = c_dbp_offset
        
        is_clamped = (sbp_scale != c_sbp_scale or sbp_offset != c_sbp_offset or
                      dbp_scale != c_dbp_scale or dbp_offset != c_dbp_offset)
        cfg["status"] = "weak" if is_clamped else "linear"
        
    return cfg

# -------------------------------------------------------------
# Request & Response Schemas
# -------------------------------------------------------------
class SubmitSignalsRequest(BaseModel):
    device_id: Optional[str] = "esp8266-test-bench"
    ppg_signal: List[float]
    ecg_signal: List[float]

class CalibrateRequest(BaseModel):
    cuff_sbp: float = Field(..., ge=70, le=200)
    cuff_dbp: float = Field(..., ge=40, le=130)

class HeartbeatRequest(BaseModel):
    leads_connected: bool
    finger_detected: bool

# -------------------------------------------------------------
# Endpoints
# -------------------------------------------------------------

@app.get("/")
def serve_index():
    # If served directly via uvicorn, reads and renders index HTML
    html_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bp_test_bench.html")
    if os.path.exists(html_path):
        from fastapi.responses import FileResponse
        return FileResponse(html_path)
    return {"message": "Standalone server is running! Place your bp_test_bench.html in this folder to view the dashboard."}

@app.post("/api/v1/vitals/bp/submit")
def submit_reading(payload: SubmitSignalsRequest):
    """
    ESP8266 uploads raw 8s window signal to this standalone endpoint.
    Computes SBP/DBP via Keras model and applies locally saved calibration offsets.
    """
    if not model_manager.ensure_loaded():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Keras model prediction engine not ready: {model_manager.error}"
        )
        
    if len(payload.ppg_signal) != WINDOW_SIZE or len(payload.ecg_signal) != WINDOW_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Incomplete sample window. Expected {WINDOW_SIZE} samples, got ppg={len(payload.ppg_signal)} and ecg={len(payload.ecg_signal)}"
        )
        
    try:
        ppg = np.array(payload.ppg_signal, dtype=np.float32)
        ecg = np.array(payload.ecg_signal, dtype=np.float32)
        
        # Preprocessing & Normalization
        ppg_f = bandpass(ppg, 0.5, 8.0, FS)
        ecg_f = bandpass(ecg, 0.5, 40.0, FS)
        
        ppg_n = normalize_wave(ppg_f)
        ecg_n = normalize_wave(ecg_f)
        
        # Waveform model shape (1, 800, 2)
        wave_input = np.stack([ppg_n, ecg_n], axis=-1)[np.newaxis].astype(np.float32)
        
        # Physiological Feature extraction
        feats = extract_features(ppg_n, ecg_n)
        feat_scaled = model_manager.sc_x.transform(feats.reshape(1, -1)).astype(np.float32)
        
        # Model Prediction execution
        pred_scaled = model_manager.model({'waveform_input': wave_input, 'feature_input': feat_scaled}, training=False).numpy()
        pred = model_manager.sc_y.inverse_transform(pred_scaled)[0]
        
        model_sbp = np.clip(float(pred[0]), 50.0, 300.0)
        model_dbp = np.clip(float(pred[1]), 30.0, 200.0)
        
        hr = float(feats[0]) if feats[0] > 0 else 75.0
        ptt = float(feats[3]) if feats[3] > 0 else 0.25
        
        # Load local calibration config and adjust readings
        cal_cfg = load_calibration_config()
        cal_sbp = cal_cfg["sbp_scale"] * model_sbp + cal_cfg["sbp_offset"]
        cal_dbp = cal_cfg["dbp_scale"] * model_dbp + cal_cfg["dbp_offset"]
        
        cal_sbp = np.clip(float(cal_sbp), 50.0, 300.0)
        cal_dbp = np.clip(float(cal_dbp), 30.0, 200.0)
        
        # Store to cache
        state.latest_ppg = ppg.tolist()
        state.latest_ecg = ecg.tolist()
        state.raw_sbp = round(model_sbp, 1)
        state.raw_dbp = round(model_dbp, 1)
        state.cal_sbp = round(cal_sbp, 1)
        state.cal_dbp = round(cal_dbp, 1)
        state.heart_rate = round(hr, 1)
        state.ptt = round(ptt, 4)
        state.status = "Success: Prediction calculated!"
        state.last_seen = np.datetime64('now').astype(str)
        
        return {
            "status": "success",
            "model_systolic": state.raw_sbp,
            "model_diastolic": state.raw_dbp,
            "calibrated_systolic": state.cal_sbp,
            "calibrated_diastolic": state.cal_dbp,
            "heart_rate": state.heart_rate,
            "ptt": state.ptt,
            "calibration_status": cal_cfg["status"]
        }
        
    except Exception as e:
        state.status = f"Inference Error: {str(e)}"
        raise HTTPException(status_code=500, detail=state.status)

@app.post("/api/v1/vitals/bp/heartbeat")
def update_heartbeat(payload: HeartbeatRequest):
    """
    ESP8266 posts periodic heartbeat connection stats
    """
    state.leads_connected = payload.leads_connected
    state.finger_detected = payload.finger_detected
    state.last_seen = np.datetime64('now').astype(str)
    return {"status": "success"}

@app.get("/api/test-bench/latest")
def get_latest_data():
    """
    For the HTML page to poll current waveforms and prediction results
    """
    cal_cfg = load_calibration_config()
    return {
        "status": state.status,
        "last_seen": state.last_seen,
        "leads_connected": state.leads_connected,
        "finger_detected": state.finger_detected,
        "heart_rate": state.heart_rate,
        "ptt": state.ptt,
        "raw_sbp": state.raw_sbp,
        "raw_dbp": state.raw_dbp,
        "cal_sbp": state.cal_sbp,
        "cal_dbp": state.cal_dbp,
        "cal_status": cal_cfg["status"],
        "cal_coefficients": {
            "sbp_scale": cal_cfg["sbp_scale"],
            "sbp_offset": cal_cfg["sbp_offset"],
            "dbp_scale": cal_cfg["dbp_scale"],
            "dbp_offset": cal_cfg["dbp_offset"],
            "samples_count": cal_cfg["samples_count"]
        },
        "has_signals": len(state.latest_ppg) > 0,
        "ppg_signal": state.latest_ppg[-200:], # return a subset for fast plotting in dashboard
        "ecg_signal": state.latest_ecg[-200:]
    }

@app.post("/api/test-bench/calibrate")
def add_calibration(cuff_data: CalibrateRequest):
    """
    Takes a reference cuff blood pressure and fits it to the last raw model output.
    """
    if state.raw_sbp is None or state.raw_dbp is None:
        raise HTTPException(
            status_code=400,
            detail="No matching model prediction available to calibrate. Please perform a measurement first."
        )
        
    cal_cfg = load_calibration_config()
    
    # Store new calibration pair
    new_sample = {
        "timestamp": np.datetime64('now').astype(str),
        "model_sbp": state.raw_sbp,
        "model_dbp": state.raw_dbp,
        "cuff_sbp": cuff_data.cuff_sbp,
        "cuff_dbp": cuff_data.cuff_dbp
    }
    
    cal_cfg["samples"].append(new_sample)
    
    # Keep only the last 10 calibration sets to match product specifications
    if len(cal_cfg["samples"]) > 10:
        cal_cfg["samples"] = cal_cfg["samples"][-10:]
        
    # Recalculate coefficients
    cal_cfg = calculate_offset_fit(cal_cfg)
    save_calibration_config(cal_cfg)
    
    # Update current calibration in cached state immediately
    state.cal_sbp = round(cal_cfg["sbp_scale"] * state.raw_sbp + cal_cfg["sbp_offset"], 1)
    state.cal_dbp = round(cal_cfg["dbp_scale"] * state.raw_dbp + cal_cfg["dbp_offset"], 1)
    
    return {
        "status": "success",
        "coefficients": {
            "sbp_scale": cal_cfg["sbp_scale"],
            "sbp_offset": cal_cfg["sbp_offset"],
            "dbp_scale": cal_cfg["dbp_scale"],
            "dbp_offset": cal_cfg["dbp_offset"],
            "samples_count": cal_cfg["samples_count"]
        },
        "calibration_status": cal_cfg["status"],
        "applied_calibrated_bp": f"{state.cal_sbp}/{state.cal_dbp}"
    }

@app.post("/api/test-bench/reset-calibration")
def reset_calibration():
    """
    Wipes out calibration samples and restores scales to 1.0 and offsets to 0.0.
    """
    cal_cfg = {
        "status": "not_calibrated",
        "samples_count": 0,
        "sbp_scale": 1.0,
        "sbp_offset": 0.0,
        "dbp_scale": 1.0,
        "dbp_offset": 0.0,
        "samples": []
    }
    save_calibration_config(cal_cfg)
    
    # Re-apply defaults to currently loaded state
    if state.raw_sbp is not None:
        state.cal_sbp = state.raw_sbp
        state.cal_dbp = state.raw_dbp
        
    return {"status": "success", "message": "Calibration matrix reset to default settings"}

# -------------------------------------------------------------
# App Entry Runner (Local Bootstrapper)
# -------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    # Initial loader attempt
    model_manager.ensure_loaded()
    print("Starting Standalone Test Server on port 8000...")
    print("ESP8266 will stream to http://localhost:8000/api/v1/vitals/bp/submit")
    uvicorn.run(app, host="127.0.0.1", port=8000)
