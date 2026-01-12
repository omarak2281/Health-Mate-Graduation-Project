"""
Medications router
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from uuid import UUID

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.medication import Medication
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.schemas.medication import MedicationCreate, MedicationUpdate, MedicationResponse

router = APIRouter(prefix="/medications", tags=["Medications"])


@router.post("", response_model=MedicationResponse, status_code=status.HTTP_201_CREATED)
async def create_medication(
    med_data: MedicationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create new medication for current user
    
    Can optionally assign to medicine box drawer
    """
    db_medication = Medication(
        user_id=current_user.id,
        **med_data.model_dump()
    )
    
    db.add(db_medication)
    await db.commit()
    await db.refresh(db_medication)
    
    return db_medication


@router.get("", response_model=List[MedicationResponse])
async def list_medications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    active_only: bool = True
):
    """
    List all medications for current user
    
    - **active_only**: Only return active medications (default True)
    """
    query = select(Medication).where(Medication.user_id == current_user.id)
    
    if active_only:
        query = query.where(Medication.is_active == True)
    
    result = await db.execute(query)
    medications = result.scalars().all()
    
    return medications


@router.get("/{medication_id}", response_model=MedicationResponse)
async def get_medication(
    medication_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get specific medication by ID
    """
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
    medication_id: UUID,
    med_data: MedicationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Update medication
    """
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
    update_data = med_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(medication, field, value)
    
    await db.commit()
    await db.refresh(medication)
    
    return medication


@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_medication(
    medication_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete medication (soft delete by setting is_active = False)
    """
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
    
    medication.is_active = False
    await db.commit()
    
    return None


@router.post("/{medication_id}/confirm")
async def confirm_medication_taken(
    medication_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Confirm medication has been taken
    
    Stops alarm and LED/buzzer
    TODO: Log to medication history
    """
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
    
    # TODO: Turn off medicine box LED/buzzer for assigned drawer
    # TODO: Log to medication history
    
    return {"message": "Medication confirmed", "medication_id": str(medication_id)}
@router.get("/patient/{patient_id}", response_model=List[MedicationResponse])
async def list_patient_medications(
    patient_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List medications for a linked patient
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
        select(Medication).where(Medication.user_id == patient_id).where(Medication.is_active == True)
    )
    return result.scalars().all()
