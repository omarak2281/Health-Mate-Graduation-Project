"""Phase 5 contract tests (plan §6 Phase 5 DoD): lang as query param (not body), urgency/
recommended_action_text top-level in the response, red flags survive a classifier failure, and
the no_symptoms_selected error contract. Mounts only the `/ai` router on a bare FastAPI app and
overrides dependencies — avoids needing a real Postgres/Redis connection or the real ML model.
"""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from uuid import UUID

from app.api.dependencies import get_current_user
from app.api.v1.ai import router
from app.application.services.symptom_checker_metrics import rollout_metrics
from app.core.config import settings
from app.core.database import get_db
from app.core.di import get_assessment_repository, get_chat_sessions, get_disease_classifier, get_taxonomy_repository
from app.services.notification_service import get_notification_service
from app.domain.entities.category import Category
from app.domain.entities.disease import Disease
from app.domain.entities.symptom import Symptom
from app.domain.interfaces.disease_classifier import DiseasePrediction
from app.infrastructure.persistence.in_memory_chat_session_repository import InMemoryChatSessionRepository


class FakeTaxonomyRepository:
    def __init__(self):
        self._categories = [Category(id="respiratory", name_en="Respiratory", name_ar="الجهاز التنفسي", order=1)]
        self._symptoms = [
            Symptom(id="chest_pain", name_en="Chest Pain", name_ar="ألم الصدر", category_ids=["respiratory"], red_flag=True),
            Symptom(id="cough", name_en="Cough", name_ar="سعال", category_ids=["respiratory"], red_flag=False),
        ]
        self._symptoms[0].synonyms_en = ["chest pressure"]
        self._symptoms[0].synonyms_ar = ["ضغط الصدر"]
        self._symptoms[1].synonyms_en = ["coughing"]
        self._symptoms[1].synonyms_ar = ["كحة"]
        self._diseases = [
            Disease(
                id="common_cold",
                name_en="Common Cold",
                name_ar="الزكام",
                description_en="d",
                description_ar="د",
                category_id="respiratory",
                default_urgency="low",
                related_symptom_ids=["cough"],
            )
        ]

    def get_categories(self):
        return self._categories

    def get_symptoms(self, category_id=None):
        if category_id is None:
            return self._symptoms
        return [s for s in self._symptoms if category_id in s.category_ids]

    def get_symptom(self, symptom_id):
        return next((s for s in self._symptoms if s.id == symptom_id), None)

    def get_disease(self, disease_id):
        return next((d for d in self._diseases if d.id == disease_id), None)

    def get_diseases(self):
        return self._diseases


class FakeDiseaseClassifier:
    def predict_top_k(self, assessment, k=3):
        return [DiseasePrediction(disease_id="common_cold", confidence=0.8)]


class FailingDiseaseClassifier:
    def predict_top_k(self, assessment, k=3):
        raise RuntimeError("model unavailable")


class NoopAssessmentRepository:
    async def save(self, assessment_id, payload):
        self.last_saved = {"assessment_id": assessment_id, "payload": payload}

    async def get(self, assessment_id):
        return None

    async def save_chat_seed(self, session_id, payload):
        self.last_chat_seed = {"session_id": session_id, "payload": payload}


class FakeCurrentUser:
    id = UUID("00000000-0000-0000-0000-000000000001")
    full_name = "Test Patient"


class FakeNotificationService:
    def __init__(self):
        self.calls = []

    async def send_symptom_assessment_alert(self, **kwargs):
        self.calls.append(kwargs)
        return 2


@pytest.fixture
def client():
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")
    app.dependency_overrides[get_current_user] = lambda: object()
    app.dependency_overrides[get_taxonomy_repository] = lambda: FakeTaxonomyRepository()
    app.dependency_overrides[get_disease_classifier] = lambda: FakeDiseaseClassifier()
    app.dependency_overrides[get_chat_sessions] = lambda: InMemoryChatSessionRepository()
    app.dependency_overrides[get_assessment_repository] = lambda: NoopAssessmentRepository()
    app.dependency_overrides[get_db] = lambda: object()
    return TestClient(app)


def test_categories_lang_en(client):
    resp = client.get("/api/v1/ai/categories?lang=en")
    assert resp.status_code == 200
    assert resp.json()[0]["name"] == "Respiratory"


