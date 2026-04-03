"""
AI Chat History model for Symptom Checker
"""

from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Float, Uuid
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base


class AIChatMessage(Base):
    """
    AI Chat Message model

    Stores interactions between users and the Symptom Checker AI
    """
    __tablename__ = "ai_chat_messages"

    # Primary Key
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)

    # Foreign Key to User
    user_id = Column(Uuid(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)

    # Session ID to group messages
    session_id = Column(String(100), nullable=False, index=True)

    # Message content
    message = Column(Text, nullable=False)

    # Role: 'user' or 'ai'
    role = Column(String(20), nullable=False)

    # Metadata
    disease_predicted = Column(String(255), nullable=True)
    confidence = Column(Float, nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    # Relationships
    user = relationship("User")

    def __repr__(self):
        return f"<AIChatMessage(id={self.id}, user_id={self.user_id}, role={self.role})>"
