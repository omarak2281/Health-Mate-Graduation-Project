import uuid
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI, status
from fastapi.testclient import TestClient

from app.api.dependencies import get_current_user
from app.api.v1.medications import router
from app.core.database import get_db
from app.models.medication import Medication
from app.models.patient_caregiver_link import PatientCaregiverLink


class FakeCaregiver:
    id = uuid.uuid4()
    email = "caregiver@example.com"
    full_name = "Care Giver"


class FakePatient:
    id = uuid.uuid4()
    email = "patient@example.com"
    full_name = "Jane Patient"


@pytest.fixture
def mock_db():
    db = AsyncMock()

    async def mock_refresh(instance):
        if not getattr(instance, "updated_at", None):
            instance.updated_at = datetime.utcnow()

    db.refresh.side_effect = mock_refresh
    return db


@pytest.fixture
def client(mock_db):
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")
    app.dependency_overrides[get_current_user] = lambda: FakeCaregiver()
    app.dependency_overrides[get_db] = lambda: mock_db
    return TestClient(app)


def _result_scalar(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


def _result_all(values):
    result = MagicMock()
    result.scalars.return_value.all.return_value = values
    return result


def _medication() -> Medication:
    now = datetime.utcnow()
    return Medication(
        id=uuid.uuid4(),
        user_id=FakePatient.id,
        name="Aspirin",
        dosage="100 mg",
        instructions="After food",
        image_url=None,
        times_per_day=1,
        scheduled_times=["08:00"],
        use_smart_box=False,
        drawer_number=None,
        is_active=True,
        created_at=now,
        updated_at=now,
    )


def _active_link() -> PatientCaregiverLink:
    return PatientCaregiverLink(
        id=uuid.uuid4(),
        patient_id=FakePatient.id,
        caregiver_id=FakeCaregiver.id,
        is_active=True,
    )


@pytest.mark.anyio
async def test_linked_caregiver_can_list_patient_medications(client, mock_db):
    med = _medication()
    mock_db.execute.side_effect = [
        _result_scalar(_active_link()),
        _result_all([med]),
    ]

    response = client.get(f"/api/v1/medications/patient/{FakePatient.id}")

    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data) == 1
    assert data[0]["id"] == str(med.id)
    assert data[0]["user_id"] == str(FakePatient.id)
    assert data[0]["scheduled_times"] == ["08:00"]


@pytest.mark.anyio
async def test_unlinked_caregiver_cannot_list_patient_medications(client, mock_db):
    mock_db.execute.return_value = _result_scalar(None)

    response = client.get(f"/api/v1/medications/patient/{FakePatient.id}")

    assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.anyio
async def test_linked_caregiver_can_update_patient_medication(client, mock_db):
    med = _medication()
    mock_db.execute.side_effect = [
        _result_scalar(med),
        _result_scalar(_active_link()),
    ]

    with patch("app.api.v1.medications.schedule_medication_jobs", AsyncMock()) as schedule_mock:
        response = client.put(
            f"/api/v1/medications/{med.id}",
            json={"dosage": "150 mg"},
        )

    assert response.status_code == status.HTTP_200_OK
    assert response.json()["dosage"] == "150 mg"
    schedule_mock.assert_awaited_once()


@pytest.mark.anyio
async def test_linked_caregiver_can_delete_patient_medication(client, mock_db):
    med = _medication()
    mock_db.execute.side_effect = [
        _result_scalar(med),
        _result_scalar(_active_link()),
        _result_all([]),
    ]

    with patch("app.api.v1.medications.delete_medication_jobs", AsyncMock()) as delete_jobs_mock:
        response = client.delete(f"/api/v1/medications/{med.id}")

    assert response.status_code == status.HTTP_204_NO_CONTENT
    delete_jobs_mock.assert_awaited_once_with(med.id, FakePatient.id, mock_db)
