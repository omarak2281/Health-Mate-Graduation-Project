"""
Vital signs schemas
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID
from app.models.vital_sign import RiskLevel


class VitalSignCreate(BaseModel):
    """Create vital sign reading"""
    systolic: int = Field(..., ge=50, le=300)
    diastolic: int = Field(..., ge=30, le=200)
    heart_rate: Optional[int] = Field(None, ge=30, le=250)
    source: str = Field(default="manual", max_length=50)


class VitalSignResponse(BaseModel):
    """Vital sign response"""
    id: UUID
    user_id: UUID
    systolic: int
    diastolic: int
    heart_rate: Optional[int]
    risk_level: RiskLevel
    source: str
    confidence: Optional[float]
    signal_quality: Optional[float]
    measured_at: datetime
    created_at: datetime
    
    class Config:
        from_attributes = True
