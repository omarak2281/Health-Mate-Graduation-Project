"""
Medications router
"""

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
import uuid

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.services.iot_mock import get_iot_service
from app.models.user import User
from app.models.medication import Medication
from app.models.medication_adherence import MedicationAdherence
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.schemas.medication import MedicineCreate, MedicationUpdate, MedicationResponse, MedicationAdherenceCreate, MedicationAdherenceResponse
from app.services.scheduler_service import (
    schedule_medication_jobs, 
    delete_medication_jobs, 
    schedule_snooze_job
)
from app.services.iot_service import iot_service
from datetime import datetime

router = APIRouter(prefix="/medications", tags=["Medications"])


@router.post("", response_model=MedicationResponse, status_code=status.HTTP_201_CREATED)
async def create_medication(
    med_data: MedicineCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create new medication
    
    If patient_id is provided, assigns to that patient (requires linked caregiver).
    Triggers IoT hardware alert if drawer assigned.
    """
    target_user_id = current_user.id
    
    # If a patient_id is provided, verify relation and assign to patient
    if med_data.patient_id:
        link_result = await db.execute(
            select(PatientCaregiverLink)
            .where(PatientCaregiverLink.caregiver_id == current_user.id)
            .where(PatientCaregiverLink.patient_id == med_data.patient_id)
            .where(PatientCaregiverLink.is_active == True)
        )
        if not link_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot add medication for this patient. They are not linked to you."
            )
        target_user_id = med_data.patient_id

    # Create medication data
    med_dict = med_data.model_dump(exclude={"patient_id"})
    
    db_medication = Medication(
        user_id=target_user_id,
        **med_dict
    )
    
    db.add(db_medication)
    await db.commit()
    await db.refresh(db_medication)

    # Schedule alarm jobs
    await schedule_medication_jobs(db_medication, db)
    
    return db_medication


@router.get("", response_model=List[MedicationResponse])
async def list_medications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all medications for current user"""
    result = await db.execute(select(Medication).where(Medication.user_id == current_user.id))
    return result.scalars().all()


@router.get("/{medication_id}", response_model=MedicationResponse)
async def get_medication(
    medication_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get specific medication details"""
    result = await db.execute(
        select(Medication)
        .where(Medication.id == medication_id)
        .where(Medication.user_id == current_user.id)
    )
    medication = result.scalar_one_or_none()
    
    if not medication:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication not found"
        )
    
    return medication


@router.put("/{medication_id}", response_model=MedicationResponse)
async def update_medication(
    medication_id: uuid.UUID,
    med_data: MedicationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update medication details"""
    result = await db.execute(
        select(Medication)
        .where(Medication.id == medication_id)
        .where(Medication.user_id == current_user.id)
    )
    medication = result.scalar_one_or_none()
    
    if not medication:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication not found"
        )
    
    # Update fields
    for field, value in med_data.model_dump(exclude_unset=True).items():
        setattr(medication, field, value)
    
    await db.commit()
    await db.refresh(medication)
    
    # Update scheduled jobs
    await schedule_medication_jobs(medication, db)
    
    return medication


@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_medication(
    medication_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete medication and all associated adherence records."""
    result = await db.execute(
        select(Medication)
        .where(Medication.id == medication_id)
        .where(Medication.user_id == current_user.id)
    )
    medication = result.scalar_one_or_none()

    if not medication:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication not found"
        )

    # 1. Explicitly delete all adherence logs for this medication first.
    #    This avoids the IntegrityError caused by SQLAlchemy attempting to
    #    SET medication_id = NULL (NOT NULL constraint violation).
    adherence_result = await db.execute(
        select(MedicationAdherence)
        .where(MedicationAdherence.medication_id == medication_id)
    )
    adherence_records = adherence_result.scalars().all()
    for record in adherence_records:
        await db.delete(record)

    # 2. Now safely delete the medication itself.
    await db.delete(medication)
    await db.commit()

    # 3. Remove scheduled alarm jobs from the background scheduler AFTER commit,
    #    so sync_user_medication_jobs won't find the deleted medication.
    await delete_medication_jobs(medication_id, current_user.id, db)

    return None


@router.post("/taken", status_code=status.HTTP_200_OK)
async def mark_medications_taken(
    medication_ids: List[uuid.UUID],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Mark multiple medications as taken and deactivate hardware.
    """
    for med_id in medication_ids:
        adherence = MedicationAdherence(
            medication_id=med_id,
            user_id=current_user.id,
            taken_at=datetime.utcnow()
        )
        db.add(adherence)
    
    await db.commit()
    
    # Deactivate all ESP32 drawers
    await iot_service.deactivate_all()
    
    return {"status": "success", "message": f"{len(medication_ids)} medications marked as taken"}


@router.post("/snooze", status_code=status.HTTP_200_OK)
async def snooze_medications(
    medication_ids: List[uuid.UUID],
    current_user: User = Depends(get_current_user),
):
    """
    Schedules a server-side snooze for the specified medications.
    """
    await schedule_snooze_job(current_user.id, medication_ids)
    return {"status": "success", "message": "Cloud snooze scheduled successfully"}


@router.post("/{medication_id}/confirm", response_model=MedicationAdherenceResponse)
async def confirm_medication_taken(
    medication_id: uuid.UUID,
    adherence_data: MedicationAdherenceCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Log that a medication was taken
    """
    result = await db.execute(select(Medication).where(Medication.id == medication_id))
    medication = result.scalar_one_or_none()
    
    if not medication:
        raise HTTPException(status_code=404, detail="Medication not found")
        
    if medication.user_id != current_user.id:
        # Caregiver check
        link_check = await db.execute(
            select(PatientCaregiverLink)
            .where(PatientCaregiverLink.caregiver_id == current_user.id)
            .where(PatientCaregiverLink.patient_id == medication.user_id)
        )
        if not link_check.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Not authorized")

    adherence = MedicationAdherence(
        medication_id=medication.id,
        user_id=medication.user_id,
        taken_at=adherence_data.taken_at,
        image_url=adherence_data.image_url
    )
    db.add(adherence)
    
    # Handle Hardware Deactivation
    await iot_service.deactivate_all()

    await db.commit()
    await db.refresh(adherence)
    return adherence


@router.get("/{medication_id}/adherence", response_model=List[MedicationAdherenceResponse])
async def get_medication_adherence(
    medication_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get adherence history for a specific medication"""
    # Verify ownership or link
    result = await db.execute(select(Medication).where(Medication.id == medication_id))
    medication = result.scalar_one_or_none()
    
    if not medication or (medication.user_id != current_user.id):
        # Basic check, caregiver check could be added here too
        raise HTTPException(status_code=403, detail="Not authorized")

    adherence_result = await db.execute(
        select(MedicationAdherence)
        .where(MedicationAdherence.medication_id == medication_id)
        .order_by(MedicationAdherence.taken_at.desc())
    )
    return adherence_result.scalars().all()
