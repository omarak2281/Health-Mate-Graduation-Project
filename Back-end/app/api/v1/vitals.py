"""
Vitals router for blood pressure management
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from datetime import datetime, timedelta
from typing import List, Optional
from uuid import UUID

from app.core.database import get_db
from app.api.dependencies import get_current_user, get_device_from_headers
from app.models.user import User
from app.models.vital_sign import VitalSign, RiskLevel, MeasurementStatus
from app.schemas.vital_sign import VitalSignCreate, VitalSignResponse, VitalSignDeviceSubmit, CuffCompleteRequest, BPDeviceHeartbeat
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.models.registered_device import RegisteredDevice
from app.services.notification_service import get_notification_service
from app.services.calibration_service import get_calibration_service

router = APIRouter(prefix="/vitals", tags=["Vitals"])


@router.post("/bp", response_model=VitalSignResponse, status_code=status.HTTP_201_CREATED)
async def create_bp_reading(
    vital_data: VitalSignCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create new blood pressure reading
    
    Can be manual or from sensors
    Auto-calculates risk level
    """
    # Create vital sign
    db_vital = VitalSign(
        user_id=current_user.id,
        systolic=vital_data.systolic,
        diastolic=vital_data.diastolic,
        heart_rate=vital_data.heart_rate,
        spo2=vital_data.spo2,
        source=vital_data.source,
        measurement_status=vital_data.measurement_status,
        device_id=vital_data.device_id,
    )
    
    # Calculate risk level
    db_vital.risk_level = db_vital.calculate_risk_level()
    
    db.add(db_vital)
    await db.commit()
    await db.refresh(db_vital)
    
    # Send emergency alert if risk is high or critical
    if db_vital.risk_level in [RiskLevel.LOW, RiskLevel.HIGH, RiskLevel.CRITICAL]:
        notification_service = get_notification_service()
        await notification_service.send_emergency_bp_alert(
            db=db,
            patient_id=str(current_user.id),
            systolic=vital_data.systolic,
            diastolic=vital_data.diastolic,
            risk_level=db_vital.risk_level.value
        )
    
    return db_vital


@router.get("/bp/current", response_model=VitalSignResponse)
async def get_current_bp(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get most recent BP reading for current user.
    Excludes pending / incomplete readings.
    """
    result = await db.execute(
        select(VitalSign)
        .where(
            VitalSign.user_id == current_user.id,
            VitalSign.measurement_status == MeasurementStatus.COMPLETED
        )
        .order_by(desc(VitalSign.measured_at))
        .limit(1)
    )
    
    vital = result.scalar_one_or_none()
    
    if not vital:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No BP readings found"
        )
    
    return vital


@router.get("/bp/history", response_model=List[VitalSignResponse])
async def get_bp_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None
):
    """
    Get BP history for current user with pagination.
    Includes both complete and pending readings.
    """
    query = select(VitalSign).where(VitalSign.user_id == current_user.id)
    
    # Apply date filters if provided
    if start_date:
        query = query.where(VitalSign.measured_at >= start_date)
    if end_date:
        query = query.where(VitalSign.measured_at <= end_date)
    
    # Order by most recent first
    query = query.order_by(desc(VitalSign.measured_at)).limit(limit).offset(offset)
    
    result = await db.execute(query)
    vitals = result.scalars().all()
    
    return vitals


@router.get("/bp/stats")
async def get_bp_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    days: int = Query(default=7, ge=1, le=365)
):
    """
    Get BP statistics for last N days.
    Only includes fully completed readings (excludes null systolic/diastolic).
    """
    start_date = datetime.utcnow() - timedelta(days=days)
    
    result = await db.execute(
        select(VitalSign)
        .where(
            VitalSign.user_id == current_user.id,
            VitalSign.measured_at >= start_date,
            VitalSign.systolic.is_not(None),
            VitalSign.diastolic.is_not(None)
        )
    )
    
    vitals = result.scalars().all()
    
    if not vitals:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No BP readings found in last {days} days"
        )
    
    systolic_values = [v.systolic for v in vitals]
    diastolic_values = [v.diastolic for v in vitals]
    
    return {
        "period_days": days,
        "total_readings": len(vitals),
        "systolic": {
            "avg": sum(systolic_values) / len(systolic_values),
            "min": min(systolic_values),
            "max": max(systolic_values)
        },
        "diastolic": {
            "avg": sum(diastolic_values) / len(diastolic_values),
            "min": min(diastolic_values),
            "max": max(diastolic_values)
        }
    }


@router.get("/patient/{patient_id}/current", response_model=VitalSignResponse)
async def get_patient_current_bp(
    patient_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get most recent BP reading for a linked patient.
    Excludes pending / incomplete readings.
    """
    # Verify link
    link_result = await db.execute(
        select(PatientCaregiverLink)
        .where(
            PatientCaregiverLink.caregiver_id == current_user.id,
            PatientCaregiverLink.patient_id == patient_id,
            PatientCaregiverLink.is_active == True
        )
    )
    if not link_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Patient is not linked to you."
        )

    result = await db.execute(
        select(VitalSign)
        .where(
            VitalSign.user_id == patient_id,
            VitalSign.measurement_status == MeasurementStatus.COMPLETED
        )
        .order_by(desc(VitalSign.measured_at))
        .limit(1)
    )
    vital = result.scalar_one_or_none()
    if not vital:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No BP readings found for this patient"
        )
    return vital


