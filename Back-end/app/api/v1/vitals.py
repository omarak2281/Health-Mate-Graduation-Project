"""
Vitals router for blood pressure management
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from datetime import datetime, timedelta
from typing import List, Optional
from uuid import UUID

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.vital_sign import VitalSign, RiskLevel
from app.schemas.vital_sign import VitalSignCreate, VitalSignResponse
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.services.notification_service import get_notification_service

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
        source=vital_data.source
    )
    
    # Calculate risk level
    db_vital.risk_level = db_vital.calculate_risk_level()
    
    db.add(db_vital)
    await db.commit()
    await db.refresh(db_vital)
    
    # Send emergency alert if risk is high or critical
    if db_vital.risk_level in [RiskLevel.HIGH, RiskLevel.CRITICAL]:
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
    Get most recent BP reading for current user
    """
    result = await db.execute(
        select(VitalSign)
        .where(VitalSign.user_id == current_user.id)
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
    Get BP history for current user with pagination
    
    - **limit**: Max number of records (default 50, max 200)
    - **offset**: Number of records to skip
    - **start_date**: Filter from date (optional)
    - **end_date**: Filter to date (optional)
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
    Get BP statistics for last N days
    
    Returns average, min, max for systolic and diastolic
    """
    start_date = datetime.utcnow() - timedelta(days=days)
    
    result = await db.execute(
        select(VitalSign)
        .where(VitalSign.user_id == current_user.id)
        .where(VitalSign.measured_at >= start_date)
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
    Get most recent BP reading for a linked patient
    """
    # Verify link
    link_result = await db.execute(
        select(PatientCaregiverLink)
        .where(PatientCaregiverLink.caregiver_id == current_user.id)
        .where(PatientCaregiverLink.patient_id == patient_id)
        .where(PatientCaregiverLink.is_active == True)
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
    Get BP history for a linked patient
    """
    # Verify link
    link_result = await db.execute(
        select(PatientCaregiverLink)
        .where(PatientCaregiverLink.caregiver_id == current_user.id)
        .where(PatientCaregiverLink.patient_id == patient_id)
        .where(PatientCaregiverLink.is_active == True)
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
