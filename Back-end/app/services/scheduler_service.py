import uuid
import logging
import datetime
import asyncio
from typing import List
from sqlalchemy import select
from app.core.scheduler import scheduler
from app.core.database import AsyncSessionLocal
from app.models.medication import Medication
from app.services.iot_service import esp32_service
from app.services.notification_service import notification_service
from app.models.notification import NotificationType

logger = logging.getLogger(__name__)


async def trigger_medication_alarm(user_id: uuid.UUID, time_str: str):
    """
    Core alarm trigger: runs at the scheduled cron time.
    """
    logger.info(f"🔔 Triggering alarm for user: {user_id} at {time_str}")

    async with AsyncSessionLocal() as db:
        try:
            # 1. Find all medications for this user
            result = await db.execute(
                select(Medication).where(Medication.user_id == user_id)
            )
            all_meds = result.scalars().all()
            
            # 2. Filter medications scheduled for this exact time
            relevant_meds = [m for m in all_meds if time_str in (m.scheduled_times or [])]

            if not relevant_meds:
                logger.warning(f"⚠️ No medications matched the time '{time_str}'")
                return

            # 3. Collect drawers for hardware trigger
            drawers_to_activate = [
                m.drawer_number
                for m in relevant_meds
                if m.use_smart_box and m.drawer_number
            ]

            # 4. Build notification payload
            if len(relevant_meds) == 1:
                med = relevant_meds[0]
                body = med.name
                payload = {
                    "type": "single",
                    "medicine": {
                        "id": str(med.id),
                        "name": med.name,
                        "dosage": med.dosage,
                        "instructions": med.instructions or "",
                        "drawer_number": med.drawer_number,
                        "image_url": med.image_url or "",
                        "scheduled_times": med.scheduled_times or [],
                    },
                }
                title = "medications.alarm_title"
            else:
                medication_names = [m.name for m in relevant_meds]
                body = ", ".join(medication_names)
                payload = {
                    "type": "grouped",
                    "medicines": [
                        {
                            "id": str(m.id),
                            "name": m.name,
                            "dosage": m.dosage,
                            "instructions": m.instructions or "",
                            "drawer_number": m.drawer_number,
                            "scheduled_times": m.scheduled_times or [],
                        }
                        for m in relevant_meds
                    ],
                }
                title = "medications.alarm_title"

            # 5. Persist notification + send FCM push
            await notification_service.create_notification(
                db=db,
                user_id=str(user_id),
                notification_type=NotificationType.MEDICATION_REMINDER,
                title=title,
                message=body,
                data=payload,
            )

            # 6. Activate ESP32 drawers (Non-blocking background task)
            if drawers_to_activate:
                logger.info(f"💡 Background activation of ESP32 drawers: {drawers_to_activate}")
                # Use asyncio.create_task to fire-and-forget hardware trigger
                asyncio.create_task(esp32_service.activate(drawers_to_activate))

            # 7. Final commit to ensure session doesn't rollback
            await db.commit()

        except Exception as e:
            logger.error(f"❌ Error in trigger_medication_alarm: {str(e)}", exc_info=True)


async def schedule_snooze_job(user_id: uuid.UUID, medication_ids: List[uuid.UUID], delay_minutes: int = 5):
    """
    Schedules a one-time 'snooze' alarm to fire after a delay.
    Convert UUIDs to strings for safe serialization in APScheduler.
    """
    run_time = datetime.datetime.now() + datetime.timedelta(minutes=delay_minutes)
    job_id = f"snooze_{user_id}_{uuid.uuid4().hex[:8]}"
    
    # Convert UUIDs to strings to avoid serialization issues
    med_id_strs = [str(mid) for mid in medication_ids]
    
    scheduler.add_job(
        trigger_medication_alarm_by_ids,
        "date",
        run_date=run_time,
        id=job_id,
        args=[str(user_id), med_id_strs],
        misfire_grace_time=300,
    )
    logger.info(f"⏰ Scheduled Cloud Snooze for user {user_id} at {run_time}")