@router.get("/patient/{patient_id}/history", response_model=List[VitalSignResponse])
async def get_patient_bp_history(
    patient_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0)
):
    """
    Get BP history for a linked patient.
    """
    # Verify link
    link_result = await db.execute(
        select(PatientCaregiverLink)
        .where(
            PatientCaregiverLink.caregiver_id == current_user.id,
            PatientCaregiverLink.patient_id == patient_id,
            PatientCaregiverLink.is_active == True
        )
    )
    if not link_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Patient is not linked to you."
        )

    result = await db.execute(
        select(VitalSign)
        .where(VitalSign.user_id == patient_id)
        .order_by(desc(VitalSign.measured_at))
        .limit(limit)
        .offset(offset)
    )
    return result.scalars().all()


@router.post("/bp/heartbeat")
async def register_device_heartbeat(
    payload: BPDeviceHeartbeat,
    device: RegisteredDevice = Depends(get_device_from_headers),
    db: AsyncSession = Depends(get_db)
):
    """
    Periodic heartbeat from the blood pressure device.
    Updates last seen time and sensors diagnostics.
    """
    device.last_seen_at = datetime.utcnow()
    device.last_leads_connected = payload.leads_connected
    device.last_finger_detected = payload.finger_detected
    
    db.add(device)
    await db.commit()
    return {"status": "success"}


@router.post("/bp/submit", response_model=VitalSignResponse, status_code=status.HTTP_201_CREATED)
async def submit_device_reading(
    payload: VitalSignDeviceSubmit,
    device: RegisteredDevice = Depends(get_device_from_headers),
    db: AsyncSession = Depends(get_db)
):
    """
    Endpoint for hardware device to submit raw PPG + ECG signal readings.
    Requires device hardware token header authentication.
    """
    # Run prediction model (or Keras engine)
    from app.services.abp_prediction_service import get_abp_service
    abp_service = get_abp_service()
    prediction = abp_service.predict_bp(payload.ppg_signal, payload.ecg_signal)
    
    if prediction.get("prediction_status") == "model_not_ready":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="model_not_ready"
        )

    # SpO2 is only trusted inside the physiologically plausible 70-100% band;
    # anything else is a sensor-quality failure and stored as NULL, never as a
    # bad number.
    spo2_value = (
        payload.spo2
        if payload.spo2 is not None and 70 <= payload.spo2 <= 100
        else None
    )
    heart_rate_value = (
        payload.heart_rate
        if payload.heart_rate is not None and 30 <= payload.heart_rate <= 220
        else None
    )

    if prediction.get("prediction_status") != "success":
        # Persist a REJECTED reading instead of raising, so the app polling
        # /bp/history can show the patient an actionable rejection reason
        # rather than silently timing out.
        if device.last_finger_detected is False:
            rejection_reason = "finger_missing"
        elif device.last_leads_connected is False:
            rejection_reason = "leads_off"
        else:
            rejection_reason = "poor_signal"

        rejected_vital = VitalSign(
            user_id=device.patient_id,
            systolic=None,
            diastolic=None,
            heart_rate=heart_rate_value,
            spo2=spo2_value,
            source="sensor",
            measurement_status=MeasurementStatus.REJECTED,
            rejection_reason=rejection_reason,
            device_id=payload.device_id,
            signal_quality=prediction.get("signal_quality", 0.0),
            risk_level=RiskLevel.NORMAL,
        )
        db.add(rejected_vital)
        await db.commit()
        await db.refresh(rejected_vital)
        return rejected_vital

    # Get calibration factors if available
    cal_service = get_calibration_service()
    cal_res = await cal_service.apply_calibration(
        db, device.patient_id, prediction["systolic"], prediction["diastolic"]
    )
    
    calibration_status = cal_res["calibration_status"]
    needs_cuff_confirmation = calibration_status in {
        "not_calibrated",
        "weak",
        "recalibration_due",
    }
    systolic = None if needs_cuff_confirmation else int(round(cal_res["systolic"]))
    diastolic = None if needs_cuff_confirmation else int(round(cal_res["diastolic"]))
    measurement_status = (
        MeasurementStatus.COMPLETED_PENDING_BP
        if needs_cuff_confirmation
        else MeasurementStatus.COMPLETED
    )

    db_vital = VitalSign(
        user_id=device.patient_id,
        systolic=systolic,
        diastolic=diastolic,
        heart_rate=heart_rate_value
        if heart_rate_value is not None
        else int(round(prediction["heart_rate"])),
        spo2=spo2_value,
        source="sensor",
        measurement_status=measurement_status,
        device_id=payload.device_id,
        signal_quality=prediction.get("signal_quality", 1.0),
        confidence=prediction.get("signal_quality", 1.0),
        risk_level=RiskLevel.NORMAL,
        model_systolic=prediction["systolic"],
        model_diastolic=prediction["diastolic"],
        calibrated_systolic=cal_res["systolic"],
        calibrated_diastolic=cal_res["diastolic"],
        calibration_status=calibration_status
    )
    db_vital.risk_level = db_vital.calculate_risk_level()

    db.add(db_vital)
    await db.commit()
    await db.refresh(db_vital)

    # Auto-completed calibrated readings must alert caregivers too — otherwise
    # only manual and cuff-confirmed readings would ever trigger the emergency
    # path. Cooldown inside the service prevents duplicates.
    if (
        db_vital.measurement_status == MeasurementStatus.COMPLETED
        and db_vital.risk_level in [RiskLevel.LOW, RiskLevel.HIGH, RiskLevel.CRITICAL]
        and db_vital.systolic is not None
        and db_vital.diastolic is not None
    ):
        notification_service = get_notification_service()
        await notification_service.send_emergency_bp_alert(
            db=db,
            patient_id=str(device.patient_id),
            systolic=db_vital.systolic,
            diastolic=db_vital.diastolic,
            risk_level=db_vital.risk_level.value
        )

    return db_vital


