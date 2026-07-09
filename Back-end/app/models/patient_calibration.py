from sqlalchemy import Column, ForeignKey, String, Float, Integer, DateTime, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base


class PatientCalibration(Base):
    """
    Per-patient BP model calibration coefficients.
    """
    __tablename__ = "patient_calibrations"

    patient_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    sbp_scale = Column(Float, nullable=False, default=1.0)
    sbp_offset = Column(Float, nullable=False, default=0.0)
    dbp_scale = Column(Float, nullable=False, default=1.0)
    dbp_offset = Column(Float, nullable=False, default=0.0)
    samples_count = Column(Integer, nullable=False, default=0)
    last_calibrated_at = Column(DateTime, nullable=True)
    calibration_status = Column(String(50), nullable=False, default="not_calibrated")  # not_calibrated, calibrated, recalibration_due

    # Drift and Baseline Tracking (from master implementation plan)
    baseline_raw_mean_sbp = Column(Float, nullable=True)
    baseline_raw_mean_dbp = Column(Float, nullable=True)
    drift_flag = Column(Boolean, nullable=False, default=False)
    drift_reason = Column(String(50), nullable=True)
    drift_flagged_at = Column(DateTime, nullable=True)
    last_drift_notification_at = Column(DateTime, nullable=True)

    patient = relationship("User")

    def __repr__(self):
        return f"<PatientCalibration(patient={self.patient_id}, status={self.calibration_status})>"


class CalibrationSample(Base):
    """
    Saves the cuff reading vs. the raw model predicted BP for fit computation.
    """
    __tablename__ = "calibration_samples"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    model_sbp = Column(Float, nullable=False)
    model_dbp = Column(Float, nullable=False)
    cuff_sbp = Column(Float, nullable=False)
    cuff_dbp = Column(Float, nullable=False)
    signal_quality = Column(Float, nullable=False, default=1.0)
    measured_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = relationship("User")

    def __repr__(self):
        return f"<CalibrationSample(patient={self.patient_id}, cuff={self.cuff_sbp}/{self.cuff_dbp}, model={self.model_sbp}/{self.model_dbp})>"
