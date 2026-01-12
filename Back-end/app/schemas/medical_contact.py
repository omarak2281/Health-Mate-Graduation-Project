from pydantic import BaseModel, Field
from typing import Optional
from uuid import UUID
from datetime import datetime
from app.models.medical_contact import ContactType

class MedicalContactBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    phone: str = Field(..., min_length=1, max_length=50)
    contact_type: ContactType
    notes: Optional[str] = None

class MedicalContactCreate(MedicalContactBase):
    pass

class MedicalContactUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    contact_type: Optional[ContactType] = None
    notes: Optional[str] = None

class MedicalContactResponse(MedicalContactBase):
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
