"""
Router for the 3 fixed daily BP measurement reminders derived from one
patient-chosen start time (start, +8h, +16h).
"""
import re
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.services.bp_reminder_service import get_bp_reminder_service

router = APIRouter(prefix="/bp/reminders", tags=["BP Reminders"])

TIME_RE = re.compile(r"^([01]\d|2[0-3]):([0-5]\d)$")


class ScheduleDailyRequest(BaseModel):
    start_time: str  # "HH:MM", 24h

    @field_validator("start_time")
    @classmethod
    def validate_time(cls, v: str) -> str:
        if not TIME_RE.match(v):
            raise ValueError("start_time must be in HH:MM 24-hour format")
        return v


class BPReminderResponse(BaseModel):
    id: str
    scheduled_time: str

    class Config:
        from_attributes = True


@router.post("/schedule-daily", response_model=list[BPReminderResponse])
async def schedule_daily_reminders(
    payload: ScheduleDailyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Deletes and recreates the patient's 3 daily BP reminders from one chosen
    start time, and re-registers the matching scheduler jobs.
    """
    service = get_bp_reminder_service()
    reminders = await service.schedule_daily(db, current_user.id, payload.start_time)
    return [
        BPReminderResponse(id=str(r.id), scheduled_time=r.scheduled_time)
        for r in reminders
    ]


@router.get("", response_model=list[BPReminderResponse])
async def get_daily_reminders(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Read-only list of the patient's currently scheduled daily BP reminders."""
    service = get_bp_reminder_service()
    reminders = await service.get_reminders(db, current_user.id)
    return [
        BPReminderResponse(id=str(r.id), scheduled_time=r.scheduled_time)
        for r in reminders
    ]
