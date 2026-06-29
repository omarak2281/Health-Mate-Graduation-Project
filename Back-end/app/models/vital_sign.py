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
    
    # Blood Pressure
    systolic = Column(Integer, nullable=False)  # mmHg
    diastolic = Column(Integer, nullable=False)  # mmHg
    
    # Heart Rate (optional, from ECG sensor)
    heart_rate = Column(Integer, nullable=True)  # bpm
    
    # Risk Assessment
    risk_level = Column(SQLEnum(RiskLevel), nullable=False, default=RiskLevel.NORMAL)
    
    # Source
    source = Column(String(50), nullable=False, default="sensor")  # sensor, manual, ai_prediction
    
    # AI Model Confidence (if predicted)
    confidence = Column(Float, nullable=True)
    
    # Sensor Quality (if from sensors)
    signal_quality = Column(Float, nullable=True)  # 0.0 to 1.0
    
    # Timestamps
    measured_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="vitals")
    
    def __repr__(self):
        return f"<VitalSign(user={self.user_id}, bp={self.systolic}/{self.diastolic}, risk={self.risk_level})>"
    
    def calculate_risk_level(self) -> RiskLevel:
        """
        Calculate risk level based on BP thresholds
        
        Normal: 90/60 - 120/80
        Low: < 90/60
        Moderate: 120-139/80-89
        High: 140-179/90-119
        Critical: >= 180/120
        """
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
