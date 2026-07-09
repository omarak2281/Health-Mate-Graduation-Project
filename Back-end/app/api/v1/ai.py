"""
AI inference router for Symptom Checker
"""

from time import perf_counter
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.user import User
from app.services.notification_service import NotificationService, get_notification_service
from app.services.ai_service import get_symptom_checker, symptom_checker, SymptomCheckerService
from app.schemas.ai import (
    SymptomCheckRequest,
    SymptomCheckResponse,
    DiseaseInfo,
    ChatRequest,
    ChatResponse,
    SymptomCategory,
    SymptomListResponse
)

from app.api.schemas.assessment_schemas import AssessmentRequestSchema, CaregiverNotificationResponse
from app.api.schemas.category_schemas import CategoryResponse, SymptomResponse
from app.application.dto.assessment_dto import AssessmentResultDTO
from app.application.use_cases.get_available_symptoms import get_available_symptoms as get_available_symptoms_v2
from app.application.use_cases.get_categories import get_categories as get_categories_use_case
from app.application.use_cases.run_assessment import run_assessment
from app.application.use_cases.run_bp_triage import run_bp_triage
from app.application.use_cases.start_chat_from_assessment import start_chat_from_assessment
from app.core.di import (
    get_assessment_phraser,
    get_assessment_repository,
    get_chat_sessions,
    get_disease_classifier,
    get_taxonomy_repository,
)
from app.domain.entities.assessment import AssessmentInput
from app.application.interfaces.assessment_phraser import AssessmentPhraser
from app.application.services.symptom_checker_metrics import rollout_metrics
from app.domain.interfaces.assessment_repository import AssessmentRepository
from app.domain.interfaces.chat_session_repository import ChatSessionRepository
from app.domain.interfaces.disease_classifier import DiseaseClassifier
from app.domain.interfaces.taxonomy_repository import TaxonomyRepository


router = APIRouter(prefix="/ai", tags=["AI Inference"])


def require_symptom_checker_v2_enabled() -> None:
    if not settings.symptom_checker_v2_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "error_code": "symptom_checker_v2_disabled",
                "message": "Structured symptom checker is currently disabled.",
            },
        )


def _user_id_or_none(current_user: User) -> UUID | None:
    return getattr(current_user, "id", None)


def _assessment_persistence_payload(
    payload: AssessmentRequestSchema,
    result: AssessmentResultDTO,
    current_user: User,
    lang: str,
    assessment_type: str,
) -> dict:
    return {
        "user_id": _user_id_or_none(current_user),
        "lang": lang,
        "assessment_type": assessment_type,
        "request": payload.model_dump(mode="json"),
        "result": result.model_dump(),
    }


def _should_notify_from_result(result: AssessmentResultDTO) -> bool:
    return result.should_notify_caregiver or result.urgency in {"high", "critical"}


async def _notify_caregivers_from_assessment_result(
    db: AsyncSession,
    current_user: User,
    result: AssessmentResultDTO,
    notification_service: NotificationService,
    assessment_id: UUID | None = None,
    manual: bool = False,
    lang: str = "en",
) -> int:
    user_id = _user_id_or_none(current_user)
    if user_id is None:
        return 0
    return await notification_service.send_symptom_assessment_alert(
        db=db,
        patient_id=str(user_id),
        urgency=result.urgency,
        caregiver_summary=result.caregiver_summary,
        recommended_action=result.recommended_action_text,
        red_flags=[flag.code for flag in result.red_flags],
        assessment_id=str(assessment_id) if assessment_id else None,
        manual=manual,
        lang=lang,
    )


