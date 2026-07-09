"""Call session schemas."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel

from app.models.call_session import CallStatus, CallType


class CallStartRequest(BaseModel):
    callee_id: UUID
    call_type: CallType


class CallOfferRequest(BaseModel):
    sdp: str
    type: str = "offer"


class CallSessionResponse(BaseModel):
    id: UUID
    caller_id: UUID
    callee_id: UUID
    call_type: CallType
    status: CallStatus
    offer_sdp: Optional[str] = None
    answer_sdp: Optional[str] = None
    duration_seconds: Optional[int] = 0
    started_at: Optional[datetime] = None
    answered_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True
