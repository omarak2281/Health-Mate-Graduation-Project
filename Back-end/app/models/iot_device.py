"""
IoT device models for sensors and medicine box
"""

from sqlalchemy import Column, ForeignKey, String, Integer, Float, Boolean, DateTime, Enum as SQLEnum, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum

from app.core.database import Base


class DeviceType(str, enum.Enum):
    """Type of IoT device"""
    PPG_SENSOR = "ppg_sensor"
    ECG_SENSOR = "ecg_sensor"
    MEDICINE_BOX = "medicine_box"


class DeviceStatus(str, enum.Enum):
    """Device connection status"""
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    UNSTABLE = "unstable"


class IoTDevice(Base):
    """
    IoT device model
    
    Registers IoT devices (sensors, medicine box)
    Tracks connection status
    """
    __tablename__ = "iot_devices"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Key
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Device Info
    device_type = Column(SQLEnum(DeviceType), nullable=False)
    device_name = Column(String(255), nullable=False)
    device_serial = Column(String(255), unique=True, nullable=False)
    
    # Status
    status = Column(SQLEnum(DeviceStatus), nullable=False, default=DeviceStatus.DISCONNECTED)
    signal_quality = Column(Float, nullable=True)  # 0.0 to 1.0
    
    # Last Communication
    last_ping_at = Column(DateTime, nullable=True)
    
    # Timestamps
    registered_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User")
    
    def __repr__(self):
        return f"<IoTDevice(type={self.device_type}, status={self.status}, user={self.user_id})>"


class MedicineBoxDrawer(Base):
    """
    Medicine box drawer model
    
    Tracks individual drawers in medicine box
    Each drawer can be assigned to a medication
    """
    __tablename__ = "medicine_box_drawers"
    
    # Primary Key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Foreign Key
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Drawer Info
    drawer_number = Column(Integer, nullable=False)  # 1, 2, 3, etc.
    
    # Status
    is_occupied = Column(Boolean, default=False, nullable=False)
    led_active = Column(Boolean, default=False, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User")
    
    def __repr__(self):
        return f"<MedicineBoxDrawer(drawer={self.drawer_number}, occupied={self.is_occupied})>"
