"""
Vital signs schemas
"""

from pydantic import BaseModel, Field, model_validator
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from app.models.vital_sign import RiskLevel, MeasurementStatus


class VitalSignCreate(BaseModel):
    """Create vital sign reading"""
    systolic: Optional[int] = Field(None, ge=50, le=300)
    diastolic: Optional[int] = Field(None, ge=30, le=200)
    heart_rate: Optional[int] = Field(None, ge=30, le=250)
    spo2: Optional[int] = Field(None, ge=0, le=100)
    source: str = Field(default="manual", max_length=50)
    measurement_status: MeasurementStatus = Field(default=MeasurementStatus.COMPLETED)
    device_id: Optional[str] = Field(None, max_length=100)

    @model_validator(mode='after')
    def validate_systolic_diastolic(self) -> 'VitalSignCreate':
        if self.systolic is not None and self.diastolic is not None:
            if self.systolic <= self.diastolic:
                raise ValueError("systolic must be greater than diastolic")
        return self


class VitalSignResponse(BaseModel):
    """Vital sign response"""
    id: UUID
    user_id: UUID
    systolic: Optional[int]
    diastolic: Optional[int]
    heart_rate: Optional[int]
    spo2: Optional[int]
    risk_level: RiskLevel
    source: str
    confidence: Optional[float]
    signal_quality: Optional[float]
    measurement_status: MeasurementStatus
    rejection_reason: Optional[str]
    device_id: Optional[str]
    model_systolic: Optional[float]
    model_diastolic: Optional[float]
    calibrated_systolic: Optional[float]
    calibrated_diastolic: Optional[float]
    calibration_status: Optional[str]
    measured_at: datetime
    created_at: datetime
    
    class Config:
        from_attributes = True


class CuffCompleteRequest(BaseModel):
    """Payload to complete a pending device measurement with manual cuff values"""
    vital_sign_id: UUID
    systolic: int = Field(..., ge=50, le=300)
    diastolic: int = Field(..., ge=30, le=200)

    @model_validator(mode='after')
    def validate_systolic_diastolic(self) -> 'CuffCompleteRequest':
        if self.systolic <= self.diastolic:
            raise ValueError("systolic must be greater than diastolic")
        return self


class VitalSignDeviceSubmit(BaseModel):
    """Payload submitted by the hardware device containing PPG and ECG signals"""
    device_id: str = Field(..., max_length=100)
    ppg_signal: List[float]
    ecg_signal: List[float]
    heart_rate: Optional[int] = Field(None, ge=0, le=250)
    # SpO2 is computed on-device by the MAX30102 (red/IR ratio-of-ratios).
    # Bounds are deliberately wide so a mis-measured value never 422s the whole
    # BP submission; the endpoint nulls anything outside the plausible 70-100%.
    spo2: Optional[int] = Field(None, ge=0, le=150)

    @model_validator(mode='after')
    def validate_signals_length(self) -> 'VitalSignDeviceSubmit':
        if len(self.ppg_signal) != 800:
            raise ValueError("ppg_signal must contain exactly 800 samples")
        if len(self.ecg_signal) != 800:
            raise ValueError("ecg_signal must contain exactly 800 samples")
            
        return self


class BPDeviceHeartbeat(BaseModel):
    """Payload submitted by the hardware device for periodic heartbeat"""
    leads_connected: bool
    finger_detected: bool