@router.post("/bp/complete", response_model=VitalSignResponse)
async def complete_bp_reading(
    payload: CuffCompleteRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Complete a pending sensor reading with manual cuff systolic and diastolic values.
    Saves calibration samples and triggers caregiver emergency alerts.
    """
    # 1. Find the vital sign reading
    result = await db.execute(
        select(VitalSign)
        .where(
            VitalSign.id == payload.vital_sign_id,
            VitalSign.user_id == current_user.id
        )
    )
    vital = result.scalar_one_or_none()
    
    if not vital:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vital sign reading not found"
        )
        
    # COMPLETED readings are also accepted (not just COMPLETED_PENDING_BP):
    # the Settings recalibration flow pairs a cuff value with the latest
    # device reading, which auto-completes once the patient is calibrated.
    # The cuff value is ground truth, so overwriting systolic/diastolic with
    # it is correct in both cases.
    allowed_statuses = (
        MeasurementStatus.COMPLETED_PENDING_BP,
        MeasurementStatus.COMPLETED,
    )
    if vital.measurement_status not in allowed_statuses or vital.source != "sensor":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot complete reading. Current status is {vital.measurement_status.value}"
        )
        
    # 2. Update with cuff values
    vital.systolic = payload.systolic
    vital.diastolic = payload.diastolic
    vital.measurement_status = MeasurementStatus.COMPLETED
    vital.risk_level = vital.calculate_risk_level()
    
    # 3. Add to device calibration
    cal_service = get_calibration_service()
    if vital.model_systolic is not None and vital.model_diastolic is not None:
        try:
            await cal_service.add_calibration_sample(
                db,
                patient_id=current_user.id,
                model_sbp=vital.model_systolic,
                model_dbp=vital.model_diastolic,
                cuff_sbp=payload.systolic,
                cuff_dbp=payload.diastolic,
                signal_quality=vital.signal_quality or 1.0
            )
            status = await cal_service.get_calibration_status(db, current_user.id)
            vital.calibration_status = status["status"]
        except Exception as e:
            # log warning but allow completion to persist
            print(f"Failed to record calibration sample: {e}")
            
    db.add(vital)
    await db.commit()
    await db.refresh(vital)
    
    # 4. Trigger emergency alert if risk is high/critical
    if vital.risk_level in [RiskLevel.LOW, RiskLevel.HIGH, RiskLevel.CRITICAL]:
        notification_service = get_notification_service()
        await notification_service.send_emergency_bp_alert(
            db=db,
            patient_id=str(current_user.id),
            systolic=vital.systolic,
            diastolic=vital.diastolic,
            risk_level=vital.risk_level.value
        )
        
    return vital


@router.get("/bp/calibration/status")
async def get_calibration_info(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get calibration parameters status for current user.
    """
    cal_service = get_calibration_service()
    return await cal_service.get_calibration_status(db, current_user.id)


class ManualCalibrationRequest(BaseModel):
    cuff_systolic: int = Field(..., ge=50, le=300)
    cuff_diastolic: int = Field(..., ge=30, le=200)


@router.post("/bp/calibration", response_model=VitalSignResponse)
async def trigger_calibration_manually(
    payload: ManualCalibrationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Manually submit a cuff BP validation reading matching the last pending sensor measurement.
    """
    result = await db.execute(
        select(VitalSign)
        .where(
            VitalSign.user_id == current_user.id,
            VitalSign.measurement_status == MeasurementStatus.COMPLETED_PENDING_BP
        )
        .order_by(desc(VitalSign.measured_at))
        .limit(1)
    )
    vital = result.scalar_one_or_none()
    
    if not vital:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No pending device readings found to calibrate"
        )
        
    # Map to complete request logic
    complete_payload = CuffCompleteRequest(
        vital_sign_id=vital.id,
        systolic=payload.cuff_systolic,
        diastolic=payload.cuff_diastolic
    )
    return await complete_bp_reading(complete_payload, current_user, db)
