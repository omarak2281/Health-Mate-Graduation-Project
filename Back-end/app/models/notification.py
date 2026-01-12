"""
Notification model for alerts and messages
"""

from sqlalchemy import Column, ForeignKey, String, Boolean, DateTime, Enum as SQLEnum, Text
from sqlalchemy.dialects.postgresql import UUID, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum

from app.core.database import Base


class NotificationType(str, enum.Enum):
    """Type of notification"""
    EMERGENCY_BP_ALERT = "emergency_bp_alert"
    MEDICATION_REMINDER = "medication_reminder"
    SENSOR_DISCONNECTION = "sensor_disconnection"
    MEDICINE_BOX_FAULT = "medicine_box_fault"
    NEW_CAREGIVER_LINKED = "new_caregiver_linked"
    INCOMING_CALL = "incoming_call"
    MISSED_CALL = "missed_call"


class Notification(Base):
    """
    Notification model
    
    Stores all notifications for push/in-app alerts
    Tracks read status
    """
    __tablename__ = "notifications"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Key
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Notification Details
    notification_type = Column(SQLEnum(NotificationType), nullable=False)
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    
    # Additional Data (JSON for flexibility)
    data = Column(JSON, nullable=True)  # e.g., {"bp_reading": "180/120", "risk": "critical"}
    
    # Status
    is_read = Column(Boolean, default=False, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    read_at = Column(DateTime, nullable=True)
    
    # Relationship
    user = relationship("User")
    
    def __repr__(self):
        return f"<Notification(type={self.notification_type}, user={self.user_id}, read={self.is_read})>"
