"""
Computes and persists the 3 fixed daily BP measurement reminder times from
one patient-chosen start time (start, +8h, +16h, wrapping midnight), and
registers/re-registers the matching APScheduler cron jobs.
"""
import logging
from datetime import datetime, timedelta
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from app.models.bp_reminder import BPReminder

logger = logging.getLogger(__name__)

INTERVAL_HOURS = 8
REMINDERS_PER_DAY = 3


def compute_daily_times(start_time: str) -> list[str]:
    """
    Given a "HH:MM" start time, returns 3 "HH:MM" times spaced 8 hours apart,
    wrapping correctly across midnight.
    """
    hour, minute = (int(p) for p in start_time.split(":"))
    base = datetime(2000, 1, 1, hour, minute)
    times = []
    for i in range(REMINDERS_PER_DAY):
        t = base + timedelta(hours=INTERVAL_HOURS * i)
        times.append(t.strftime("%H:%M"))
    return times


class BPReminderService:
    async def schedule_daily(
        self, db: AsyncSession, patient_id: UUID, start_time: str
    ) -> list[BPReminder]:
        """Deletes all existing reminders for the patient and recreates the 3 fixed times."""
        times = compute_daily_times(start_time)

        await db.execute(delete(BPReminder).where(BPReminder.patient_id == patient_id))
        await db.commit()

        reminders = [BPReminder(patient_id=patient_id, scheduled_time=t) for t in times]
        db.add_all(reminders)
        await db.commit()
        for r in reminders:
            await db.refresh(r)

        await self._sync_scheduler_jobs(patient_id, times)
        return reminders

    async def get_reminders(self, db: AsyncSession, patient_id: UUID) -> list[BPReminder]:
        result = await db.execute(
            select(BPReminder)
            .where(BPReminder.patient_id == patient_id)
            .order_by(BPReminder.scheduled_time)
        )
        return list(result.scalars().all())

    async def _sync_scheduler_jobs(self, patient_id: UUID, times: list[str]) -> None:
        """Registers one cron job per reminder time, replacing any previous ones for this patient."""
        from app.core.scheduler import scheduler
        from app.services.scheduler_service import trigger_bp_reminder

        prefix = f"bp_reminder_{patient_id}"
        for job in scheduler.get_jobs():
            if job.id.startswith(prefix):
                try:
                    scheduler.remove_job(job.id)
                except Exception:
                    pass

        for time_str in times:
            try:
                hour, minute = (int(p) for p in time_str.split(":"))
                job_id = f"{prefix}_{time_str.replace(':', '')}"
                scheduler.add_job(
                    trigger_bp_reminder,
                    "cron",
                    hour=hour,
                    minute=minute,
                    id=job_id,
                    args=[patient_id, time_str],
                    replace_existing=True,
                    misfire_grace_time=300,
                )
            except Exception as e:
                logger.error(f"Failed to schedule BP reminder {time_str}: {e}")


bp_reminder_service = BPReminderService()


def get_bp_reminder_service() -> BPReminderService:
    return bp_reminder_service
