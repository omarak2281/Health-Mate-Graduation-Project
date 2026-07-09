"""
Persistence models for Symptom Checker v2 assessments and chat sessions.
"""
from datetime import datetime
import uuid

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class Assessment(Base):
    __tablename__ = "assessments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    source_vital_id = Column(UUID(as_uuid=True), ForeignKey("vital_signs.id", ondelete="SET NULL"), nullable=True, index=True)
    assessment_type = Column(String(50), nullable=False, default="symptom_checker")
    category_id = Column(String(100), nullable=True, index=True)
    duration_days = Column(Integer, nullable=True)
    age_group = Column(String(50), nullable=True)
    known_conditions = Column(JSONB, nullable=False, default=list)
    vitals = Column(JSONB, nullable=True)
    top_predictions = Column(JSONB, nullable=False, default=list)
    urgency = Column(String(20), nullable=False, index=True)
    urgency_label = Column(String(100), nullable=False)
    recommended_action_code = Column(String(100), nullable=False)
    recommended_action_text = Column(Text, nullable=False)
    patient_message = Column(Text, nullable=False)
    caregiver_summary = Column(Text, nullable=False)
    should_notify_caregiver = Column(Boolean, nullable=False, default=False)
    should_remeasure = Column(Boolean, nullable=False, default=False)
    disclaimer = Column(Text, nullable=False)
    lang = Column(String(5), nullable=False, default="en")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    symptoms = relationship("AssessmentSymptom", back_populates="assessment", cascade="all, delete-orphan")
    red_flags = relationship("RedFlagTriggered", back_populates="assessment", cascade="all, delete-orphan")
    chat_sessions = relationship("SymptomChatSession", back_populates="assessment")


class AssessmentSymptom(Base):
    __tablename__ = "assessment_symptoms"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    assessment_id = Column(UUID(as_uuid=True), ForeignKey("assessments.id", ondelete="CASCADE"), nullable=False, index=True)
    symptom_id = Column(String(100), nullable=False, index=True)
    severity = Column(Integer, nullable=False)

    assessment = relationship("Assessment", back_populates="symptoms")


class RedFlagTriggered(Base):
    __tablename__ = "red_flags_triggered"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    assessment_id = Column(UUID(as_uuid=True), ForeignKey("assessments.id", ondelete="CASCADE"), nullable=False, index=True)
    code = Column(String(100), nullable=False, index=True)
    severity = Column(Integer, nullable=False)

    assessment = relationship("Assessment", back_populates="red_flags")


class SymptomChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    assessment_id = Column(UUID(as_uuid=True), ForeignKey("assessments.id", ondelete="SET NULL"), nullable=True, index=True)
    state = Column(String(50), nullable=False, default="INITIAL")
    seeded_from_assessment = Column(Boolean, nullable=False, default=False)
    lang = Column(String(5), nullable=False, default="en")
    context = Column(JSONB, nullable=False, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    assessment = relationship("Assessment", back_populates="chat_sessions")
    messages = relationship("SymptomChatMessage", back_populates="session", cascade="all, delete-orphan")


class SymptomChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("chat_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(20), nullable=False)
    message = Column(Text, nullable=False)
    payload = Column(JSONB, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    session = relationship("SymptomChatSession", back_populates="messages")
