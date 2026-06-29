"""
AI inference service for Symptom Checker
Integrates existing trained model from Symptom-Checker directory
"""

import joblib
import json
import os
from typing import List, Dict, Optional
from pathlib import Path

from app.core.config import settings


class SymptomCheckerService:
    """
    Symptom Checker AI model service
    
    Uses existing trained model from Symptom-Checker/Output/Production/
    Loads translations from Symptom-Checker/Data/ folder
    """
    
    def __init__(self):
        """Initialize model paths and translation data"""
        self.model_path = Path(settings.symptom_checker_model_path)
        self.model = None
        self.vectorizer = None
        self.metadata = None
        self.loaded = False
        
        # Translation data from JSON files
        self.symptom_translations: Dict[str, Dict] = {}
        self.disease_translations: Dict[str, Dict] = {}
        
        # Load translations on init
        self._load_translations()
    
    def _load_translations(self):
        """Load symptom and disease translations from Data folder"""
        try:
            # Determine base path for translations
            if os.path.exists("/app/Symptom-Checker"):
                base_path = Path("/app/Symptom-Checker/Data")
            else:
                # Get the project root from model path
                base_path = self.model_path.parent.parent / "Data"
            
            # Load General symptoms and diseases
            general_symptoms_file = base_path / "General" / "GeneralSymptoms.json"
            if general_symptoms_file.exists():
                with open(general_symptoms_file, 'r', encoding='utf-8') as f:
                    general_symptoms = json.load(f)
                    self.symptom_translations.update(general_symptoms)
                print(f"✅ Loaded {len(general_symptoms)} general symptoms")
            
            general_diseases_file = base_path / "General" / "GeneralDiseases.json"
            if general_diseases_file.exists():
                with open(general_diseases_file, 'r', encoding='utf-8') as f:
                    general_diseases = json.load(f)
                    self.disease_translations.update(general_diseases)
                print(f"✅ Loaded {len(general_diseases)} general diseases")
            
            # Load Heart symptoms and diseases
            heart_symptoms_file = base_path / "Heart" / "HeartSymptoms.json"
            if heart_symptoms_file.exists():
                with open(heart_symptoms_file, 'r', encoding='utf-8') as f:
                    heart_symptoms = json.load(f)
                    self.symptom_translations.update(heart_symptoms)
                print(f"✅ Loaded {len(heart_symptoms)} heart symptoms")
            
            heart_diseases_file = base_path / "Heart" / "HeartDiseases.json"
            if heart_diseases_file.exists():
                with open(heart_diseases_file, 'r', encoding='utf-8') as f:
                    heart_diseases = json.load(f)
                    self.disease_translations.update(heart_diseases)
                print(f"✅ Loaded {len(heart_diseases)} heart diseases")
            
            print(f"📚 Total translations: {len(self.symptom_translations)} symptoms, {len(self.disease_translations)} diseases")
            
        except Exception as e:
            print(f"⚠️ Error loading translations: {e}")
    
    def get_symptom_translation(self, symptom_name: str, language: str = "en") -> Dict:
        """Get symptom translation data"""
        # Try direct match first
        data = self.symptom_translations.get(symptom_name)
        
        # Robust fallback: case-insensitive and handles underscores/spaces
        if not data:
            search_name = symptom_name.lower().replace("_", " ").strip()
            for key in self.symptom_translations:
                key_clean = key.lower().replace("_", " ").strip()
                if key_clean == search_name:
                    data = self.symptom_translations[key]
                    break
        
        if not data: data = {}
        
        if language == "ar":
            return {
                "name": data.get("nameAr", symptom_name),
                "description": data.get("descriptionAr", data.get("description", "")),
                "severity": data.get("severity", "moderate"),
                "category": data.get("category", "General")
            }
        return {
            "name": symptom_name,
            "description": data.get("description", ""),
            "severity": data.get("severity", "moderate"),
            "category": data.get("category", "General")
        }
    
    def get_disease_translation(self, disease_name: str, language: str = "en") -> Dict:
        """Get disease translation data"""
        data = self.disease_translations.get(disease_name, {})
        related_symptoms = data.get("relatedSymptoms", [])
        
        # Expert Severity and Advice Mapping
        severity_map = {
            "low": {"en": "Low", "ar": "خفيفة"},
            "moderate": {"en": "Moderate", "ar": "متوسطة"},
            "high": {"en": "High", "ar": "خطيرة / طارئة"}
        }
        
        advice_map = {
            "low": {
                "en": "Rest and monitor your symptoms. Consult a doctor if they persist.",
                "ar": "يرجى الراحة ومراقبة أعراضك. استشر طبيباً إذا استمرت."
            },
            "moderate": {
                "en": "You should schedule a consultation with a healthcare professional soon.",
                "ar": "يجب عليك حجز موعد مع أخصائي رعاية صحية قريباً."
            },
            "high": {
                "en": "URGENT: Please seek medical attention immediately or go to the nearest emergency room.",
                "ar": "عاجل: يرجى التماس العناية الطبية فوراً أو الذهاب إلى أقرب غرفة طوارئ."
            }
        }
        
        raw_severity = data.get("severity", "moderate")
        translated_severity = severity_map.get(raw_severity, severity_map["moderate"])[language]
        advice = advice_map.get(raw_severity, advice_map["moderate"])[language]

        if language == "ar":
            translated_related = [
                self.get_symptom_translation(s, "ar")["name"]
                for s in related_symptoms
            ]
            return {
                "name": data.get("nameAr", disease_name),
                "description": data.get("descriptionAr", data.get("description", "")),
                "severity": translated_severity,
                "advice": advice,
                "precautions": translated_related
            }
            
        return {
            "name": disease_name,
            "description": data.get("description", ""),
            "severity": translated_severity,
            "advice": advice,
            "precautions": related_symptoms
        }
    
    def load_model(self):
        """
        Load trained model, vectorizer, and metadata
        """
        try:
            # Load model
            model_file = self.model_path / "best_model.pkl"
            if not model_file.exists():
                print(f"⚠️  Symptom Checker model not found at: {model_file}")
                return False
            
            self.model = joblib.load(model_file)
            print("✅ Symptom Checker model loaded")
            
            # Load vectorizer
            vectorizer_file = self.model_path / "vectorizer.pkl"
            if vectorizer_file.exists():
                self.vectorizer = joblib.load(vectorizer_file)
                print("✅ Vectorizer loaded")
            
            # Load metadata
            metadata_file = self.model_path / "model_metadata.json"
            if metadata_file.exists():
                with open(metadata_file, 'r', encoding='utf-8') as f:
                    self.metadata = json.load(f)
                print("✅ Model metadata loaded")
            
            self.loaded = True
            return True
            
        except Exception as e:
            print(f"❌ Error loading Symptom Checker model: {e}")
            return False
    
    def extract_symptoms(self, text: str) -> List[str]:
        """
        Extract known symptoms from natural language text.
        Returns a list of symptom keys.
        """
        if not text: return []
        
        raw_text = text.lower().strip()
        normalized_text = self._normalize_arabic(raw_text)
        
        known_symptoms = list(self.symptom_translations.keys())
        # Sort by length descending to match longer phrases first
        sorted_symptoms = sorted(known_symptoms, key=len, reverse=True)
        
        found = []
        # Track matched indices to avoid double-counting overlapping text
        # (though the sorted matching already helps)
        matched_text = normalized_text
        
        # Expert Medical Synonym Map (Expanded from master database + common verbs + prefixes)
        synonyms = {
            "Fever": ["temperature", "high heat", "حرارة", "سخونة", "حمى", "سخن", "سخونة عالية", "حرارتي مرتفعة", "عندي حرارة", "حاسس بحرارة"],
            "Cough": ["coughing", "hacking", "كحة", "سعال", "قحة", "بكح", "كح", "سعلة", "عندي كحة"],
            "Headache": ["head pain", "migraine", "صداع", "الم راس", "شقيقة", "راسي بيوجعني", "وجع راس", "عندي صداع", "بشعر بصداع"],
            "Fatigue": ["tired", "exhausted", "weakness", "تعب", "ارهاق", "خمول", "ارهاق", "تعبان", "حاسس بتعب", "عندي خمول"],
            "Abdominal Pain": ["stomach ache", "belly pain", "الم بطن", "مغص", "وجع بطن", "بطني بتوجعني", "مغص ببطني", "عندي وجع ببطني"],
            "Nausea": ["feeling sick", "vomit", "غثيان", "لوعة", "لعبان نفس", "نفسي لعية", "بدي استفرغ", "حاسس بغثيان"],
            "Shortness of Breath": ["breathing difficulty", "dyspnea", "ضيق تنفس", "كتمة", "نهجة", "مش قادر اتنفس", "نفسي ضيق", "عندي ضيق تنفس"],
            "Dizziness": ["vertigo", "lightheaded", "دوخة", "دوار", "دايخ", "حاسس الدنيا بتلف", "دوخة براسي", "عندي دوخة"],
            "Chest Pain": ["heart pain", "chest pressure", "الم صدر", "نغزة", "ضيق صدر", "صدري بيوجعني", "نغزة بقلبي", "عندي الم بصدري"],
            "Joint Pain": ["arthritis", "stiffness", "الم مفاصل", "خشونة", "وجع مفاصل", "مفاصلي بتوجعني", "عندي الم مفاصل"],
            "Skin Rash": ["eczema", "itching", "طفح جلدي", "حساسية", "حكة", "جلدي محمر", "بهرش", "عندي طفح"],
            "Jaundice": ["yellow skin", "yellow eyes", "يرقان", "ابو صفار", "اصفرار", "عيوني صفراء", "عندي صفار"],
            "Weight Loss": ["losing weight", "thinning", "فقدان وزن", "نحافة", "ضعفت", "وزني نزل", "عندي نقص وزن"],
            "Frequent Urination": ["polyuria", "bathroom often", "تبول متكرر", "كثرة تبول", "بدخل الحمام كتير", "عندي تبول كتير"],
            "Blood in Urine": ["hematuria", "red urine", "دم في البول", "بولي احمر", "عندي دم بالبول"],
            "Insomnia": ["can't sleep", "sleep problems", "ارق", "ما انام", "قلة نوم", "مش عارف انام", "عندي ارق"],
        }

        # Words to ignore (conversational fillers that shouldn't be symptoms)
        ignore_words = ["نعم", "لا", "yes", "no", "ok", "حسنا"]

        for symptom in sorted_symptoms:
            s_data = self.get_symptom_translation(symptom, "en")
            s_ar_data = self.get_symptom_translation(symptom, "ar")
            
            # Match variants
            variants = [
                symptom.lower().replace("_", " "),
                s_data["name"].lower(),
                self._normalize_arabic(s_ar_data["name"])
            ]
            
            # Add synonyms if available
            if symptom in synonyms:
                variants.extend(synonyms[symptom])

            for variant in variants:
                v_norm = self._normalize_arabic(variant)
                if v_norm in ignore_words: continue # Skip ignore words
                
                # Check normalized and raw text
                if v_norm in matched_text or variant.lower() in raw_text:
                    found.append(symptom)
                    break
        
        return list(dict.fromkeys(found))

    def _normalize_arabic(self, text: str) -> str:
        """Helper to normalize Arabic text and remove definite articles"""
        if not text: return ""
        # Basic normalization
        text = text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
        text = text.replace("ة", "ه").replace("ى", "ي")
        
        # Expert logic: Remove definite article "ال" if it's at the start of a word
        # but only if the word is long enough to avoid removing "Al" from "Allah" etc.
        words = text.split()
        normalized_words = []
        for w in words:
            if w.startswith("ال") and len(w) > 3:
                normalized_words.append(w[2:])
            else:
                normalized_words.append(w)
        
        return " ".join(normalized_words).strip().lower()

    def predict_disease(self, symptoms: List[str]) -> Optional[Dict]:
        """
        Predict disease from symptoms
        
        Args:
            symptoms: List of symptom strings
        
        Returns:
            Dict with prediction results or None
        """
        if not self.loaded:
            if not self.load_model():
                return None
        
        try:
            # Join symptoms into single string
            symptoms_text = " ".join(symptoms)
            
            # Vectorize input
            if self.vectorizer:
                symptoms_vector = self.vectorizer.transform([symptoms_text])
            else:
                # Fallback if no vectorizer
                symptoms_vector = [symptoms_text]
            
            # Make prediction
            prediction = self.model.predict(symptoms_vector)[0]
            
            # Get prediction probability if available
            confidence = None
            if hasattr(self.model, 'predict_proba'):
                probabilities = self.model.predict_proba(symptoms_vector)[0]
                confidence = float(max(probabilities))
            
            return {
                "disease": prediction,
                "confidence": confidence,
                "symptoms_matched": len(symptoms),
                "model_version": self.metadata.get("version", "2.0.1") if self.metadata else "2.0.1"
            }
            
        except Exception as e:
            print(f"Error during prediction: {e}")
            return None
    
    def get_disease_info(self, disease_name: str) -> Optional[Dict]:
        """
        Get educational information about disease
        
        Args:
            disease_name: Name of disease
        
        Returns:
            Disease information from metadata
        """
        if not self.metadata:
            return None
        
        # Search in metadata for disease info
        diseases = self.metadata.get("diseases", {})
        return diseases.get(disease_name)


# Singleton instance
symptom_checker = SymptomCheckerService()

# Load model immediately on module import
try:
    print("🔄 Loading AI model at module import...")
    if not symptom_checker.loaded:
        success = symptom_checker.load_model()
        if success:
            print("✅ AI model loaded successfully at import")
        else:
            print("⚠️ Failed to load AI model at import")
except Exception as e:
    print(f"❌ Error during model load at import: {e}")


def get_symptom_checker() -> SymptomCheckerService:
    """Get Symptom Checker service instance"""
    if not symptom_checker.loaded:
        symptom_checker.load_model()
    return symptom_checker
