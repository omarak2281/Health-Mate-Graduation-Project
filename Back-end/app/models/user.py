"""
User model with role-based access control
Supports Patient and Caregiver roles
"""

from sqlalchemy import Column, String, Boolean, DateTime, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum

from app.core.database import Base


class UserRole(str, enum.Enum):
    """User role enumeration"""
    PATIENT = "patient"
    CAREGIVER = "caregiver"


class User(Base):
    """
    User model
    
    Represents both patients and caregivers
    Role determines UI and permissions
    """
    __tablename__ = "users"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    
    # Authentication
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    
    # Firebase Authentication
    firebase_uid = Column(String(255), nullable=True, unique=True, index=True)
    auth_provider = Column(SQLEnum('email', 'google', name='authprovider'), nullable=True)
    email_verified_at = Column(DateTime, nullable=True)
    
    # Profile
    full_name = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=True)
    birth_date = Column(String(50), nullable=True)
    gender = Column(String(20), nullable=True)
    profile_image_url = Column(String(500), nullable=True)
    
    # Role
    role = Column(SQLEnum(UserRole), nullable=False, index=True)
    
    # Status
    is_active = Column(Boolean, default=True, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    
    # FCM Token for push notifications
    fcm_token = Column(String(500), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    last_login_at = Column(DateTime, nullable=True)
    
    # Relationships
    # Patient relationships (when user is patient)
    caregivers = relationship(
        "PatientCaregiverLink",
        foreign_keys="PatientCaregiverLink.patient_id",
        back_populates="patient",
        cascade="all, delete-orphan"
    )
    
    # Caregiver relationships (when user is caregiver)
    patients = relationship(
        "PatientCaregiverLink",
        foreign_keys="PatientCaregiverLink.caregiver_id",
        back_populates="caregiver",
        cascade="all, delete-orphan"
    )
    
    # Vital signs
    vitals = relationship("VitalSign", back_populates="user", cascade="all, delete-orphan")
    
    # Medications
    medications = relationship("Medication", back_populates="user", cascade="all, delete-orphan")
    
    # Medical contacts
    medical_contacts = relationship("MedicalContact", back_populates="user", cascade="all, delete-orphan")
    
    # Call sessions (as caller)
    calls_initiated = relationship(
        "CallSession",
        foreign_keys="CallSession.caller_id",
        back_populates="caller",
        cascade="all, delete-orphan"
    )
    
    # Call sessions (as callee)
    calls_received = relationship(
        "CallSession",
        foreign_keys="CallSession.callee_id",
        back_populates="callee",
        cascade="all, delete-orphan"
    )
    
    def __repr__(self):
        return f"<User(id={self.id}, email={self.email}, role={self.role})>"