async def trigger_medication_alarm_by_ids(user_id_str: str, medication_id_strs: List[str]):
    """
    Identical to primary alarm trigger but filtered by medication IDs.
    Ensures maximum reliability for Cloud Snooze.
    """
    logger.info(f"🚀 [Cloud Snooze] Executing for user: {user_id_str} with medals: {medication_id_strs}")

    async with AsyncSessionLocal() as db:
        try:
            u_id = uuid.UUID(user_id_str)
            m_ids = [uuid.UUID(mid) for mid in medication_id_strs]
            
            result = await db.execute(
                select(Medication).where(Medication.id.in_(m_ids))
            )
            relevant_meds = result.scalars().all()

            if not relevant_meds:
                logger.warning(f"⚠️ [Cloud Snooze] No medications found for IDs: {medication_id_strs}")
                return

            drawers_to_activate = [
                m.drawer_number
                for m in relevant_meds
                if m.use_smart_box and m.drawer_number
            ]

            # payload building (Identical to trigger_medication_alarm)
            if len(relevant_meds) == 1:
                med = relevant_meds[0]
                body = med.name
                payload = {
                    "type": "single",
                    "medicine": {
                        "id": str(med.id),
                        "name": med.name,
                        "dosage": med.dosage,
                        "instructions": med.instructions or "",
                        "drawer_number": med.drawer_number,
                        "image_url": med.image_url or "",
                        "scheduled_times": med.scheduled_times or [],
                    },
                }
            else:
                body = ", ".join([m.name for m in relevant_meds])
                payload = {
                    "type": "grouped",
                    "medicines": [
                        {
                            "id": str(m.id),
                            "name": m.name,
                            "dosage": m.dosage,
                            "instructions": m.instructions or "",
                            "drawer_number": m.drawer_number,
                            "scheduled_times": m.scheduled_times or [],
                        }
                        for m in relevant_meds
                    ],
                }

            # Use identical logic for sending
            await notification_service.create_notification(
                db=db,
                user_id=str(u_id),
                notification_type=NotificationType.MEDICATION_REMINDER,
                title="medications.alarm_title",
                message=body,
                data=payload,
            )
            
            logger.info(f"✅ [Cloud Snooze] Successfully triggered reminder for user {user_id_str}")

            if drawers_to_activate:
                logger.info(f"💡 [Cloud Snooze] Activating drawers: {drawers_to_activate}")
                asyncio.create_task(esp32_service.activate(drawers_to_activate))

            await db.commit()

        except Exception as e:
            logger.error(f"❌ [Cloud Snooze] Critical error: {str(e)}", exc_info=True)


async def sync_user_medication_jobs(db, user_id: uuid.UUID):
    """Synchronises cron jobs for a user."""
    try:
        prefix = f"user_time_{user_id}"
        existing_jobs = scheduler.get_jobs()
        for job in existing_jobs:
            if job.id.startswith(prefix):
                try:
                    scheduler.remove_job(job.id)
                except Exception:
                    pass

        result = await db.execute(select(Medication).where(Medication.user_id == user_id))
        medications = result.scalars().all()

        unique_times = set()
        for med in medications:
            for t in (med.scheduled_times or []):
                unique_times.add(t)

        for time_str in unique_times:
            try:
                parts = time_str.split(":")
                hour, minute = int(parts[0]), int(parts[1])
                job_id = f"{prefix}_{time_str.replace(':', '')}"

                scheduler.add_job(
                    trigger_medication_alarm,
                    "cron",
                    hour=hour,
                    minute=minute,
                    id=job_id,
                    args=[user_id, time_str],
                    replace_existing=True,
                    misfire_grace_time=60,
                )
            except Exception as e:
                logger.error(f"❌ Failed to schedule {time_str}: {e}")
    except Exception as e:
        logger.error(f"❌ Error syncing jobs for user {user_id}: {e}", exc_info=True)


async def schedule_medication_jobs(medication: Medication, db=None):
    user_id = medication.user_id
    if db:
        await sync_user_medication_jobs(db, user_id)
    else:
        async with AsyncSessionLocal() as session:
            await sync_user_medication_jobs(session, user_id)


async def delete_medication_jobs(medication_id: uuid.UUID, user_id: uuid.UUID, db=None):
    if db:
        await sync_user_medication_jobs(db, user_id)
    else:
        async with AsyncSessionLocal() as session:
            await sync_user_medication_jobs(session, user_id)
