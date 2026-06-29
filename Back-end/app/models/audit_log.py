"""
Audit log model for system events
"""

from sqlalchemy import Column, ForeignKey, String, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base


class AuditLog(Base):
    """
    Audit log model
    
    Tracks all important system events for security and debugging
    Complies with medical data regulations
    """
    __tablename__ = "audit_logs"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Key (nullable - some events may not be user-specific)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    
    # Event Details
    event_type = Column(String(100), nullable=False, index=True)  # login, logout, bp_reading, call_initiated, etc.
    event_description = Column(Text, nullable=False)
    
    # Additional Data
    event_data = Column(JSON, nullable=True)
    
    # Request Info
    ip_address = Column(String(50), nullable=True)
    user_agent = Column(String(500), nullable=True)
    
    # Timestamp
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    # Relationship
    user = relationship("User")
    
    def __repr__(self):
        return f"<AuditLog(type={self.event_type}, user={self.user_id})>"
