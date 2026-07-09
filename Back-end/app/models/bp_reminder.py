"""
Blood pressure measurement reminder model.
Three fixed daily reminders are derived from one patient-chosen start time
(start, +8h, +16h, wrapping midnight) — see bp_reminder_service.py.
"""

from sqlalchemy import Column, ForeignKey, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base


class BPReminder(Base):
    """One of the (up to) 3 daily BP measurement reminder times for a patient."""
    __tablename__ = "bp_reminders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    scheduled_time = Column(String(5), nullable=False)  # "HH:MM", 24h
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = relationship("User")

    def __repr__(self):
        return f"<BPReminder(patient={self.patient_id}, time={self.scheduled_time})>"
