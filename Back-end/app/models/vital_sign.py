"""
Vital signs model for blood pressure readings
"""

from sqlalchemy import Column, ForeignKey, Integer, Float, String, DateTime, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum

from app.core.database import Base


class RiskLevel(str, enum.Enum):
    """Blood pressure risk level"""
    NORMAL = "normal"
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    CRITICAL = "critical"


class MeasurementStatus(str, enum.Enum):
    """Blood pressure measurement status"""
    COMPLETED = "completed"
    COMPLETED_PENDING_BP = "completed_pending_bp"
    REJECTED = "rejected"


class VitalSign(Base):
    """
    Vital signs model - primarily blood pressure readings
    
    Stores BP readings from sensors or manual input
    Includes risk level for emergency alerts
    """
    __tablename__ = "vital_signs"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Key
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Blood Pressure (can be nullable now if we submit pending sensor values that don't have blood pressure values yet! Wait!)
    # Let's think: when a sensor starts, it gets hr, spo2, finger_detected, etc. but NO systolic/diastolic yet.
    # Therefore, systolic and diastolic MUST be nullable in the DB!
    # Ah! Let's check: "systolic = Column(Integer, nullable=False)"
    # If it is nullable=False, then when we create a "pending" row from the device, we cannot insert it because systolic/diastolic are null!
    # So we must modify systolic and diastolic columns to be nullable=True in the model, but they should be required in schemas when completed.
    # Yes! Let's check the spec: "on pass persists a VitalSign with source="sensor", heart_rate, signal_quality, measurement_status="completed_pending_bp" (new status — HR/SpO2 known, systolic/diastolic still awaited)"
    # This means systolic/diastolic of the DB model MUST change from nullable=False to nullable=True!
    # This is a very important detail.
    systolic = Column(Integer, nullable=True)  # mmHg, nullable to support pending device readings
    diastolic = Column(Integer, nullable=True)  # mmHg, nullable to support pending device readings
    
    # Heart Rate (optional, from ECG sensor)
    heart_rate = Column(Integer, nullable=True)  # bpm

    # Blood oxygen saturation (optional, computed on-device by the MAX30102)
    spo2 = Column(Integer, nullable=True)  # percent, 0-100
    
    # Risk Assessment
    risk_level = Column(SQLEnum(RiskLevel), nullable=False, default=RiskLevel.NORMAL)
    
    # Source
    source = Column(String(50), nullable=False, default="sensor")  # sensor, manual, ai_prediction
    
    # AI Model Confidence (if predicted)
    confidence = Column(Float, nullable=True)
    
    # Sensor Quality (if from sensors)
    signal_quality = Column(Float, nullable=True)  # 0.0 to 1.0
    
    # Measurement Status and Device ID
    # values_callable makes SQLAlchemy persist the enum *values* (lowercase,
    # e.g. 'completed_pending_bp') matching the Postgres enum created by the
    # bp_phase1 migration — the default persists member NAMES (uppercase),
    # which the DB enum rejects, silently breaking every vital-sign insert.
    measurement_status = Column(
        SQLEnum(MeasurementStatus, values_callable=lambda e: [m.value for m in e]),
        nullable=False,
        default=MeasurementStatus.COMPLETED,
    )
    device_id = Column(String(100), nullable=True)

    # Why a rejected reading was not accepted (finger_missing, leads_off,
    # poor_signal, out_of_range) — set only when measurement_status == REJECTED
    rejection_reason = Column(String(50), nullable=True)
    
    # Model predicted and calibrated values (Phase 2 & Phase 5)
    model_systolic = Column(Float, nullable=True)
    model_diastolic = Column(Float, nullable=True)
    calibrated_systolic = Column(Float, nullable=True)
    calibrated_diastolic = Column(Float, nullable=True)
    calibration_status = Column(String(50), nullable=True)
    
    # Timestamps
    measured_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="vitals")
    
    def calculate_risk_level(self) -> RiskLevel:
        """
        Calculate risk level based on BP thresholds
        
        Normal: 90/60 - 120/80
        Low: < 90/60
        Moderate: 120-139/80-89
        High: 140-179/90-119
        Critical: >= 180/120
        """
        if self.systolic is None or self.diastolic is None:
            return RiskLevel.NORMAL
        if self.systolic < 90 or self.diastolic < 60:
            return RiskLevel.LOW
        elif self.systolic >= 180 or self.diastolic >= 120 :
            return RiskLevel.CRITICAL
        elif self.systolic >= 140 or self.diastolic >= 90:
            return RiskLevel.HIGH
        elif self.systolic >= 120 or self.diastolic >= 80:
            return RiskLevel.MODERATE
        else:
            return RiskLevel.NORMAL

    def __repr__(self):
        return f"<VitalSign(user={self.user_id}, bp={self.systolic}/{self.diastolic}, risk={self.risk_level})>"


class BPAlertCooldown(Base):
    """
    Blood pressure alert cooldown tracking table
    """
    __tablename__ = "bp_alert_cooldowns"
    
    patient_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    risk_level = Column(String(50), primary_key=True)
    last_sent_at = Column(DateTime, default=datetime.utcnow, nullable=False, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f"<BPAlertCooldown(patient={self.patient_id}, risk={self.risk_level}, last_sent={self.last_sent_at})>"
