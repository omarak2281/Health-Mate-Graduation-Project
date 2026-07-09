"""
Import all models for Alembic migrations
"""

from app.core.database import Base
from app.models.user import User, UserRole
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.models.vital_sign import VitalSign, RiskLevel
from app.models.medication import Medication
from app.models.medication_adherence import MedicationAdherence
from app.models.call_session import CallSession, CallType, CallStatus
from app.models.medical_contact import MedicalContact, ContactType
from app.models.notification import Notification, NotificationType
from app.models.iot_device import IoTDevice, MedicineBoxDrawer, DeviceType, DeviceStatus
from app.models.registered_device import RegisteredDevice
from app.models.patient_calibration import PatientCalibration, CalibrationSample
from app.models.bp_reminder import BPReminder
from app.models.audit_log import AuditLog
from app.models.symptom_assessment import (
    Assessment,
    AssessmentSymptom,
    RedFlagTriggered,
    SymptomChatMessage,
    SymptomChatSession,
)

__all__ = [
    "Base",
    "User",
    "UserRole",
    "PatientCaregiverLink",
    "VitalSign",
    "RiskLevel",
    "Medication",
    "MedicationAdherence",
    "CallSession",
    "CallType",
    "CallStatus",
    "MedicalContact",
    "ContactType",
    "Notification",
    "NotificationType",
    "IoTDevice",
    "MedicineBoxDrawer",
    "DeviceType",
    "DeviceStatus",
    "RegisteredDevice",
    "PatientCalibration",
    "CalibrationSample",
    "BPReminder",
    "AuditLog",
    "Assessment",
    "AssessmentSymptom",
    "RedFlagTriggered",
    "SymptomChatSession",
    "SymptomChatMessage",
]