@router.on_event("startup")
async def load_ai_model():
    """Load AI model on startup"""
    print("🔄 Loading AI model on startup...")
    if not symptom_checker.loaded:
        success = symptom_checker.load_model()
        if success:
            print("✅ AI model loaded successfully on startup")
        else:
            print("⚠️  Failed to load AI model on startup")

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
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker),
    lang: str = "en"
):
    """
    Get list of available symptoms grouped by category with translations
    
    - **lang**: Language code ('en' for English, 'ar' for Arabic)
    """
    if not symptom_checker.metadata:
        symptom_checker.load_model()
        
    if not symptom_checker.metadata:
         raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model metadata not available"
        )
    
    # Get all symptoms with translations
    all_symptoms = list(symptom_checker.symptom_translations.keys())
    
    # Group symptoms by category
    categorized = {k: [] for k in SYMPTOM_CATEGORIES_MAP.keys()}
    
    for symptom in all_symptoms:
        assigned = False
        s_clean = symptom.lower().replace("_", " ")
        translation = symptom_checker.get_symptom_translation(symptom, lang)
        symptom_data = {
            "id": symptom,
            "name": translation["name"],
            "description": translation["description"],
            "severity": translation["severity"],
            "category": translation["category"]
        }
        
        for cat, info in SYMPTOM_CATEGORIES_MAP.items():
            if cat == "Other": continue
            
            for key in info["keywords"]:
                if key in s_clean:
                    categorized[cat].append(symptom_data)
                    assigned = True
                    break
            if assigned: break
            
        if not assigned:
            categorized["Other"].append(symptom_data)
    
    # Build response with translations
    mapping = {
        "Heart": ["Coronary Artery Disease", "Heart Failure"],
        "General": ["Respiratory Infection", "Gastrointestinal"]
    }
    
    # Build categories dict with translated symptom names
    categories_dict = {}
    for cat, symptoms in categorized.items():
        if symptoms:
            categories_dict[cat] = [s["name"] for s in symptoms]
            
    return {
        "mapping": mapping,
        "categories": categories_dict,
        "all_symptoms": [s["name"] for s in sum(categorized.values(), [])],
        "symptoms_data": categorized  # Full data with translations
    }



@router.post("/symptom-checker", response_model=SymptomCheckResponse)
async def check_symptoms(
    request: SymptomCheckRequest,
    current_user: User = Depends(get_current_user),
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker),
    lang: str = "en"
):
    """
    AI-powered symptom checker with translations
    
    - **symptoms**: List of symptoms (e.g., ["fever", "headache", "cough"])
    - **lang**: Language code ('en' or 'ar')
    
    Returns predicted disease with confidence score and translations
    """
    # Get prediction
    result = symptom_checker.predict_disease(request.symptoms)
    
    if not result:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI model not available. Please ensure model files are in Symptom-Checker/Output/Production/"
        )
    
    # Get disease translation
    disease_translation = symptom_checker.get_disease_translation(result["disease"], lang)
    
    # Build disease info with translation
    disease_info = DiseaseInfo(
        name=disease_translation["name"],
        description=disease_translation["description"],
        treatment=None,
        precautions=disease_translation.get("relatedSymptoms", [])
    )
    
    return SymptomCheckResponse(
        disease=disease_translation["name"],
        confidence=result["confidence"],
        symptoms_matched=result["symptoms_matched"],
        model_version=result["model_version"],
        disease_info=disease_info
    )

def normalize_arabic(text: str) -> str:
    """Normalize Arabic text for better matching"""
    if not text: return ""
    # Normalize Alifs
    text = text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    # Normalize Ta Marbuta
    text = text.replace("ة", "ه")
    # Normalize Alif Maqsura
    text = text.replace("ى", "ي")
    return text.strip().lower()

@router.post("/chat", response_model=ChatResponse)
async def chat_symptom_checker(
    request: ChatRequest,
    current_user: User = Depends(get_current_user),
    symptom_checker: SymptomCheckerService = Depends(get_symptom_checker),
    chat_sessions: ChatSessionRepository = Depends(get_chat_sessions),
    lang: str = "en"
):
    """
    Assistant-like chat interface for Symptom Checker with translations
    """
    if not symptom_checker.metadata:
        if not symptom_checker.load_model():
             raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI model is not available."
            )

    session_id = request.session_id or "default"
    session = chat_sessions.get(session_id)
    if session is None:
        session = {"symptoms": [], "state": "INITIAL"}
        chat_sessions.create(session_id, session)
    
    # 1. Automatic Symptom Extraction from Message
    raw_message = request.message.lower().strip()
    
    # Binary Choice Handling
    yes_words = ["نعم", "yes", "confirm", "ok", "yep"]
    no_words = ["لا", "no", "nah", "stop", "finish"]
    
    is_yes = any(word in raw_message for word in yes_words)
    is_no = any(word in raw_message for word in no_words)

    # State Machine Logic
    if is_no:
        # "No" or "No more" always triggers final diagnosis if we have symptoms
        if session["symptoms"]:
            return await generate_final_diagnosis(session_id, session["symptoms"], lang, symptom_checker, chat_sessions)
        else:
            return ChatResponse(
                message="يرجى ذكر بعض الأعراض أولاً لنتمكن من مساعدتك." if lang == "ar" else "Please describe some symptoms first so we can help you.",
                session_id=session_id,
                found_symptoms=[]
            )

    # Use Service for extraction
    new_found = symptom_checker.extract_symptoms(request.message)
    for symptom in new_found:
        if symptom not in session["symptoms"]:
            session["symptoms"].append(symptom)
    chat_sessions.create(session_id, session)
            
    # 2. Check if we have symptoms
    all_session_symptoms = session["symptoms"]
    
    if not all_session_symptoms:
        common_symptoms = ["Fever", "Cough", "Headache", "Fatigue", "Nausea"]
        translated_common = [symptom_checker.get_symptom_translation(s, lang)["name"] for s in common_symptoms]
        return ChatResponse(
            message="أنا أسمعك بوضوح. يرجى وصف أعراضك بدقة لمساعدتك (مثل: أشعر بصداع شديد وحمى)." if lang == "ar" else "I'm listening. Please describe your symptoms clearly (e.g., 'I have high fever and cough').",
            session_id=session_id,
            options=translated_common[:5],
            found_symptoms=[]
        )

    # 3. Direct Suggestions Branch (No more binary Yes/No step)
    # The suggestions will include a "No" option to finish and analyze
    return await generate_suggestions(session_id, all_session_symptoms, lang, symptom_checker, chat_sessions)


