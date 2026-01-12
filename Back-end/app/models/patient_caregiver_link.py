"""
Patient-Caregiver relationship model
Many-to-many relationship allowing multiple caregivers per patient
"""

from sqlalchemy import Column, ForeignKey, DateTime, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base


class PatientCaregiverLink(Base):
    """
    Patient-Caregiver linking table
    
    Allows many-to-many relationship:
    - One patient can have multiple caregivers
    - One caregiver can monitor multiple patients
    """
    __tablename__ = "patient_caregiver_links"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Keys
    patient_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    caregiver_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Status
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Timestamps
    linked_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationships
    patient = relationship("User", foreign_keys=[patient_id], back_populates="caregivers")
    caregiver = relationship("User", foreign_keys=[caregiver_id], back_populates="patients")
    
    def __repr__(self):
        return f"<PatientCaregiverLink(patient={self.patient_id}, caregiver={self.caregiver_id})>"
