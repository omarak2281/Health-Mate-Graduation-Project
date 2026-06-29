"""
Call session model for audio/video calls
Supports WebRTC communication between patients and caregivers
"""

from sqlalchemy import Column, ForeignKey, String, Integer, DateTime, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum

from app.core.database import Base


class CallType(str, enum.Enum):
    """Type of call"""
    AUDIO = "audio"
    VIDEO = "video"


class CallStatus(str, enum.Enum):
    """Call session status"""
    IDLE = "idle"
    RINGING = "ringing"
    IN_CALL = "in_call"
    ENDED = "ended"
    REJECTED = "rejected"


class CallSession(Base):
    """
    Call session model
    
    Tracks audio/video call sessions between users
    Enforces one active call per patient (concurrency control)
    """
    __tablename__ = "call_sessions"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Keys
    caller_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    callee_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Call Details
    call_type = Column(SQLEnum(CallType), nullable=False)
    status = Column(SQLEnum(CallStatus), nullable=False, default=CallStatus.IDLE, index=True)
    
    # WebRTC Signaling Data (stored as JSON text)
    offer_sdp = Column(String(5000), nullable=True)
    answer_sdp = Column(String(5000), nullable=True)
    
    # Duration
    duration_seconds = Column(Integer, nullable=True, default=0)
    
    # Timestamps
    started_at = Column(DateTime, nullable=True)
    answered_at = Column(DateTime, nullable=True)
    ended_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationships
    caller = relationship("User", foreign_keys=[caller_id], back_populates="calls_initiated")
    callee = relationship("User", foreign_keys=[callee_id], back_populates="calls_received")
    
    def __repr__(self):
        return f"<CallSession(caller={self.caller_id}, callee={self.callee_id}, status={self.status})>"
