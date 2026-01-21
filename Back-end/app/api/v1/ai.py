"""
AI inference router for Symptom Checker
"""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_current_user
from app.models.user import User
from app.services.ai_service import get_symptom_checker, SymptomCheckerService
from app.schemas.ai import (
    SymptomCheckRequest, 
    SymptomCheckResponse, 
    DiseaseInfo, 
    ChatRequest, 
    ChatResponse,
    SymptomCategory,
    SymptomListResponse
)


router = APIRouter(prefix="/ai", tags=["AI Inference"])

# Manual mapping of symptoms to categories for UI
# This maps exact internal symptom names to user-friendly categories
SYMPTOM_CATEGORIES_MAP = {
    "General": {
        "icon": "health_and_safety", 
        "keywords": ["fever", "fatigue", "chill", "sweat", "weight", "appetite", "weakness"]
    },
    "Respiratory": {
        "icon": "lungs", 
        "keywords": ["cough", "breath", "throat", "sneeze", "chest", "mucus", "sputum"]
    },
    "Heart & Cardio": {
        "icon": "favorite", 
        "keywords": ["heart", "pulse", "palpitation"]
    },
    "Digestive": {
        "icon": "stomach", 
        "keywords": ["stomach", "abdom", "vomit", "nausea", "diarrhea", "stool", "constipat", "gas", "indigestion"]
    },
    "Neurological": {
        "icon": "psychology", 
        "keywords": ["headache", "dizzi", "numb", "coma", "coordinat", "concentrat", "confusion"]
    },
    "Skin": {
        "icon": "dermatology", 
        "keywords": ["rash", "skin", "itch", "spot", "bruis", "blister", "yellow"]
    },
    "Musculoskeletal": {
        "icon": "accessibility_new", 
        "keywords": ["joint", "muscle", "pain", "back", "neck", "knee", "swelling_joints"]
    },
    "Other": {
        "icon": "healing",
        "keywords": []
    }
}

@router.get("/available-symptoms", response_model=SymptomListResponse)
async def get_available_symptoms(
    current_user: User = Depends(get_current_user),
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker)
):
    """
    Get list of available symptoms grouped by category
    """
    if not symptom_checker.metadata:
        # Try load
        symptom_checker.load_model()
        
    if not symptom_checker.metadata:
         raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model metadata not available"
        )
    
    all_symptoms = symptom_checker.metadata.get("symptoms", [])
    
    # Group symptoms
    categorized = {k: [] for k in SYMPTOM_CATEGORIES_MAP.keys()}
    used_symptoms = set()
    
    for symptom in all_symptoms:
        assigned = False
        s_clean = symptom.lower().replace("_", " ")
        
        for cat, info in SYMPTOM_CATEGORIES_MAP.items():
            if cat == "Other": continue
            
            # Check keywords
            for key in info["keywords"]:
                if key in s_clean:
                    categorized[cat].append(symptom)
                    used_symptoms.add(symptom)
                    assigned = True
                    break
            if assigned: break
            
        if not assigned:
            categorized["Other"].append(symptom)
            
    # Build response
    categories_list = []
    for cat, symptoms in categorized.items():
        if symptoms: # Only add if has symptoms
            categories_list.append(
                SymptomCategory(
                    category=cat,
                    icon=SYMPTOM_CATEGORIES_MAP[cat]["icon"],
                    symptoms=sorted(symptoms)
                )
            )
            
    return SymptomListResponse(
        categories=categories_list,
        all_symptoms=all_symptoms
    )



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



@router.post("/chat", response_model=ChatResponse)
async def chat_symptom_checker(
    request: ChatRequest,
    current_user: User = Depends(get_current_user),
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker)
):
    """
    Assistant-like chat interface for Symptom Checker
    """
    if not symptom_checker.metadata:
        # Try to load if not loaded
        if not symptom_checker.load_model():
             raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI model is not available."
            )

    # 1. Extract Symptoms from Message
    message = request.message.lower()
    known_symptoms = symptom_checker.metadata.get("symptoms", [])
    found_symptoms = []
    
    # Sort known symptoms by length (descending) to match "high fever" before "fever"
    sorted_symptoms = sorted(known_symptoms, key=len, reverse=True)
    
    for symptom in sorted_symptoms:
        symptom_clean = symptom.replace("_", " ")
        if symptom_clean in message or symptom in message:
            found_symptoms.append(symptom)
            
    # 2. Logic Branching
    if not found_symptoms:
        return ChatResponse(
            message="I'm listening. Please describe your symptoms clearly (e.g., 'I have high fever and cough').",
            session_id=request.session_id,
            options=["High Fever", "Cough", "Headache", "Fatigue", "Nausea"]
        )
        
    # 3. Predict
    result = symptom_checker.predict_disease(found_symptoms)
    
    if not result:
         return ChatResponse(
            message=f"I noted these symptoms: {', '.join(found_symptoms).replace('_', ' ')}. However, I can't determine a specific condition yet. Please provide more details or consult a doctor.",
            session_id=request.session_id
        )

    # 4. Success Response
    disease_name = result["disease"]
    confidence = result["confidence"]
    
    disease_info_data = symptom_checker.get_disease_info(disease_name)
    d_info = None
    if disease_info_data:
        d_info = DiseaseInfo(**disease_info_data)
        
    response_msg = f"Based on your symptoms ({', '.join(found_symptoms).replace('_', ' ')}), the analysis suggests: **{disease_name}**."
    
    if confidence:
        response_msg += f" (Confidence: {int(confidence * 100)}%)"
        
    if d_info and d_info.description:
        response_msg += f"\n\n{d_info.description}"

    response_msg += "\n\n⚠️ Disclaimer: This is for educational purposes only. Please consult a healthcare professional."

    return ChatResponse(
        message=response_msg,
        session_id=request.session_id,
        disease_info=d_info
    )




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
