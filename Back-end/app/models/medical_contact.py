"""
Medical contacts model for doctors, clinics, pharmacies
"""

from sqlalchemy import Column, ForeignKey, String, Text, DateTime, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum

from app.core.database import Base


class ContactType(str, enum.Enum):
    """Type of medical contact"""
    DOCTOR = "doctor"
    CLINIC = "clinic"
    PHARMACY = "pharmacy"
    EMERGENCY = "emergency"
    FAMILY = "family"


class MedicalContact(Base):
    """
    Medical contacts model
    
    Stores emergency contacts like doctors, clinics, pharmacies
    Quick-call functionality for emergencies
    """
    __tablename__ = "medical_contacts"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Key
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Contact Info
    name = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=False)
    contact_type = Column(SQLEnum(ContactType), nullable=False)
    notes = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="medical_contacts")
    
    def __repr__(self):
        return f"<MedicalContact(name={self.name}, type={self.contact_type}, user={self.user_id})>"
