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
    dosage = Column(String(100), nullable=False)  # e.g. "100mg", "2 tablets"
    instructions = Column(Text, nullable=True)
    
    # Schedule
    frequency = Column(String(50), nullable=False)  # daily, twice_daily, weekly, etc.
    time_slots = Column(ARRAY(Time), nullable=False)  # List of times to take medication
    
    # Medicine Box Integration
    drawer_number = Column(Integer, nullable=True)  # Assigned drawer (1-N)
    
    # Status
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Reminder Settings
    enable_led = Column(Boolean, default=True, nullable=False)
    enable_buzzer = Column(Boolean, default=True, nullable=False)
    enable_notification = Column(Boolean, default=True, nullable=False)
    image_url = Column(String(500), nullable=True) # URL for medicine image
    
    # Timestamps
    start_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    end_date = Column(DateTime, nullable=True)  # Null means ongoing
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="medications")
    
    def __repr__(self):
        return f"<Medication(name={self.name}, user={self.user_id}, drawer={self.drawer_number})>"
