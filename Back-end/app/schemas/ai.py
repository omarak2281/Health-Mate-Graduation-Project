"""
AI schemas for inference requests and responses
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict


class SymptomCheckRequest(BaseModel):
    """Symptom checker request"""
    symptoms: List[str] = Field(..., min_items=1, max_items=20)
    

class DiseaseInfo(BaseModel):
    """Disease information"""
    name: str
    description: Optional[str] = None
    treatment: Optional[str] = None
    precautions: Optional[List[str]] = None


class SymptomCheckResponse(BaseModel):
    """Symptom checker response"""
    disease: str
    confidence: Optional[float]
    symptoms_matched: int
    model_version: str
    disease_info: Optional[DiseaseInfo] = None
    disclaimer: str = "This is an AI prediction for educational purposes only. Please consult a healthcare professional for accurate diagnosis."
