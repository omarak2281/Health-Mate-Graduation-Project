import pytest
import uuid
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from app.models.patient_calibration import PatientCalibration
from app.models.vital_sign import VitalSign, MeasurementStatus
from app.services.bp_drift_service import BPDriftService


@pytest.mark.anyio
async def test_drift_service_no_drift():
    # Setup
    db = AsyncMock()
    patient_id = uuid.uuid4()
    
    # 1. Calibration record setup with baseline of 120/80
    calibration = PatientCalibration(
        patient_id=patient_id,
        baseline_raw_mean_sbp=120.0,
        baseline_raw_mean_dbp=80.0,
        last_calibrated_at=datetime.utcnow() - timedelta(days=5),
        drift_flag=False,
        last_drift_notification_at=None
    )
    
    # Mock calibration query
    mock_cal_res = MagicMock()
    mock_cal_res.scalars.return_value.all.return_value = [calibration]
    
    # 2. Vital readings setup: 10 readings close to the baseline (no drift)
    readings = [
        VitalSign(
            user_id=patient_id,
            model_systolic=121.0,
            model_diastolic=81.0,
            measurement_status=MeasurementStatus.COMPLETED,
            measured_at=datetime.utcnow() - timedelta(hours=i)
        )
        for i in range(10)
    ]
    
    mock_readings_res = MagicMock()
    mock_readings_res.scalars.return_value.all.return_value = readings
    
    # Setup database mock execute sequences
    db.execute.side_effect = [mock_cal_res, mock_readings_res]
    
    drift_service = BPDriftService()
    
    with patch("app.services.bp_drift_service.get_notification_service") as mock_notif_service:
        await drift_service.check_all_patients(db)
        
        # Drift flag should NOT be True
        assert calibration.drift_flag is False
        assert db.commit.call_count == 0
        mock_notif_service.return_value.create_notification.assert_not_called()


@pytest.mark.anyio
async def test_drift_service_drift_detected():
    db = AsyncMock()
    patient_id = uuid.uuid4()
    
    # 1. Calibration record setup
    calibration = PatientCalibration(
        patient_id=patient_id,
        baseline_raw_mean_sbp=120.0,
        baseline_raw_mean_dbp=80.0,
        last_calibrated_at=datetime.utcnow() - timedelta(days=5),
        drift_flag=False,
        last_drift_notification_at=None
    )
    
    mock_cal_res = MagicMock()
    mock_cal_res.scalars.return_value.all.return_value = [calibration]
    
    # 2. Vital readings setup: Readings showing a significant drift (offset is > 8 SBP and > 5 DBP)
    # SBP baseline: 120, model readings: 130 (+10) -> SBP drifted
    # DBP baseline: 80, model readings: 87 (+7) -> DBP drifted
    readings = [
        VitalSign(
            user_id=patient_id,
            model_systolic=130.0,
            model_diastolic=87.0,
            measurement_status=MeasurementStatus.COMPLETED,
            measured_at=datetime.utcnow() - timedelta(hours=i)
        )
        for i in range(10)
    ]
    
    mock_readings_res = MagicMock()
    mock_readings_res.scalars.return_value.all.return_value = readings
    
    db.execute.side_effect = [mock_cal_res, mock_readings_res]
    
    drift_service = BPDriftService()
    
    # Mock the notification service
    mock_notification = AsyncMock()
    
    with patch("app.services.bp_drift_service.get_notification_service", return_value=mock_notification):
        await drift_service.check_all_patients(db)
        
        # Drift flag SHOULD be True
        assert calibration.drift_flag is True
        assert calibration.drift_reason == 'drift_detected'
        assert db.commit.call_count == 1
        mock_notification.create_notification.assert_called_once()
        
        # Check title/message payload components in notification call
        args, kwargs = mock_notification.create_notification.call_args
        assert kwargs["notification_type"] == "bp_drift_alert"
        assert "drift_reason" in kwargs["data"]
        assert kwargs["data"]["drift_reason"] == "drift_detected"


@pytest.mark.anyio
async def test_drift_service_stale_detected():
    db = AsyncMock()
    patient_id = uuid.uuid4()
    
    # Last calibrated > 90 days ago
    calibration = PatientCalibration(
        patient_id=patient_id,
        baseline_raw_mean_sbp=120.0,
        baseline_raw_mean_dbp=80.0,
        last_calibrated_at=datetime.utcnow() - timedelta(days=95),
        drift_flag=False,
        last_drift_notification_at=None
    )
    
    mock_cal_res = MagicMock()
    mock_cal_res.scalars.return_value.all.return_value = [calibration]
    
    # Normal readings (no drift, but calibration is stale)
    readings = [
        VitalSign(
            user_id=patient_id,
            model_systolic=120.0,
            model_diastolic=80.0,
            measurement_status=MeasurementStatus.COMPLETED,
            measured_at=datetime.utcnow() - timedelta(hours=i)
        )
        for i in range(10)
    ]
    
    mock_readings_res = MagicMock()
    mock_readings_res.scalars.return_value.all.return_value = readings
    
    db.execute.side_effect = [mock_cal_res, mock_readings_res]
    
    drift_service = BPDriftService()
    mock_notification = AsyncMock()
    
    with patch("app.services.bp_drift_service.get_notification_service", return_value=mock_notification):
        await drift_service.check_all_patients(db)
        
        # Drift flag SHOULD be True, reason "calibration_stale"
        assert calibration.drift_flag is True
        assert calibration.drift_reason == 'calibration_stale'
        assert db.commit.call_count == 1
        mock_notification.create_notification.assert_called_once()
        kwargs = mock_notification.create_notification.call_args[1]
        assert kwargs["data"]["drift_reason"] == "calibration_stale"
