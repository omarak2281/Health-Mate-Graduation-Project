"""
AI inference router for Symptom Checker
"""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_current_user
from app.models.user import User
from app.services.ai_service import get_symptom_checker, SymptomCheckerService
from app.schemas.ai import SymptomCheckRequest, SymptomCheckResponse, DiseaseInfo

router = APIRouter(prefix="/ai", tags=["AI Inference"])


@router.post("/symptom-checker", response_model=SymptomCheckResponse)
async def check_symptoms(
    request: SymptomCheckRequest,
    current_user: User = Depends(get_current_user),
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker)
):
    """
    AI-powered symptom checker
    
    - **symptoms**: List of symptoms (e.g., ["fever", "headache", "cough"])
    
    Returns predicted disease with confidence score
    
    ⚠️ **IMPORTANT**: This is for educational purposes only. 
    Always consult a healthcare professional for diagnosis.
    """
    # Get prediction
    result = symptom_checker.predict_disease(request.symptoms)
    
    if not result:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI model not available. Please ensure model files are in Symptom-Checker/Output/Production/"
        )
    
    # Get disease information
    disease_info_data = symptom_checker.get_disease_info(result["disease"])
    disease_info = None
    if disease_info_data:
        disease_info = DiseaseInfo(**disease_info_data)
    
    return SymptomCheckResponse(
        disease=result["disease"],
        confidence=result["confidence"],
        symptoms_matched=result["symptoms_matched"],
        model_version=result["model_version"],
        disease_info=disease_info
    )


@router.get("/available-symptoms")
async def get_available_symptoms(
    current_user: User = Depends(get_current_user),
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker)
):
    """
    Get list of available symptoms for selection
    
    Returns symptom vocabulary from model metadata
    """
    if not symptom_checker.metadata:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model metadata not available"
        )
    
    symptoms = symptom_checker.metadata.get("symptoms", [])
    
    return {
        "symptoms": symptoms,
        "total": len(symptoms)
    }


@router.get("/model-info")
async def get_model_info(
    current_user: User = Depends(get_current_user),
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker)
):
    """
    Get model information and statistics
    """
    if not symptom_checker.metadata:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model metadata not available"
        )
    
    return {
        "model_type": symptom_checker.metadata.get("model_type", "unknown"),
        "version": symptom_checker.metadata.get("version", "unknown"),
        "accuracy": symptom_checker.metadata.get("accuracy"),
        "diseases_count": len(symptom_checker.metadata.get("diseases", {})),
        "symptoms_count": len(symptom_checker.metadata.get("symptoms", []))
    }
@router.get("/symptom-checker/history/{session_id}")
async def get_chat_history(
    session_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get chat history for a specific symptom checker session
    
    Returns recent interactions (Mocked for now since DB persistence for AI chat not yet implemented)
    """
    # In a full implementation, you would query the database for this user and session
    return [
        {
            "role": "user",
            "message": "I have a fever and headache.",
            "timestamp": "2024-01-01T10:00:00Z"
        },
        {
            "role": "ai",
            "message": "Based on your symptoms, you might have a common cold. Please consult a doctor.",
            "timestamp": "2024-01-01T10:00:05Z"
        }
    ]
