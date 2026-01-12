"""
Medical contacts router
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from uuid import UUID

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.medical_contact import MedicalContact
from app.schemas.medical_contact import MedicalContactCreate, MedicalContactUpdate, MedicalContactResponse

router = APIRouter(prefix="/contacts", tags=["Medical Contacts"])


@router.post("", response_model=MedicalContactResponse, status_code=status.HTTP_201_CREATED)
async def create_contact(
    contact_data: MedicalContactCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new medical contact
    """
    db_contact = MedicalContact(
        user_id=current_user.id,
        **contact_data.model_dump()
    )
    
    db.add(db_contact)
    await db.commit()
    await db.refresh(db_contact)
    
    return db_contact


@router.get("", response_model=List[MedicalContactResponse])
async def list_contacts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List all medical contacts for current user
    """
    result = await db.execute(
        select(MedicalContact).where(MedicalContact.user_id == current_user.id)
    )
    return result.scalars().all()


@router.put("/{contact_id}", response_model=MedicalContactResponse)
async def update_contact(
    contact_id: UUID,
    contact_data: MedicalContactUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Update a medical contact
    """
    result = await db.execute(
        select(MedicalContact)
        .where(MedicalContact.id == contact_id)
        .where(MedicalContact.user_id == current_user.id)
    )
    db_contact = result.scalar_one_or_none()
    
    if not db_contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    update_data = contact_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_contact, field, value)
    
    await db.commit()
    await db.refresh(db_contact)
    
    return db_contact


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contact(
    contact_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete a medical contact
    """
    result = await db.execute(
        select(MedicalContact)
        .where(MedicalContact.id == contact_id)
        .where(MedicalContact.user_id == current_user.id)
    )
    db_contact = result.scalar_one_or_none()
    
    if not db_contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    await db.delete(db_contact)
    await db.commit()
    
    return None