async def generate_suggestions(session_id, symptoms, lang, symptom_checker, chat_sessions: ChatSessionRepository):
    result = symptom_checker.predict_disease(symptoms)
    suggestions = []
    if result and result.get("disease"):
        target_disease = result.get("disease")
        d_data = symptom_checker.disease_translations.get(target_disease, {})
        suggestions = d_data.get("relatedSymptoms", [])
    
    session_norm = [s.lower().replace("_", " ") for s in symptoms]
    filtered_suggestions = [s for s in suggestions if s.lower().replace("_", " ") not in session_norm]
    filtered_suggestions = list(dict.fromkeys(filtered_suggestions))
    
    translated_suggestions = [symptom_checker.get_symptom_translation(s, lang)["name"] for s in filtered_suggestions[:6]]
    translated_all = [symptom_checker.get_symptom_translation(s, lang)["name"] for s in symptoms]

    if lang == "ar":
        msg = "يرجى اختيار أي من هذه الأعراض إذا كانت لديك، أو اذكر المزيد من الأعراض:"
        # Professional Exit Option
        translated_suggestions.append("لا")
    else:
        msg = "Please choose any of these symptoms if you have them, or describe more symptoms:"
        translated_suggestions.append("No")

    # Move back to INITIAL state to allow more input or selection
    # But we stay in a "context" where a "No" input triggers diagnosis
    session = chat_sessions.get(session_id) or {"symptoms": symptoms, "state": "INITIAL"}
    session["state"] = "INITIAL"
    session["symptoms"] = symptoms
    chat_sessions.create(session_id, session)

    return ChatResponse(
        message=msg,
        session_id=session_id,
        options=translated_suggestions,
        found_symptoms=translated_all
    )

