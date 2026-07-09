from __future__ import annotations

import httpx

from app.application.dto.assessment_dto import AssessmentResultDTO, RedFlagDTO, TopPrediction
from app.application.use_cases.run_assessment import run_assessment
from app.domain.entities.category import Category
from app.domain.entities.disease import Disease
from app.domain.entities.assessment import AssessmentInput, SelectedSymptom
from app.domain.entities.symptom import Symptom
from app.domain.interfaces.disease_classifier import DiseasePrediction
from app.infrastructure.phrasing.assessment_phraser import OpenAICompatibleAssessmentPhraser, StaticAssessmentPhraser


def _assessment() -> AssessmentInput:
    return AssessmentInput(symptoms=[SelectedSymptom(id="cough", severity=2)])


def _result() -> AssessmentResultDTO:
    return AssessmentResultDTO(
        top_predictions=[TopPrediction(disease_id="common_cold", name="Common Cold", confidence=0.8, why=["cough"])],
        urgency="low",
        urgency_label="Low",
        red_flags=[RedFlagDTO(code="cough", severity=2)],
        patient_message="Static patient message.",
        recommended_action_code="self_care_monitor",
        recommended_action_text="Rest and monitor your symptoms.",
        caregiver_summary="Static caregiver summary.",
        should_notify_caregiver=False,
        disclaimer="This is a preliminary assessment, not a final diagnosis.",
    )


def test_static_phraser_preserves_complete_assessment_result():
    assessment = _assessment()
    result = _result()

    phrased = StaticAssessmentPhraser().phrase(assessment, result, lang="en")

    assert phrased == result


def test_openai_compatible_phraser_degrades_to_static_text_when_client_fails(monkeypatch):
    class FailingClient:
        def __init__(self, *args, **kwargs):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def post(self, *args, **kwargs):
            raise httpx.ConnectError("network unavailable")

    monkeypatch.setattr(httpx, "Client", FailingClient)
    assessment = _assessment()
    result = _result()

    phrased = OpenAICompatibleAssessmentPhraser(
        api_key="test-key",
        model="test-model",
        base_url="https://example.invalid/v1",
        timeout_seconds=0.1,
    ).phrase(assessment, result, lang="en")

    assert phrased == result


def test_run_assessment_phraser_can_update_only_patient_and_caregiver_text():
    class FakeTaxonomyRepository:
        def get_symptom(self, symptom_id):
            return Symptom(id=symptom_id, name_en="Cough", name_ar="سعال", category_ids=["respiratory"], red_flag=False)

        def get_disease(self, disease_id):
            return Disease(
                id=disease_id,
                name_en="Common Cold",
                name_ar="الزكام",
                description_en="d",
                description_ar="د",
                category_id="respiratory",
                default_urgency="low",
                related_symptom_ids=["cough"],
            )

        def get_categories(self):
            return [Category(id="respiratory", name_en="Respiratory", name_ar="تنفسي", order=1)]

        def get_symptoms(self, category_id=None):
            return []

        def get_diseases(self):
            return []

    class FakeClassifier:
        def predict_top_k(self, assessment, k=3):
            return [DiseasePrediction(disease_id="common_cold", confidence=0.8)]

    class TextOnlyPhraser:
        def phrase(self, assessment, result, *, lang):
            return result.model_copy(
                update={
                    "patient_message": "Phrased patient message.",
                    "caregiver_summary": "Phrased caregiver summary.",
                }
            )

    result = run_assessment(
        _assessment(),
        FakeTaxonomyRepository(),
        FakeClassifier(),
        lang="en",
        phraser=TextOnlyPhraser(),
    )

    assert result.patient_message == "Phrased patient message."
    assert result.caregiver_summary == "Phrased caregiver summary."
    assert result.urgency == "low"
    assert result.recommended_action_code == "self_care_monitor"
    assert result.top_predictions[0].disease_id == "common_cold"
