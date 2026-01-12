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
        
        # TODO: Send push notification via FCM
        await self._send_push_notification(notification)
        
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
                    "systolic": systolic,
                    "diastolic": diastolic,
                    "risk_level": risk_level,
                    "actions": ["call_patient", "video_call_patient", "view_details"]
                }
            )
    
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
        session_id: str
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
                "call_type": call_type,
                "session_id": session_id,
                "actions": ["answer", "decline"]
            }
        )
    
    async def _send_push_notification(self, notification: Notification):
        """
        Send push notification via FCM
        
        TODO: Implement FCM integration
        For now, just logs
        """
        print(f"📱 Push notification sent: {notification.title} to user {notification.user_id}")
        # TODO: Use Firebase Admin SDK to send FCM notification


# Singleton instance
notification_service = NotificationService()


def get_notification_service() -> NotificationService:
    """Get notification service instance"""
    return notification_service
