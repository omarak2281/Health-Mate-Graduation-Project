"""
Medication schemas
"""

from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional, List
from datetime import datetime, time
from uuid import UUID


class MedicineCreate(BaseModel):
    """Create medication schema"""
    name: str = Field(..., min_length=1, max_length=255)
    image_url: Optional[str] = None
    instructions: Optional[str] = None
    dosage: str = Field(..., min_length=1)
    times_per_day: int = Field(..., ge=1, le=3)
    scheduled_times: List[str] = Field(..., description="List of times in HH:MM format")
    use_smart_box: bool = False
    drawer_number: Optional[int] = Field(None, ge=1, le=6)
    patient_id: Optional[UUID] = None

    @field_validator('scheduled_times')
    @classmethod
    def validate_times_format(cls, v):
        for t in v:
            try:
                datetime.strptime(t, "%H:%M")
            except ValueError:
                raise ValueError(f"Time '{t}' must be in HH:MM format")
        return v

    @model_validator(mode='after')
    def validate_logic(self) -> 'MedicineCreate':
        if self.use_smart_box and self.drawer_number is None:
            raise ValueError("drawer_number is required when use_smart_box is True")
        if len(self.scheduled_times) != self.times_per_day:
            raise ValueError(f"scheduled_times count ({len(self.scheduled_times)}) must match times_per_day ({self.times_per_day})")
        return self


class MedicationUpdate(BaseModel):
    """Update medication"""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    dosage: Optional[str] = Field(None, min_length=1)
    instructions: Optional[str] = None
    times_per_day: Optional[int] = Field(None, ge=1, le=3)
    scheduled_times: Optional[List[str]] = None
    use_smart_box: Optional[bool] = None
    drawer_number: Optional[int] = Field(None, ge=1, le=6)
    is_active: Optional[bool] = None
    image_url: Optional[str] = None

    @field_validator('scheduled_times')
    @classmethod
    def validate_times_format(cls, v):
        if v is None:
            return v
        for t in v:
            try:
                datetime.strptime(t, "%H:%M")
            except ValueError:
                raise ValueError(f"Time '{t}' must be in HH:MM format")
        return v


class MedicationResponse(BaseModel):
    """Medication response"""
    id: UUID
    user_id: UUID
    name: str
    dosage: str
    instructions: Optional[str]
    image_url: Optional[str]
    times_per_day: int
    scheduled_times: List[str]
    use_smart_box: bool
    drawer_number: Optional[int]
    is_active: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class MedicationAdherenceCreate(BaseModel):
    """Confirm medication taken"""
    image_url: Optional[str] = None
    taken_at: Optional[datetime] = None


class MedicationAdherenceResponse(BaseModel):
    """Adherence log response"""
    id: UUID
    medication_id: UUID
    taken_at: datetime
    image_url: Optional[str]
    
    class Config:
        from_attributes = True
