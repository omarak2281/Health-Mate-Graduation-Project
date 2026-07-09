"""Audio/video call session endpoints."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.models.call_session import CallSession, CallStatus
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.models.user import User, UserRole
from app.schemas.call import CallOfferRequest, CallSessionResponse, CallStartRequest
from app.services.notification_service import get_notification_service

router = APIRouter(prefix="/calls", tags=["Calls"])

ACTIVE_STATUSES = (CallStatus.RINGING, CallStatus.IN_CALL)


async def _get_user_or_404(db: AsyncSession, user_id: UUID) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user


def _patient_and_caregiver(current_user: User, other_user: User) -> tuple[UUID, UUID]:
    if current_user.role == UserRole.PATIENT and other_user.role == UserRole.CAREGIVER:
        return current_user.id, other_user.id
    if current_user.role == UserRole.CAREGIVER and other_user.role == UserRole.PATIENT:
        return other_user.id, current_user.id
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Calls are only allowed between linked patients and caregivers",
    )


async def _require_active_link(
    db: AsyncSession,
    patient_id: UUID,
    caregiver_id: UUID,
) -> None:
    result = await db.execute(
        select(PatientCaregiverLink).where(
            PatientCaregiverLink.patient_id == patient_id,
            PatientCaregiverLink.caregiver_id == caregiver_id,
            PatientCaregiverLink.is_active == True,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Call is only allowed between linked patient and caregiver",
        )


async def _get_call_for_participant(
    db: AsyncSession,
    call_id: UUID,
    user_id: UUID,
) -> CallSession:
    result = await db.execute(
        select(CallSession).where(
            CallSession.id == call_id,
            or_(CallSession.caller_id == user_id, CallSession.callee_id == user_id),
        )
    )
    call = result.scalar_one_or_none()
    if not call:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Call session not found",
        )
    return call


@router.post("", response_model=CallSessionResponse, status_code=status.HTTP_201_CREATED)
async def start_call(
    payload: CallStartRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Start a ringing one-to-one call between a linked patient and caregiver."""
    callee = await _get_user_or_404(db, payload.callee_id)
    patient_id, caregiver_id = _patient_and_caregiver(current_user, callee)
    await _require_active_link(db, patient_id, caregiver_id)

    active_result = await db.execute(
        select(CallSession).where(
            or_(
                CallSession.caller_id == patient_id,
                CallSession.callee_id == patient_id,
            ),
            CallSession.status.in_(ACTIVE_STATUSES),
        )
    )
    if active_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Patient is currently busy",
        )

    call = CallSession(
        caller_id=current_user.id,
        callee_id=callee.id,
        call_type=payload.call_type,
        status=CallStatus.RINGING,
        started_at=datetime.utcnow(),
    )
    db.add(call)
    await db.commit()
    await db.refresh(call)

    return call


@router.get("/{call_id}", response_model=CallSessionResponse)
async def get_call(
    call_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await _get_call_for_participant(db, call_id, current_user.id)


@router.post("/{call_id}/offer", response_model=CallSessionResponse)
async def set_call_offer(
    call_id: UUID,
    payload: CallOfferRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    call = await _get_call_for_participant(db, call_id, current_user.id)
    if call.caller_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only caller can set offer")
    if call.status != CallStatus.RINGING:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Call is not ringing")
    if not payload.sdp.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Offer SDP is required")

    callee = await _get_user_or_404(db, call.callee_id)
    call.offer_sdp = payload.sdp
    await db.commit()
    await db.refresh(call)

    notification_service = get_notification_service()
    await notification_service.send_incoming_call_notification(
        db=db,
        callee_id=str(callee.id),
        caller_name=current_user.full_name,
        call_type=call.call_type.value,
        session_id=str(call.id),
        caller_id=str(current_user.id),
        caller_phone=current_user.phone,
        caller_avatar=current_user.profile_image_url,
    )

    return call


@router.post("/{call_id}/accept", response_model=CallSessionResponse)
async def accept_call(
    call_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    call = await _get_call_for_participant(db, call_id, current_user.id)
    if call.callee_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only callee can accept")
    if call.status != CallStatus.RINGING:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Call is not ringing")

    call.status = CallStatus.IN_CALL
    call.answered_at = datetime.utcnow()
    await db.commit()
    await db.refresh(call)
    return call


@router.post("/{call_id}/reject", response_model=CallSessionResponse)
async def reject_call(
    call_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    call = await _get_call_for_participant(db, call_id, current_user.id)
    if call.callee_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only callee can reject")
    if call.status not in ACTIVE_STATUSES:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Call is already closed")

    call.status = CallStatus.REJECTED
    call.ended_at = datetime.utcnow()
    await db.commit()
    await db.refresh(call)
    return call


@router.post("/{call_id}/busy", response_model=CallSessionResponse)
async def busy_call(
    call_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    call = await _get_call_for_participant(db, call_id, current_user.id)
    if call.callee_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only callee can mark busy")

    call.status = CallStatus.BUSY
    call.ended_at = datetime.utcnow()
    await db.commit()
    await db.refresh(call)
    return call


@router.post("/{call_id}/end", response_model=CallSessionResponse)
async def end_call(
    call_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    call = await _get_call_for_participant(db, call_id, current_user.id)
    if call.status not in ACTIVE_STATUSES:
        return call

    now = datetime.utcnow()
    call.status = CallStatus.ENDED
    call.ended_at = now
    if call.answered_at:
        call.duration_seconds = max(0, int((now - call.answered_at).total_seconds()))
    await db.commit()
    await db.refresh(call)
    return call
