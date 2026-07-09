from sqlalchemy import Column, ForeignKey, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base


class RegisteredDevice(Base):
    """
    Registered IoT device for secure authentication.
    Maps a device_id and device_token_hash to a specific patient.
    """
    __tablename__ = "registered_devices"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    device_id = Column(String(100), unique=True, nullable=False, index=True)
    token_hash = Column(String(200), nullable=False)
    patient_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    is_active = Column(Boolean, default=True, nullable=False)
    registered_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_seen_at = Column(DateTime, nullable=True)
    last_leads_connected = Column(Boolean, nullable=True)
    last_finger_detected = Column(Boolean, nullable=True)

    patient = relationship("User")

    def __repr__(self):
        return f"<RegisteredDevice(device_id={self.device_id}, patient={self.patient_id}, active={self.is_active})>"

