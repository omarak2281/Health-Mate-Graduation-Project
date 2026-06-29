"""
Medication adherence model for tracking taken doses
"""

from sqlalchemy import Column, ForeignKey, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base


class MedicationAdherence(Base):
    """
    Medication Adherence model
    
    Records when a user confirms taking their medication.
    Supports storing an optional confirmation image.
    """
    __tablename__ = "medication_adherence"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Keys
    medication_id = Column(UUID(as_uuid=True), ForeignKey("medications.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Adherence Data
    taken_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    image_url = Column(String(500), nullable=True)  # Optional photo proof
    
    # Relationships
    medication = relationship("Medication", backref="adherence_logs")
    user = relationship("User", backref="medication_adherence_logs")
    
    def __repr__(self):
        return f"<MedicationAdherence(medication={self.medication_id}, user={self.user_id}, taken_at={self.taken_at})>"
