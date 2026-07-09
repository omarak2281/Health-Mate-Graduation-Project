"""
User management router
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from uuid import UUID

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.core.security import verify_password, get_password_hash
from app.models.user import User
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.schemas.user import UserResponse, UserUpdate, PasswordChange, FcmTokenUpdate

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user)
):
    """
    Get current user profile
    """
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_profile(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Update current user profile
    """
    update_data = user_data.model_dump(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(current_user, field, value)
    
    await db.commit()
    await db.refresh(current_user)
    
    return current_user


@router.put("/me/fcm-token", status_code=200)
async def update_fcm_token(
    token_data: FcmTokenUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Register or update the FCM device token for push notifications.

    Called by the Flutter app on every login/startup after Firebase
    generates a new (or refreshed) FCM token for the device.
    """
    current_user.fcm_token = token_data.fcm_token
    await db.commit()
    return {"message": "FCM token updated successfully"}


@router.put("/me/password")
async def change_password(
    password_data: PasswordChange,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Change password for current user
    """
    # Verify current password
    if not verify_password(password_data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect current password"
        )
    
    # Update password
    current_user.hashed_password = get_password_hash(password_data.new_password)
    await db.commit()
    
    return {"message": "Password updated successfully"}


@router.get("/linked", response_model=List[UserResponse])
async def get_linked_users(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all linked users
    
    - For patients: returns linked caregivers
    - For caregivers: returns linked patients
    """
    from app.models.user import UserRole
    
    if current_user.role == UserRole.PATIENT:
        # Get caregivers
        result = await db.execute(
            select(User)
            .join(PatientCaregiverLink, PatientCaregiverLink.caregiver_id == User.id)
            .where(PatientCaregiverLink.patient_id == current_user.id)
            .where(PatientCaregiverLink.is_active == True)
        )
    else:  # Caregiver
        # Get patients
        result = await db.execute(
            select(User)
            .join(PatientCaregiverLink, PatientCaregiverLink.patient_id == User.id)
            .where(PatientCaregiverLink.caregiver_id == current_user.id)
            .where(PatientCaregiverLink.is_active == True)
        )
    
    linked_users = result.scalars().all()
    
    return linked_users


def _normalize_phone(phone: str) -> str:
    """Normalize a phone number for duplicate comparison (digits and + only)."""
    return "".join(ch for ch in phone if ch.isdigit() or ch == "+")


async def _sync_caregiver_into_patient_contacts(db, patient_id, caregiver) -> None:
    """
    Add the caregiver's registered phone number to the patient's in-app
    medical contacts (family type) when a link is created or reactivated.
    Skips silently if the caregiver has no phone or a contact with the same
    phone number already exists (de-duplication by normalized number).
    """
    from app.models.medical_contact import MedicalContact, ContactType

    if not caregiver.phone or not caregiver.phone.strip():
        return

    result = await db.execute(
        select(MedicalContact).where(MedicalContact.user_id == patient_id)
    )
    existing_contacts = result.scalars().all()
    caregiver_phone = _normalize_phone(caregiver.phone)
    if any(
        _normalize_phone(c.phone) == caregiver_phone for c in existing_contacts
    ):
        return

    db.add(
        MedicalContact(
            user_id=patient_id,
            name=caregiver.full_name,
            phone=caregiver.phone,
            contact_type=ContactType.FAMILY,
        )
    )


@router.post("/link/{user_id}")
async def link_user(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Link current user with another user
    
    - Caregivers can link to patients
    - Patients can accept caregiver links
    
    In production, this should use QR code scanning
    """
    from app.models.user import UserRole
    
    # Get target user
    result = await db.execute(select(User).where(User.id == user_id))
    target_user = result.scalar_one_or_none()
    
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Validate role combination
    if current_user.role == UserRole.CAREGIVER and target_user.role == UserRole.PATIENT:
        patient_id = target_user.id
        caregiver_id = current_user.id
    elif current_user.role == UserRole.PATIENT and target_user.role == UserRole.CAREGIVER:
        patient_id = current_user.id
        caregiver_id = target_user.id
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Can only link patients with caregivers"
        )
    
    # Check if link already exists
    result = await db.execute(
        select(PatientCaregiverLink)
        .where(PatientCaregiverLink.patient_id == patient_id)
        .where(PatientCaregiverLink.caregiver_id == caregiver_id)
    )
    
    existing_link = result.scalar_one_or_none()
    
    if existing_link:
        if existing_link.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Users are already linked"
            )
        else:
            # Reactivate existing link
            existing_link.is_active = True
            from app.services.patient_caregiver_service import assign_is_primary_for_new_link
            await assign_is_primary_for_new_link(db, patient_id, existing_link)
            caregiver = current_user if caregiver_id == current_user.id else target_user
            await _sync_caregiver_into_patient_contacts(db, patient_id, caregiver)
            await db.commit()
            return {"message": "Link reactivated"}
    
    # Create new link
    link = PatientCaregiverLink(
        patient_id=patient_id,
        caregiver_id=caregiver_id
    )
    from app.services.patient_caregiver_service import assign_is_primary_for_new_link
    await assign_is_primary_for_new_link(db, patient_id, link)
    db.add(link)
    caregiver = current_user if caregiver_id == current_user.id else target_user
    await _sync_caregiver_into_patient_contacts(db, patient_id, caregiver)
    await db.commit()

    return {"message": "Users linked successfully"}


@router.delete("/linked/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unlink_user(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Unlink user (soft delete)
    """
    from app.models.user import UserRole
    
    # Determine patient and caregiver IDs
    if current_user.role == UserRole.PATIENT:
        patient_id = current_user.id
        caregiver_id = user_id
    else:
        patient_id = user_id
        caregiver_id = current_user.id
    
    # Find link
    result = await db.execute(
        select(PatientCaregiverLink)
        .where(PatientCaregiverLink.patient_id == patient_id)
        .where(PatientCaregiverLink.caregiver_id == caregiver_id)
    )
    
    link = result.scalar_one_or_none()
    
    if not link:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Link not found"
        )
    
    # Soft delete
    link.is_active = False
    from app.services.patient_caregiver_service import promote_new_primary_if_needed
    await promote_new_primary_if_needed(db, patient_id, link)
    await db.commit()
    
    return None


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete current user account (Hard delete)
    
    CRITICAL: This deletes both Database records AND Firebase account
    """
    from app.core.firebase_admin import delete_firebase_user
    import traceback
    
    firebase_uid = current_user.firebase_uid
    
    try:
        # 1. Delete from Database (CASCADE handles related data)
        await db.delete(current_user)
        await db.commit()
        
        # 2. Delete from Firebase (if applicable)
        if firebase_uid:
            try:
                await delete_firebase_user(firebase_uid)
            except Exception as fe:
                print(f"⚠️ Warning: Failed to delete user from Firebase: {fe}")
                # We don't fail the whole request if Firebase deletion fails 
                # because the DB record is already gone.
        
        return None
        
    except Exception as e:
        await db.rollback()
        print(f"❌ DELETE ACCOUNT FAILED: {str(e)}")
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Account deletion failed. Error: {str(e)}"
        )
