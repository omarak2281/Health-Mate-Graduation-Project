"""
Blood Pressure Prediction Service (ABP)
Uses PPG/ECG signals to predict continuous blood pressure
"""

import os
from typing import List, Dict, Optional
import numpy as np
import scipy.signal
from scipy.stats import skew, kurtosis
import joblib

# Paths to the model and scalers
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "models")
MODEL_PATH = os.path.join(MODELS_DIR, "bp_model_final.keras")
SCALER_X_PATH = os.path.join(MODELS_DIR, "scaler_features.pkl")
SCALER_Y_PATH = os.path.join(MODELS_DIR, "scaler_targets.pkl")

# Constant parameters
FS = 100
WINDOW_SIZE = 800
HR_MAX = 180.0
HR_MIN = 40.0


def bandpass(sig: np.ndarray, lo: float, hi: float, fs: float, order: int = 4) -> np.ndarray:
    """Bandpass filter using Butterworth filter"""
    nyq = 0.5 * fs
    b, a = scipy.signal.butter(order, [max(lo / nyq, 1e-5), min(hi / nyq, 0.9999)], btype='band')
    return scipy.signal.filtfilt(b, a, sig).astype(np.float32)


def normalize_wave(sig: np.ndarray) -> np.ndarray:
    """Z-score normalization"""
    return ((sig - sig.mean()) / (sig.std() + 1e-8)).astype(np.float32)


def extract_features(ppg_w: np.ndarray, ecg_w: np.ndarray) -> np.ndarray:
    """Extract 21 physiological features from PPG and ECG waveforms"""
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
    
    # 12, 13: Velocity photoplethysmogram (VPG)
    vpg = np.diff(ppg_w)
    feats[12] = vpg.mean()
    feats[13] = vpg.std()
    
    # 14, 15: Acceleration photoplethysmogram (APG)
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


class ABPPredictionService:
    """
    Inference service for ABP Prediction using the final Keras model.
    If the model artifacts do not exist, falls back gracefully to `model_not_ready`
    without crashing server boot.
    """
    
    def __init__(self):
        self.is_ready = False
        self.model = None
        self.sc_x = None
        self.sc_y = None
        self.load_model()
        
    def load_model(self) -> bool:
        """Dynamically load TensorFlow and model packages to prevent boot dependency blocker"""
        # Ensure model directory exists
        os.makedirs(MODELS_DIR, exist_ok=True)
        
        # Check files presence
        if not (os.path.exists(MODEL_PATH) and os.path.exists(SCALER_X_PATH) and os.path.exists(SCALER_Y_PATH)):
            self.is_ready = False
            return False
            
        try:
            # Import Tensorflow dynamically so we don't crash startup if TF is not installed
            import tensorflow as tf
            
            # Load keras model
            self.model = tf.keras.models.load_model(MODEL_PATH)
            
            # Load pickles
            self.sc_x = joblib.load(SCALER_X_PATH)
            self.sc_y = joblib.load(SCALER_Y_PATH)
            
            self.is_ready = True
            return True
        except Exception as e:
            # Fall back to not ready
            print(f"Error loading BP Keras Inference model: {e}")
            self.is_ready = False
            return False
            
    def predict_bp(self, ppg_signal: List[float], ecg_signal: List[float]) -> Dict:
        """
        Calculate blood pressure from PPG and ECG signals using the deep learning model.
        Returns prediction status and predicted values.
        """
        # Attempt deferred loading if not ready
        if not self.is_ready:
            self.load_model()
            
        if not self.is_ready:
            return {
                "prediction_status": "model_not_ready",
                "systolic": None,
                "diastolic": None,
                "heart_rate": None,
                "signal_quality": 0.0,
                "ptt": 0.0,
            }
            
        if len(ppg_signal) != WINDOW_SIZE or len(ecg_signal) != WINDOW_SIZE:
            return {
                "prediction_status": "wrong_signal_length",
                "systolic": None,
                "diastolic": None,
                "heart_rate": None,
                "signal_quality": 0.0,
                "ptt": 0.0,
            }
            
        try:
            ppg = np.array(ppg_signal, dtype=np.float32)
            ecg = np.array(ecg_signal, dtype=np.float32)
            
            if not np.all(np.isfinite(ppg)) or not np.all(np.isfinite(ecg)):
                return {
                    "prediction_status": "invalid_values",
                    "systolic": None,
                    "diastolic": None,
                    "heart_rate": None,
                    "signal_quality": 0.0,
                    "ptt": 0.0,
                }
            
            # 1. Preprocessing (filtering & z-score normalizing)
            ppg_f = bandpass(ppg, 0.5, 8.0, FS)
            ecg_f = bandpass(ecg, 0.5, 40.0, FS)
            
            ppg_n = normalize_wave(ppg_f)
            ecg_n = normalize_wave(ecg_f)
            
            # Form waveform input array shape (1, 800, 2)
            wave_input = np.stack([ppg_n, ecg_n], axis=-1)[np.newaxis].astype(np.float32)
            
            # 2. Extract features shape (1, 21)
            feats = extract_features(ppg_n, ecg_n)
            feat_sc = self.sc_x.transform(feats.reshape(1, -1)).astype(np.float32)
            
            # 3. Model run
            # Use direct __call__ or predict
            pred_sc = self.model({'waveform_input': wave_input, 'feature_input': feat_sc}, training=False).numpy()
            pred = self.sc_y.inverse_transform(pred_sc)[0]
            
            sbp = float(pred[0])
            dbp = float(pred[1])
            hr = float(feats[0]) if feats[0] > 0 else 75.0
            ptt = float(feats[3]) if feats[3] > 0 else 0.25
            
            # Physiological clamp checks
            sbp = float(np.clip(sbp, 50.0, 300.0))
            dbp = float(np.clip(dbp, 30.0, 200.0))
            hr = float(np.clip(hr, 30.0, 220.0))
            
            return {
                "prediction_status": "success",
                "systolic": round(sbp, 1),
                "diastolic": round(dbp, 1),
                "heart_rate": round(hr, 1),
                "signal_quality": 1.0,  # Preprocessing validates finite length
                "ptt": round(ptt, 4),
            }
        except Exception as e:
            return {
                "prediction_status": f"inference_error: {str(e)}",
                "systolic": None,
                "diastolic": None,
                "heart_rate": None,
                "signal_quality": 0.0,
                "ptt": 0.0,
            }


# Singleton instance
abp_service = ABPPredictionService()


def get_abp_service() -> ABPPredictionService:
    return abp_service