async def generate_final_diagnosis(session_id, symptoms, lang, symptom_checker, chat_sessions: ChatSessionRepository):
    result = symptom_checker.predict_disease(symptoms)
    disease_translation = symptom_checker.get_disease_translation(result["disease"], lang)
    disease_name = disease_translation["name"]
    
    d_info = DiseaseInfo(
        name=disease_name,
        description=disease_translation.get("description", ""),
        severity=disease_translation.get("severity"),
        advice=disease_translation.get("advice"),
        precautions=disease_translation.get("precautions", [])
    )
    
    translated_all = [symptom_checker.get_symptom_translation(s, lang)["name"] for s in symptoms]
    
    if lang == "ar":
        response_msg = f"بناءً على أعراضك ({', '.join(translated_all)})، التشخيص الأكثر احتمالاً هو: **{disease_name}**."
        response_msg += f"\n\n**النصيحة الطبية:** {d_info.advice}"
        response_msg += "\n\n⚠️ إخلاء مسؤولية: هذا تقييم ذكاء اصطناعي للأغراض التعليمية فقط. يرجى استشارة الطبيب."
    else:
        response_msg = f"Based on your symptoms ({', '.join(translated_all)}), the most likely diagnosis is: **{disease_name}**."
        response_msg += f"\n\n**Medical Advice:** {d_info.advice}"
        response_msg += "\n\n⚠️ Disclaimer: This is for educational purposes only. Please consult a healthcare professional."

    # Clear session
    chat_sessions.create(session_id, {"symptoms": [], "state": "INITIAL"})

    return ChatResponse(
        message=response_msg,
        session_id=session_id,
        disease_info=d_info,
        found_symptoms=translated_all
    )

    return ChatResponse(
        message=response_msg,
        session_id=session_id,
        disease_info=d_info,
        found_symptoms=translated_all
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
        "diseases_count": len(symptom_checker.metadata.get("disease_translations", {})),
        "symptoms_count": len(symptom_checker.metadata.get("symptom_translations", {}))
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


# --- Phase 5: new structured-assessment endpoints (plan §6.1) ---------------------------
# Deliberately additive: none of the routes above are modified, so the existing
# AiSymptomChatPage/SymptomCheckerPage keep working unchanged (plan §3.2). One documented path
# deviation from the plan's literal spec: `GET /available-symptoms` already exists above with
# a different response shape consumed by the current SymptomCheckerPage — reusing that exact
# path for the new taxonomy-based listing would silently break it. The new listing is exposed
# at `/taxonomy/symptoms` instead; see Plans/SYMPTOM_CHECKER_PROGRESS.md Phase 5 for the full
# rationale.


@router.get("/categories", response_model=list[CategoryResponse])
async def get_categories_v2(
    lang: str = "en",
    _v2_enabled: None = Depends(require_symptom_checker_v2_enabled),
    current_user: User = Depends(get_current_user),
    taxonomy: TaxonomyRepository = Depends(get_taxonomy_repository),
):
    """GET /api/v1/ai/categories?lang=ar|en — plan §6.1."""
    return get_categories_use_case(taxonomy, lang="ar" if lang == "ar" else "en")


@router.get("/taxonomy/symptoms", response_model=list[SymptomResponse])
async def get_taxonomy_symptoms(
    category_id: str | None = None,
    lang: str = "en",
    _v2_enabled: None = Depends(require_symptom_checker_v2_enabled),
    current_user: User = Depends(get_current_user),
    taxonomy: TaxonomyRepository = Depends(get_taxonomy_repository),
):
    """GET /api/v1/ai/taxonomy/symptoms?category_id=&lang= — plan §6.1's `available-symptoms`
    shape, exposed at this path instead (see module note above)."""
    return get_available_symptoms_v2(taxonomy, category_id=category_id, lang="ar" if lang == "ar" else "en")


def _to_domain_assessment(payload: AssessmentRequestSchema) -> AssessmentInput:
    if not payload.symptoms:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error_code": "no_symptoms_selected", "message": "Please select at least one symptom."},
        )
    return AssessmentInput(**payload.model_dump())


@router.post("/assessment", response_model=AssessmentResultDTO)
async def post_assessment(
    payload: AssessmentRequestSchema,
    lang: str = "en",
    _v2_enabled: None = Depends(require_symptom_checker_v2_enabled),
    current_user: User = Depends(get_current_user),
    taxonomy: TaxonomyRepository = Depends(get_taxonomy_repository),
    classifier: DiseaseClassifier = Depends(get_disease_classifier),
    phraser: AssessmentPhraser = Depends(get_assessment_phraser),
    assessments: AssessmentRepository = Depends(get_assessment_repository),
    db: AsyncSession = Depends(get_db),
    notification_service: NotificationService = Depends(get_notification_service),
):
    """POST /api/v1/ai/assessment?lang=ar|en — plan §6.1."""
    started_at = perf_counter()
    resolved_lang = "ar" if lang == "ar" else "en"
    assessment = _to_domain_assessment(payload)
    result = run_assessment(assessment, taxonomy, classifier, lang=resolved_lang, phraser=phraser)
    assessment_id = uuid4()
    await assessments.save(
        assessment_id,
        _assessment_persistence_payload(payload, result, current_user, resolved_lang, "symptom_checker"),
    )
    notified_count = 0
    if _should_notify_from_result(result):
        notified_count = await _notify_caregivers_from_assessment_result(
            db,
            current_user,
            result,
            notification_service,
            assessment_id=assessment_id,
            manual=False,
            lang=resolved_lang,
        )
    rollout_metrics.record_assessment(
        result,
        latency_ms=(perf_counter() - started_at) * 1000,
        caregiver_notified=notified_count > 0,
    )
    return result


