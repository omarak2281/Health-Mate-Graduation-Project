"""
Medication model with schedule and medicine box integration
"""

from sqlalchemy import Column, ForeignKey, String, Integer, Boolean, DateTime, Time, Text
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship
from datetime import datetime, time
import uuid

from app.core.database import Base


class Medication(Base):
    """
    Medication model
    
    Stores medication information and schedule
    Can be assigned to medicine box drawer
    """
    __tablename__ = "medications"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Key
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Medication Info
    name = Column(String(255), nullable=False)
    dosage = Column(String(255), nullable=False)  # e.g. "100mg", "2 tablets"
    instructions = Column(Text, nullable=True)
    image_url = Column(String(500), nullable=True) # URL for medicine image
    
    # Schedule
    times_per_day = Column(Integer, nullable=False)
    scheduled_times = Column(ARRAY(String), nullable=False)  # List of HH:MM strings
    
    # Medicine Box Integration
    use_smart_box = Column(Boolean, default=False, nullable=False)
    drawer_number = Column(Integer, nullable=True)  # Assigned drawer (1-6)
    
    # Status
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="medications")
    
    def __repr__(self):
        return f"<Medication(name={self.name}, dosage={self.dosage}, drawer={self.drawer_number})>"