def test_categories_lang_ar(client):
    resp = client.get("/api/v1/ai/categories?lang=ar")
    assert resp.status_code == 200
    assert resp.json()[0]["name"] == "الجهاز التنفسي"


def test_taxonomy_symptoms_filtered_by_category(client):
    resp = client.get("/api/v1/ai/taxonomy/symptoms?category_id=respiratory&lang=en")
    assert resp.status_code == 200
    ids = {s["id"] for s in resp.json()}
    assert ids == {"chest_pain", "cough"}
    chest_pain = next(s for s in resp.json() if s["id"] == "chest_pain")
    assert chest_pain["red_flag"] is True
    assert "chest pressure" in chest_pain["synonyms"]


def test_phase11_categories_have_same_ids_in_ar_and_en(client):
    en = client.get("/api/v1/ai/categories?lang=en")
    ar = client.get("/api/v1/ai/categories?lang=ar")

    assert en.status_code == 200
    assert ar.status_code == 200
    assert [item["id"] for item in en.json()] == [item["id"] for item in ar.json()]


def test_phase11_symptom_lists_have_same_ids_and_localized_synonyms(client):
    en = client.get("/api/v1/ai/taxonomy/symptoms?category_id=respiratory&lang=en")
    ar = client.get("/api/v1/ai/taxonomy/symptoms?category_id=respiratory&lang=ar")

    assert en.status_code == 200
    assert ar.status_code == 200
    assert {item["id"] for item in en.json()} == {item["id"] for item in ar.json()} == {"chest_pain", "cough"}
    assert "coughing" in next(item for item in en.json() if item["id"] == "cough")["synonyms"]
    assert "كحة" in next(item for item in ar.json() if item["id"] == "cough")["synonyms"]


