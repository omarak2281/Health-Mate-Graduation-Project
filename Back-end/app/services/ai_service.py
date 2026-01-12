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
    """
    
    def __init__(self):
        """Initialize model paths"""
        self.model_path = Path(settings.symptom_checker_model_path)
        self.model = None
        self.vectorizer = None
        self.metadata = None
        self.loaded = False
    
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
                "model_version": self.metadata.get("version") if self.metadata else "unknown"
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


def get_symptom_checker() -> SymptomCheckerService:
    """Get Symptom Checker service instance"""
    if not symptom_checker.loaded:
        symptom_checker.load_model()
    return symptom_checker
