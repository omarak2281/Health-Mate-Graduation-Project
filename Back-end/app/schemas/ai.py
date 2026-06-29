"""
AI schemas for inference requests and responses
"""

from pydantic import BaseModel, Field, ConfigDict
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
    severity: Optional[str] = None
    advice: Optional[str] = None


class SymptomCheckResponse(BaseModel):
    """Symptom checker response"""
    model_config = ConfigDict(protected_namespaces=())
    
    disease: str
    confidence: Optional[float]
    symptoms_matched: int
    model_version: str
    disease_info: Optional[DiseaseInfo] = None
    disclaimer: str = "This is an AI prediction for educational purposes only. Please consult a healthcare professional for accurate diagnosis."


class ChatRequest(BaseModel):
    """Chat request"""
    message: str
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    """Chat response"""
    message: str
    session_id: Optional[str] = None
    disease_info: Optional[DiseaseInfo] = None
    options: Optional[List[str]] = None
    found_symptoms: Optional[List[str]] = None


class SymptomCategory(BaseModel):
    """Symptom category with list of symptoms"""
    category: str
    icon: str  # Icon name for UI mapping
    symptoms: List[str]


class SymptomListResponse(BaseModel):
    """Categorized symptom list response - matches Flutter expected structure"""
    mapping: Dict[str, List[str]]  # e.g., {"Heart": [...], "General": [...]}
    categories: Dict[str, List[str]]  # e.g., {"General": [...], "Respiratory": [...]}
    all_symptoms: List[str]
    symptoms_data: Optional[Dict[str, List[Dict]]] = None  # Full symptom data with translations