@router.post("/bp-triage", response_model=AssessmentResultDTO)
async def post_bp_triage(
    payload: AssessmentRequestSchema,
    lang: str = "en",
    _v2_enabled: None = Depends(require_symptom_checker_v2_enabled),
    current_user: User = Depends(get_current_user),
    taxonomy: TaxonomyRepository = Depends(get_taxonomy_repository),
    classifier: DiseaseClassifier = Depends(get_disease_classifier),
    phraser: AssessmentPhraser = Depends(get_assessment_phraser),
    assessments: AssessmentRepository = Depends(get_assessment_repository),
):
    """POST /api/v1/ai/bp-triage?lang=ar|en — plan §6.1 + §8 BP integration hook."""
    started_at = perf_counter()
    resolved_lang = "ar" if lang == "ar" else "en"
    assessment = _to_domain_assessment(payload)
    result = run_bp_triage(assessment, taxonomy, classifier, lang=resolved_lang, phraser=phraser)
    await assessments.save(
        uuid4(),
        _assessment_persistence_payload(payload, result, current_user, resolved_lang, "bp_triage"),
    )
    rollout_metrics.record_assessment(
        result,
        latency_ms=(perf_counter() - started_at) * 1000,
        caregiver_notified=False,
    )
    return result


@router.post("/chat/from-assessment")
async def post_chat_from_assessment(
    payload: AssessmentRequestSchema,
    lang: str = "en",
    _v2_enabled: None = Depends(require_symptom_checker_v2_enabled),
    current_user: User = Depends(get_current_user),
    taxonomy: TaxonomyRepository = Depends(get_taxonomy_repository),
    classifier: DiseaseClassifier = Depends(get_disease_classifier),
    phraser: AssessmentPhraser = Depends(get_assessment_phraser),
    chat_sessions: ChatSessionRepository = Depends(get_chat_sessions),
    assessments: AssessmentRepository = Depends(get_assessment_repository),
):
    """POST /api/v1/ai/chat/from-assessment?lang=ar|en — plan §6.1, returns `{"assessment_id"}`."""
    resolved_lang = "ar" if lang == "ar" else "en"
    assessment = _to_domain_assessment(payload)
    result = run_assessment(assessment, taxonomy, classifier, lang=resolved_lang, phraser=phraser)
    assessment_id = uuid4()
    await assessments.save(
        assessment_id,
        _assessment_persistence_payload(payload, result, current_user, resolved_lang, "symptom_checker_chat_seed"),
    )
    session_id = start_chat_from_assessment(result, chat_sessions, lang=resolved_lang, assessment_id=str(assessment_id))
    await assessments.save_chat_seed(
        assessment_id,
        {
            "user_id": _user_id_or_none(current_user),
            "assessment_id": assessment_id,
            "state": "INITIAL",
            "seeded_from_assessment": True,
            "lang": resolved_lang,
            "context": {"seed_context": result.model_dump()},
        },
    )
    return {"assessment_id": session_id}


@router.post("/assessment/notify-caregiver", response_model=CaregiverNotificationResponse)
async def post_assessment_notify_caregiver(
    payload: AssessmentRequestSchema,
    lang: str = "en",
    _v2_enabled: None = Depends(require_symptom_checker_v2_enabled),
    current_user: User = Depends(get_current_user),
    taxonomy: TaxonomyRepository = Depends(get_taxonomy_repository),
    classifier: DiseaseClassifier = Depends(get_disease_classifier),
    phraser: AssessmentPhraser = Depends(get_assessment_phraser),
    notification_service: NotificationService = Depends(get_notification_service),
    db: AsyncSession = Depends(get_db),
):
    """Send the current guided assessment summary to all linked caregivers."""
    resolved_lang = "ar" if lang == "ar" else "en"
    assessment = _to_domain_assessment(payload)
    result = run_assessment(assessment, taxonomy, classifier, lang=resolved_lang, phraser=phraser)
    notified_count = await _notify_caregivers_from_assessment_result(
        db,
        current_user,
        result,
        notification_service,
        manual=True,
        lang=resolved_lang,
    )
    return CaregiverNotificationResponse(notified_count=notified_count, auto_triggered=False)


@router.get("/assessment/rollout-metrics")
async def get_assessment_rollout_metrics(
    current_user: User = Depends(get_current_user),
):
    """Phase 12 rollout monitor: distribution, red-flag rate, caregiver notify rate, latency."""
    return rollout_metrics.snapshot()
