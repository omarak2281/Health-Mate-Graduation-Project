import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import FastAPI, status
from fastapi.testclient import TestClient
from uuid import UUID
from datetime import datetime

from app.api.dependencies import get_current_user, get_device_from_headers
from app.api.v1.vitals import router
from app.core.database import get_db
from app.models.user import User
from app.models.vital_sign import VitalSign, MeasurementStatus, RiskLevel
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.models.registered_device import RegisteredDevice
from app.services.notification_service import get_notification_service
from app.services.patient_caregiver_service import assign_is_primary_for_new_link


class FakeUser:
    id = uuid.uuid4()
    email = "patient@example.com"
    full_name = "Jane Doe"


@pytest.fixture
def mock_db():
    db = AsyncMock()
    
    # Mock refresh to populate UUID and timestamps simulating DB defaults
    async def mock_refresh(instance):
        if not getattr(instance, "id", None):
            instance.id = uuid.uuid4()
        if not getattr(instance, "measured_at", None):
            instance.measured_at = datetime.utcnow()
        if not getattr(instance, "created_at", None):
            instance.created_at = datetime.utcnow()
    
    db.refresh.side_effect = mock_refresh
    return db


@pytest.fixture
def client(mock_db):
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")
    app.dependency_overrides[get_current_user] = lambda: FakeUser()
    app.dependency_overrides[get_db] = lambda: mock_db
    
    fake_device = RegisteredDevice(
        device_id="test-device-123",
        patient_id=FakeUser.id,
        is_active=True
    )
    app.dependency_overrides[get_device_from_headers] = lambda: fake_device
    return TestClient(app)


@pytest.mark.anyio
async def test_submit_device_reading(client, mock_db):
    # Setup mock user return
    mock_execute = MagicMock()
    mock_execute.scalar_one_or_none.return_value = FakeUser()
    mock_db.execute.return_value = mock_execute

    payload = {
        "device_id": "test-device-123",
        "ppg_signal": [0.1] * 800,
        "ecg_signal": [0.2] * 800,
        "heart_rate": 76,
        "spo2": 98,
    }

    mock_prediction = {
        "prediction_status": "success",
        "systolic": 118.5,
        "diastolic": 76.2,
        "heart_rate": 48.0,
        "signal_quality": 0.95
    }

    mock_cal_res = {
        "systolic": 118.5,
        "diastolic": 76.2,
        "calibration_status": "not_calibrated"
    }

    with patch("app.services.abp_prediction_service.ABPPredictionService.predict_bp", return_value=mock_prediction), \
         patch("app.services.calibration_service.CalibrationService.apply_calibration", return_value=mock_cal_res):
        # Pass headers to bypass dependency mock
        headers = {"X-Device-ID": "test-device-123", "X-Device-Token": "valid-token"}
        response = client.post("/api/v1/vitals/bp/submit", json=payload, headers=headers)
        assert response.status_code == status.HTTP_201_CREATED
        data = response.json()
        assert data["source"] == "sensor"
        assert data["measurement_status"] == "completed_pending_bp"
        assert data["device_id"] == "test-device-123"
        assert data["systolic"] is None
        assert data["diastolic"] is None
        assert data["heart_rate"] == 76
        assert data["spo2"] == 98


@pytest.mark.anyio
async def test_create_manual_bp_reading_persists_spo2(client, mock_db):
    payload = {
        "systolic": 120,
        "diastolic": 80,
        "heart_rate": 72,
        "spo2": 97,
        "source": "manual",
    }

    response = client.post("/api/v1/vitals/bp", json=payload)

    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["systolic"] == 120
    assert data["diastolic"] == 80
    assert data["heart_rate"] == 72
    assert data["spo2"] == 97


@pytest.mark.anyio
async def test_submit_device_reading_returns_completed_prediction_when_calibrated(client, mock_db):
    mock_execute = MagicMock()
    mock_execute.scalar_one_or_none.return_value = FakeUser()
    mock_db.execute.return_value = mock_execute

    payload = {
        "device_id": "test-device-123",
        "ppg_signal": [0.1] * 800,
        "ecg_signal": [0.2] * 800
    }

    mock_prediction = {
        "prediction_status": "success",
        "systolic": 126.4,
        "diastolic": 78.2,
        "heart_rate": 73.0,
        "signal_quality": 0.96
    }

    mock_cal_res = {
        "systolic": 128.2,
        "diastolic": 80.1,
        "calibration_status": "additive"
    }

    with patch("app.services.abp_prediction_service.ABPPredictionService.predict_bp", return_value=mock_prediction), \
         patch("app.services.calibration_service.CalibrationService.apply_calibration", return_value=mock_cal_res):
        headers = {"X-Device-ID": "test-device-123", "X-Device-Token": "valid-token"}
        response = client.post("/api/v1/vitals/bp/submit", json=payload, headers=headers)

    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["measurement_status"] == "completed"
    assert data["systolic"] == 128
    assert data["diastolic"] == 80
    assert data["calibrated_systolic"] == 128.2
    assert data["calibrated_diastolic"] == 80.1


