"""
Medication schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, time
from uuid import UUID


class MedicationCreate(BaseModel):
    """Create medication"""
    name: str = Field(..., min_length=1, max_length=255)
    dosage: str = Field(..., min_length=1, max_length=100)
    instructions: Optional[str] = None
    frequency: str = Field(..., max_length=50)
    time_slots: List[time]
    drawer_number: Optional[int] = Field(None, ge=1, le=20)
    enable_led: bool = True
    enable_buzzer: bool = True
    enable_notification: bool = True
    image_url: Optional[str] = None


class MedicationUpdate(BaseModel):
    """Update medication"""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    dosage: Optional[str] = Field(None, min_length=1, max_length=100)
    instructions: Optional[str] = None
    time_slots: Optional[List[time]] = None
    drawer_number: Optional[int] = Field(None, ge=1, le=20)
    is_active: Optional[bool] = None
    image_url: Optional[str] = None


class MedicationResponse(BaseModel):
    """Medication response"""
    id: UUID
    user_id: UUID
    name: str
    dosage: str
    instructions: Optional[str]
    frequency: str
    time_slots: List[time]
    drawer_number: Optional[int]
    is_active: bool
    enable_led: bool
    enable_buzzer: bool
    enable_notification: bool
    start_date: datetime
    end_date: Optional[datetime]
    image_url: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True
