from __future__ import annotations

import pytest

from app.services.ai_service import SymptomCheckerService


@pytest.fixture
def symptom_checker() -> SymptomCheckerService:
    service = SymptomCheckerService()
    service.symptom_translations = {
        "Cough": {
            "en": {"name": "Cough", "description": "", "severity": "low", "category": "Respiratory"},
            "ar": {"name": "كحة", "description": "", "severity": "low", "category": "تنفسي"},
        },
        "Sore Throat": {
            "en": {"name": "Sore Throat", "description": "", "severity": "low", "category": "Respiratory"},
            "ar": {"name": "احتقان", "description": "", "severity": "low", "category": "تنفسي"},
        },
        "Fever": {
            "en": {"name": "Fever", "description": "", "severity": "moderate", "category": "General"},
            "ar": {"name": "حرارة", "description": "", "severity": "moderate", "category": "عام"},
        },
        "Headache": {
            "en": {"name": "Headache", "description": "", "severity": "moderate", "category": "Neurological"},
            "ar": {"name": "صداع", "description": "", "severity": "moderate", "category": "عصبي"},
        },
        "Dizziness": {
            "en": {"name": "Dizziness", "description": "", "severity": "moderate", "category": "Neurological"},
            "ar": {"name": "دوخة", "description": "", "severity": "moderate", "category": "عصبي"},
        },
        "Chest Pain": {
            "en": {"name": "Chest Pain", "description": "", "severity": "high", "category": "Heart"},
            "ar": {"name": "ألم في الصدر", "description": "", "severity": "high", "category": "القلب"},
        },
        "Shortness of Breath": {
            "en": {"name": "Shortness of Breath", "description": "", "severity": "high", "category": "Respiratory"},
            "ar": {"name": "ضيق تنفس", "description": "", "severity": "high", "category": "تنفسي"},
        },
    }
    return service


@pytest.mark.parametrize(
    ("phrase", "expected"),
    [
        ("عندي كحة واحتقان وحرارة بسيطة", {"Cough", "Sore Throat", "Fever"}),
        ("عندي صداع ودوخة والضغط عالي", {"Headache", "Dizziness"}),
        ("عندي ألم في الصدر وضيق تنفس", {"Chest Pain", "Shortness of Breath"}),
        ("I have cough, sore throat, and mild fever.", {"Cough", "Sore Throat", "Fever"}),
        ("I have headache and dizziness after high blood pressure.", {"Headache", "Dizziness"}),
        ("I have chest pain and shortness of breath.", {"Chest Pain", "Shortness of Breath"}),
    ],
)
def test_phase11_source_doc_free_text_phrases_extract_expected_symptoms(symptom_checker, phrase, expected):
    extracted = set(symptom_checker.extract_symptoms(phrase))

    assert expected <= extracted
