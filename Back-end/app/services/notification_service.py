"""
Notification service for push notifications and in-app alerts
Handles emergency BP alerts, medication reminders, and call notifications
"""

from typing import List, Dict, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from app.models.notification import Notification, NotificationType
from app.models.user import User
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.core.firebase_admin import send_push_notification


class NotificationService:
    """
    Notification service for creating and sending alerts
    
    Handles:
    - Emergency BP alerts to caregivers
    - Medication reminders
    - Sensor disconnection warnings
    - Incoming call notifications
    """
    
    async def create_notification(
        self,
        db: AsyncSession,
        user_id: str,
        notification_type: NotificationType,
        title: str,
        message: str,
        data: Optional[Dict] = None
    ) -> Notification:
        """
        Create notification in database
        
        Args:
            db: Database session
            user_id: Target user ID
            notification_type: Type of notification
            title: Notification title
            message: Notification message
            data: Additional data (JSON)
        
        Returns:
            Created notification
        """
        notification = Notification(
            user_id=user_id,
            notification_type=notification_type,
            title=title,
            message=message,
            data=data
        )
        
        db.add(notification)
        await db.commit()
        await db.refresh(notification)
        
        # Send actual push notification via FCM
        await self._send_push_notification(db, notification)
        
        return notification
    
    async def send_emergency_bp_alert(
        self,
        db: AsyncSession,
        patient_id: str,
        systolic: int,
        diastolic: int,
        risk_level: str
    ):
        """
        Send emergency BP alert to all linked caregivers
        
        Args:
            db: Database session
            patient_id: Patient user ID
            systolic: Systolic BP
            diastolic: Diastolic BP
            risk_level: Risk level (normal/low/moderate/high/critical)
        """
        import uuid
        from datetime import datetime, timedelta
        from sqlalchemy.dialects.postgresql import insert
        from app.models.vital_sign import BPAlertCooldown

        # Cooldown check
        risk_lower = risk_level.lower()
        if risk_lower in ("low", "high", "critical"):
            cooldown_minutes = 15 if risk_lower == "critical" else 30
            patient_uuid = uuid.UUID(str(patient_id)) if not isinstance(patient_id, uuid.UUID) else patient_id

            # Check existing cooldown
            stmt = select(BPAlertCooldown).where(
                BPAlertCooldown.patient_id == patient_uuid,
                BPAlertCooldown.risk_level == risk_lower
            )
            cooldown_result = await db.execute(stmt)
            cooldown_entry = cooldown_result.scalar_one_or_none()

            now = datetime.utcnow()
            if cooldown_entry:
                time_elapsed = now - cooldown_entry.last_sent_at
                if time_elapsed < timedelta(minutes=cooldown_minutes):
                    print(f"⌛ Cooldown active for patient {patient_id} and risk level {risk_level}. Skipping alert.")
                    return

            # Upsert cooldown
            insert_stmt = insert(BPAlertCooldown).values(
                patient_id=patient_uuid,
                risk_level=risk_lower,
                last_sent_at=now
            )
            upsert_stmt = insert_stmt.on_conflict_do_update(
                index_elements=['patient_id', 'risk_level'],
                set_=dict(last_sent_at=now)
            )
            await db.execute(upsert_stmt)
            await db.commit()

        # Get patient info
        patient_result = await db.execute(select(User).where(User.id == patient_id))
        patient = patient_result.scalar_one_or_none()
        
        if not patient:
            return
        
        # Get all active caregivers
        caregivers_result = await db.execute(
            select(User)
            .join(PatientCaregiverLink, PatientCaregiverLink.caregiver_id == User.id)
            .where(PatientCaregiverLink.patient_id == patient_id)
            .where(PatientCaregiverLink.is_active == True)
        )
        
        caregivers = caregivers_result.scalars().all()
        
        # Create notification for each caregiver
        for caregiver in caregivers:
            await self.create_notification(
                db=db,
                user_id=str(caregiver.id),
                notification_type=NotificationType.EMERGENCY_BP_ALERT,
                title=f"⚠️ Emergency BP Alert: {patient.full_name}",
                message=f"Blood pressure: {systolic}/{diastolic} mmHg - Risk: {risk_level.upper()}",
                data={
                    "patient_id": str(patient_id),
                    "patient_name": patient.full_name,
                    "phone": patient.phone or "",
                    "systolic": systolic,
                    "diastolic": diastolic,
                    "risk_level": risk_level,
                    "actions": ["call_patient", "video_call_patient", "view_details"]
                }
            )

    async def send_symptom_assessment_alert(
        self,
        db: AsyncSession,
        patient_id: str,
        urgency: str,
        caregiver_summary: str,
        recommended_action: str,
        red_flags: list[str],
        assessment_id: str | None = None,
        manual: bool = False,
        lang: str = "en",
    ) -> int:
        """
        Send symptom assessment alert to all active linked caregivers.

        Used by the guided symptom checker when an assessment is high risk or
        when the patient explicitly chooses to notify their caregiver.
        """
        patient_result = await db.execute(select(User).where(User.id == patient_id))
        patient = patient_result.scalar_one_or_none()

        if not patient:
            return 0

        caregivers_result = await db.execute(
            select(User)
            .join(PatientCaregiverLink, PatientCaregiverLink.caregiver_id == User.id)
            .where(PatientCaregiverLink.patient_id == patient_id)
            .where(PatientCaregiverLink.is_active == True)
        )
        caregivers = caregivers_result.scalars().all()

        # Title was always hardcoded in English regardless of the patient's
        # app language ("Symptom Alert: ..."), which reads wrong in an
        # otherwise fully-Arabic app.
        title = (
            f"تنبيه أعراض: {patient.full_name}"
            if lang == "ar"
            else f"Symptom Alert: {patient.full_name}"
        )
        message = f"{urgency.upper()} urgency - {recommended_action}"
        if caregiver_summary:
            message = caregiver_summary

        notified_count = 0
        for caregiver in caregivers:
            await self.create_notification(
                db=db,
                user_id=str(caregiver.id),
                notification_type=NotificationType.SYMPTOM_ASSESSMENT_ALERT,
                title=title,
                message=message,
                data={
                    "patient_id": str(patient_id),
                    "patient_name": patient.full_name,
                    "assessment_id": assessment_id or "",
                    "urgency": urgency,
                    "recommended_action": recommended_action,
                    "red_flags": red_flags,
                    "manual": manual,
                    "actions": ["call_patient", "video_call_patient", "view_details"],
                },
            )
            notified_count += 1

        return notified_count
    
    async def send_medication_reminder(
        self,
        db: AsyncSession,
        patient_id: str,
        medication_name: str,
        dosage: str
    ):
        """
        Send medication reminder to patient
        
        Args:
            db: Database session
            patient_id: Patient user ID
            medication_name: Name of medication
            dosage: Dosage information
        """
        await self.create_notification(
            db=db,
            user_id=patient_id,
            notification_type=NotificationType.MEDICATION_REMINDER,
            title=f"💊 Time for your medication",
            message=f"{medication_name} - {dosage}",
            data={
                "medication_name": medication_name,
                "dosage": dosage
            }
        )
    
    async def send_sensor_disconnection_alert(
        self,
        db: AsyncSession,
        patient_id: str,
        sensor_type: str
    ):
        """
        Send sensor disconnection alert
        
        Args:
            db: Database session
            patient_id: Patient user ID
            sensor_type: Type of sensor (ppg/ecg)
        """
        await self.create_notification(
            db=db,
            user_id=patient_id,
            notification_type=NotificationType.SENSOR_DISCONNECTION,
            title="⚡ Sensor Disconnected",
            message=f"{sensor_type.upper()} sensor is disconnected. Please check your device.",
            data={
                "sensor_type": sensor_type
            }
        )
    
    async def send_incoming_call_notification(
        self,
        db: AsyncSession,
        callee_id: str,
        caller_name: str,
        call_type: str,
        session_id: str,
        caller_id: str | None = None,
        caller_phone: str | None = None,
        caller_avatar: str | None = None,
    ):
        """
        Send incoming call notification

        Args:
            db: Database session
            callee_id: User receiving the call
            caller_name: Name of caller
            call_type: audio or video
            session_id: Call session ID
        """
        await self.create_notification(
            db=db,
            user_id=callee_id,
            notification_type=NotificationType.INCOMING_CALL,
            title=f"📞 Incoming {call_type.capitalize()} Call",
            message=f"{caller_name} is calling you",
            data={
                "caller_name": caller_name,
                "caller_id": caller_id or "",
                "caller_avatar": caller_avatar or "",
                "phone": caller_phone or "",
                "call_type": call_type,
                "session_id": session_id,
                "actions": ["answer", "decline"]
            }
        )
    
    async def _send_push_notification(self, db: AsyncSession, notification: Notification):
        """
        Fetch user fcm_token and send push notification via FCM Admin SDK.
        
        IMPORTANT: Firebase FCM requires ALL data payload values to be plain strings.
        Nested dicts/lists must be JSON-serialized before being added to the payload.
        """
        import json
        try:
            user_id = notification.user_id
            user_result = await db.execute(select(User).where(User.id == user_id))
            user = user_result.scalar_one_or_none()

            if not user or not user.fcm_token:
                print(f"⚠️ Cannot send push: User {user_id} has no fcm_token")
                return

            # Combine notification data with standard routing fields
            raw_data = dict(notification.data or {})
            raw_data.update({
                "notification_id": str(notification.id),
                "notification_type": notification.notification_type.value,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
            })

            # Firebase requires all data values to be STRINGS.
            # Nested dicts/lists must be JSON-serialized so Flutter can jsonDecode() them.
            string_payload: dict[str, str] = {}
            for key, value in raw_data.items():
                if isinstance(value, (dict, list)):
                    string_payload[key] = json.dumps(value, ensure_ascii=False)
                elif value is None:
                    string_payload[key] = ""
                else:
                    string_payload[key] = str(value)

            message_id, token_invalid = await send_push_notification(
                token=user.fcm_token,
                title=notification.title,
                body=notification.message,
                data=string_payload,
            )

            # Only clear the stored token when FCM confirms *this device
            # token* is dead. Credential/network/quota failures are
            # transient and must not wipe a perfectly valid token -- doing
            # so previously locked users out of all push notifications
            # (including medication alarms) until their next login.
            if token_invalid:
                print(f"🧹 Clearing invalid FCM token for user {user_id}")
                user.fcm_token = None
                db.add(user)
                await db.commit()
            elif not message_id:
                print(f"⚠️ Transient FCM failure for user {user_id}; keeping token for retry")
            
        except Exception as e:
            print(f"❌ Error in _send_push_notification: {str(e)}")
            # If we were in the middle of a transaction that failed, rollback
            try:
                await db.rollback()
            except:
                pass


# Singleton instance
notification_service = NotificationService()


def get_notification_service() -> NotificationService:
    """Get notification service instance"""
    return notification_service