@pytest.mark.anyio
async def test_submit_device_reading_model_not_ready(client, mock_db):
    mock_execute = MagicMock()
    mock_execute.scalar_one_or_none.return_value = FakeUser()
    mock_db.execute.return_value = mock_execute

    payload = {
        "device_id": "test-device-123",
        "ppg_signal": [0.1] * 800,
        "ecg_signal": [0.2] * 800
    }

    mock_prediction = {
        "prediction_status": "model_not_ready"
    }

    with patch("app.services.abp_prediction_service.ABPPredictionService.predict_bp", return_value=mock_prediction):
        headers = {"X-Device-ID": "test-device-123", "X-Device-Token": "valid-token"}
        response = client.post("/api/v1/vitals/bp/submit", json=payload, headers=headers)
        assert response.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
        assert response.json()["detail"] == "model_not_ready"


@pytest.mark.anyio
async def test_submit_device_reading_invalid_length(client, mock_db):
    payload = {
        "device_id": "test-device-123",
        "ppg_signal": [0.1] * 100,  # invalid signal length
        "ecg_signal": [0.2] * 800
    }

    headers = {"X-Device-ID": "test-device-123", "X-Device-Token": "valid-token"}
    response = client.post("/api/v1/vitals/bp/submit", json=payload, headers=headers)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.anyio
async def test_complete_bp_reading_normal(client, mock_db):
    # Setup pending vital sign with exact UUID and timestamps preset
    pending_vital = VitalSign(
        id=uuid.uuid4(),
        user_id=FakeUser.id,
        source="sensor",
        measurement_status=MeasurementStatus.COMPLETED_PENDING_BP,
        heart_rate=72,
        measured_at=datetime.utcnow(),
        created_at=datetime.utcnow(),
        device_id="test-device-123",
        confidence=1.0,
        signal_quality=1.0
    )

    mock_execute = MagicMock()
    mock_execute.scalar_one_or_none.return_value = pending_vital
    mock_db.execute.return_value = mock_execute

    payload = {
        "vital_sign_id": str(pending_vital.id),
        "systolic": 120,
        "diastolic": 80
    }

    response = client.post("/api/v1/vitals/bp/complete", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["systolic"] == 120
    assert data["diastolic"] == 80
    assert data["measurement_status"] == "completed"


@pytest.mark.anyio
async def test_complete_bp_reading_invalid_systolic_diastolic(client, mock_db):
    # Pydantic validation should block systolic <= diastolic
    payload = {
        "vital_sign_id": str(uuid.uuid4()),
        "systolic": 110,
        "diastolic": 110
    }
    response = client.post("/api/v1/vitals/bp/complete", json=payload)
    assert response.status_code == 422


@pytest.mark.anyio
async def test_bp_calibration_status(client, mock_db):
    # Mock database empty calibrations return
    mock_execute = MagicMock()
    mock_execute.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_execute

    response = client.get("/api/v1/vitals/bp/calibration/status")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "not_calibrated"
    assert data["samples_count"] == 0
    assert data["recalibration_due"] is True


@pytest.mark.anyio
async def test_patient_caregiver_service_assign_primary(mock_db):
    # If no other caregiver is primary, setting it should remain true
    link = PatientCaregiverLink(
        patient_id=uuid.uuid4(),
        caregiver_id=uuid.uuid4(),
        is_primary=False,
        is_active=True
    )
    
    mock_execute = MagicMock()
    mock_execute.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_execute

    await assign_is_primary_for_new_link(mock_db, link.patient_id, link)
    assert link.is_primary is True


@pytest.mark.anyio
async def test_register_device_heartbeat(client, mock_db):
    payload = {
        "leads_connected": True,
        "finger_detected": False
    }
    
    headers = {"X-Device-ID": "test-device-123", "X-Device-Token": "valid-token"}
    response = client.post("/api/v1/vitals/bp/heartbeat", json=payload, headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"