def test_assessment_lang_arrives_as_query_param_not_body(client):
    """Regression test for plan §1.6 mismatch #1: `lang` must be read from the query string.
    Sending `lang` inside the JSON body (as the old broken Flutter client did) must have zero
    effect — the response must still honor the query-string `lang`."""
    payload = {"symptoms": [{"id": "cough", "severity": 2}], "lang": "ar"}  # lang in body, ignored
    resp = client.post("/api/v1/ai/assessment?lang=en", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["urgency_label"] == "Low"  # English, from the query param, not "منخفض"


def test_assessment_urgency_and_action_text_are_top_level(client):
    """Regression test for plan §1.6 mismatch #2: `urgency`/`recommended_action_text` must be
    top-level fields, not nested under a `disease_info` object."""
    payload = {"symptoms": [{"id": "cough", "severity": 2}]}
    resp = client.post("/api/v1/ai/assessment?lang=en", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert "disease_info" not in body
    assert "urgency" in body and "recommended_action_text" in body
    assert body["urgency"] == "low"
    assert body["recommended_action_text"] == "Rest and monitor your symptoms."


def test_no_symptoms_selected_error_contract(client):
    resp = client.post("/api/v1/ai/assessment?lang=en", json={"symptoms": []})
    assert resp.status_code == 400
    assert resp.json()["detail"]["error_code"] == "no_symptoms_selected"


def test_red_flags_present_even_if_ml_classifier_fails(client):
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")
    app.dependency_overrides[get_current_user] = lambda: object()
    app.dependency_overrides[get_taxonomy_repository] = lambda: FakeTaxonomyRepository()
    app.dependency_overrides[get_disease_classifier] = lambda: FailingDiseaseClassifier()
    app.dependency_overrides[get_assessment_repository] = lambda: NoopAssessmentRepository()
    failing_client = TestClient(app)

    payload = {"symptoms": [{"id": "chest_pain", "severity": 3}]}
    resp = failing_client.post("/api/v1/ai/assessment?lang=en", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["top_predictions"] == []  # ML degraded gracefully
    assert len(body["red_flags"]) == 1  # but red flags still computed
    assert body["red_flags"][0]["code"] == "chest_pain"
    assert body["urgency"] == "critical"


def test_phase11_assessment_top_predictions_urgency_and_red_flags_match_between_languages(client):
    payload = {"symptoms": [{"id": "chest_pain", "severity": 3}], "duration_days": 1, "age_group": "adult"}

    en = client.post("/api/v1/ai/assessment?lang=en", json=payload)
    ar = client.post("/api/v1/ai/assessment?lang=ar", json=payload)

    assert en.status_code == 200
    assert ar.status_code == 200
    en_body = en.json()
    ar_body = ar.json()
    assert [item["disease_id"] for item in en_body["top_predictions"]] == [
        item["disease_id"] for item in ar_body["top_predictions"]
    ]
    assert en_body["urgency"] == ar_body["urgency"] == "critical"
    assert [item["code"] for item in en_body["red_flags"]] == [item["code"] for item in ar_body["red_flags"]]


def test_bp_triage_sets_should_remeasure_for_moderate_high_urgency(client):
    payload = {
        "symptoms": [{"id": "cough", "severity": 1}],
        "vitals": {"systolic": 150, "diastolic": 95},
    }
    resp = client.post("/api/v1/ai/bp-triage?lang=en", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["should_remeasure"] is True
    assert body["recommended_action_code"] == "remeasure_after_rest"


def test_bp_triage_persists_source_vital_id():
    app = FastAPI()
    assessment_repo = NoopAssessmentRepository()
    app.include_router(router, prefix="/api/v1")
    app.dependency_overrides[get_current_user] = lambda: object()
    app.dependency_overrides[get_taxonomy_repository] = lambda: FakeTaxonomyRepository()
    app.dependency_overrides[get_disease_classifier] = lambda: FakeDiseaseClassifier()
    app.dependency_overrides[get_assessment_repository] = lambda: assessment_repo
    bp_client = TestClient(app)

    vital_id = "11111111-1111-1111-1111-111111111111"
    payload = {
        "source_vital_id": vital_id,
        "category_id": "heart_bp",
        "symptoms": [{"id": "chest_pain", "severity": 3}],
        "vitals": {"systolic": 185, "diastolic": 125},
    }
    resp = bp_client.post("/api/v1/ai/bp-triage?lang=en", json=payload)

    assert resp.status_code == 200
    body = resp.json()
    assert body["urgency"] == "critical"
    assert body["red_flags"][0]["code"] == "chest_pain"
    assert assessment_repo.last_saved["payload"]["assessment_type"] == "bp_triage"
    assert assessment_repo.last_saved["payload"]["request"]["source_vital_id"] == vital_id


def test_phase11_bp_triage_handoff_same_source_vital_contract_in_ar_and_en():
    for lang in ("en", "ar"):
        app = FastAPI()
        assessment_repo = NoopAssessmentRepository()
        app.include_router(router, prefix="/api/v1")
        app.dependency_overrides[get_current_user] = lambda: object()
        app.dependency_overrides[get_taxonomy_repository] = lambda: FakeTaxonomyRepository()
        app.dependency_overrides[get_disease_classifier] = lambda: FakeDiseaseClassifier()
        app.dependency_overrides[get_assessment_repository] = lambda: assessment_repo
        bp_client = TestClient(app)

        vital_id = f"11111111-1111-1111-1111-11111111111{1 if lang == 'en' else 2}"
        payload = {
            "source_vital_id": vital_id,
            "category_id": "heart_bp",
            "symptoms": [{"id": "cough", "severity": 1}],
            "vitals": {"systolic": 150, "diastolic": 95},
        }
        resp = bp_client.post(f"/api/v1/ai/bp-triage?lang={lang}", json=payload)

        assert resp.status_code == 200
        assert resp.json()["should_remeasure"] is True
        assert assessment_repo.last_saved["payload"]["assessment_type"] == "bp_triage"
        assert assessment_repo.last_saved["payload"]["request"]["source_vital_id"] == vital_id


def test_chat_from_assessment_returns_assessment_id(client):
    payload = {"symptoms": [{"id": "cough", "severity": 1}]}
    resp = client.post("/api/v1/ai/chat/from-assessment?lang=en", json=payload)
    assert resp.status_code == 200
    assert "assessment_id" in resp.json()


def test_assessment_lang_ar_localizes_disease_name_and_disclaimer(client):
    payload = {"symptoms": [{"id": "cough", "severity": 1}]}
    resp = client.post("/api/v1/ai/assessment?lang=ar", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["top_predictions"][0]["name"] == "الزكام"
    assert body["disclaimer"] == "هذا تقييم مبدئي وليس تشخيصًا نهائيًا."


def test_taxonomy_symptoms_lang_ar(client):
    resp = client.get("/api/v1/ai/taxonomy/symptoms?lang=ar")
    assert resp.status_code == 200
    names = {s["id"]: s["name"] for s in resp.json()}
    assert names["chest_pain"] == "ألم الصدر"


def test_bp_triage_lang_ar(client):
    payload = {"symptoms": [{"id": "cough", "severity": 1}], "vitals": {"systolic": 150, "diastolic": 95}}
    resp = client.post("/api/v1/ai/bp-triage?lang=ar", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["should_remeasure"] is True
    assert body["recommended_action_text"] == "استرح لمدة 5 دقائق ثم أعد القياس."


def test_chat_from_assessment_lang_ar(client):
    payload = {"symptoms": [{"id": "cough", "severity": 1}]}
    resp = client.post("/api/v1/ai/chat/from-assessment?lang=ar", json=payload)
    assert resp.status_code == 200
    assert "assessment_id" in resp.json()


def test_notify_caregiver_endpoint_uses_linked_caregiver_notification_service():
    app = FastAPI()
    fake_notifications = FakeNotificationService()
    app.include_router(router, prefix="/api/v1")
    app.dependency_overrides[get_current_user] = lambda: FakeCurrentUser()
    app.dependency_overrides[get_taxonomy_repository] = lambda: FakeTaxonomyRepository()
    app.dependency_overrides[get_disease_classifier] = lambda: FakeDiseaseClassifier()
    app.dependency_overrides[get_notification_service] = lambda: fake_notifications
    app.dependency_overrides[get_db] = lambda: object()
    notify_client = TestClient(app)

    payload = {"symptoms": [{"id": "cough", "severity": 2}]}
    resp = notify_client.post("/api/v1/ai/assessment/notify-caregiver?lang=en", json=payload)

    assert resp.status_code == 200
    assert resp.json() == {"notified_count": 2, "auto_triggered": False}
    assert fake_notifications.calls[0]["patient_id"] == str(FakeCurrentUser.id)
    assert fake_notifications.calls[0]["manual"] is True


def test_phase11_caregiver_notification_routing_is_patient_language_independent():
    fake_notifications = FakeNotificationService()
    for lang in ("en", "ar"):
        app = FastAPI()
        app.include_router(router, prefix="/api/v1")
        app.dependency_overrides[get_current_user] = lambda: FakeCurrentUser()
        app.dependency_overrides[get_taxonomy_repository] = lambda: FakeTaxonomyRepository()
        app.dependency_overrides[get_disease_classifier] = lambda: FakeDiseaseClassifier()
        app.dependency_overrides[get_notification_service] = lambda: fake_notifications
        app.dependency_overrides[get_db] = lambda: object()
        notify_client = TestClient(app)

        resp = notify_client.post(f"/api/v1/ai/assessment/notify-caregiver?lang={lang}", json={"symptoms": [{"id": "cough", "severity": 2}]})

        assert resp.status_code == 200
        assert resp.json()["notified_count"] == 2

    assert len(fake_notifications.calls) == 2
    assert {call["patient_id"] for call in fake_notifications.calls} == {str(FakeCurrentUser.id)}


def test_phase12_feature_flag_disables_structured_v2_without_disabling_legacy_routes(client, monkeypatch):
    monkeypatch.setattr(settings, "symptom_checker_v2_enabled", False)

    disabled = client.get("/api/v1/ai/categories?lang=en")

    assert disabled.status_code == 503
    assert disabled.json()["detail"]["error_code"] == "symptom_checker_v2_disabled"


def test_phase12_rollout_metrics_track_assessment_distribution_and_latency(client):
    rollout_metrics.reset()

    resp = client.post("/api/v1/ai/assessment?lang=en", json={"symptoms": [{"id": "chest_pain", "severity": 3}]})
    metrics = client.get("/api/v1/ai/assessment/rollout-metrics")

    assert resp.status_code == 200
    assert metrics.status_code == 200
    body = metrics.json()
    assert body["assessment_count"] == 1
    assert body["red_flag_trigger_rate"] == 1.0
    assert body["top_prediction_distribution"] == {"common_cold": 1}
    assert body["urgency_distribution"] == {"critical": 1}
    assert body["assessment_latency_ms_avg"] >= 0
