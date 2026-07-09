"""
IoT router for sensor and medicine box endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, List, Optional
from uuid import UUID
from datetime import datetime
from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.registered_device import RegisteredDevice
from app.models.patient_caregiver_link import PatientCaregiverLink
from app.services.iot_service import esp32_service
from app.services.iot_mock import get_iot_service # Still used for sensors
from sqlalchemy import select


router = APIRouter(prefix="/iot", tags=["IoT Devices"])


@router.get("/sensors/status")
async def get_sensors_status(
    patient_id: Optional[UUID] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get status of all sensors (PPG, ECG)
    Supports patient_id check for caregivers
    """
    from app.core.config import settings
    
    # Determine which patient is checked
    target_patient_id = current_user.id
    if patient_id is not None:
        # Check if current user is caregiver linked to patient_id
        if current_user.id != patient_id:
            link_result = await db.execute(
                select(PatientCaregiverLink)
                .where(
                    PatientCaregiverLink.caregiver_id == current_user.id,
                    PatientCaregiverLink.patient_id == patient_id,
                    PatientCaregiverLink.is_active == True
                )
            )
            if not link_result.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied. Patient is not linked to you."
                )
        target_patient_id = patient_id
        
    # Query active registered device for target patient
    device_result = await db.execute(
        select(RegisteredDevice)
        .where(
            RegisteredDevice.patient_id == target_patient_id,
            RegisteredDevice.is_active == True
        )
    )
    device = device_result.scalar_one_or_none()
    
    if device:
        # Verify freshness of heartbeat
        is_online = False
        if device.last_seen_at:
            delta = datetime.utcnow() - device.last_seen_at
            if delta.total_seconds() < 25: # Online window: 25 seconds
                is_online = True
                
        ppg_status = "connected" if (is_online and device.last_finger_detected) else "disconnected"
        ecg_status = "connected" if (is_online and device.last_leads_connected) else "disconnected"
        
        return [
            {
                "sensor_type": "ppg",
                "status": ppg_status,
                "signal_quality": 1.0 if ppg_status == "connected" else 0.0,
                "last_ping": device.last_seen_at.isoformat() if device.last_seen_at else None
            },
            {
                "sensor_type": "ecg",
                "status": ecg_status,
                "signal_quality": 1.0 if ecg_status == "connected" else 0.0,
                "last_ping": device.last_seen_at.isoformat() if device.last_seen_at else None
            }
        ]
        
    # If device not registered and mode is mock, use mock service
    if settings.iot_mode == "mock":
        iot_service = get_iot_service()
        return iot_service.get_all_sensors_status()
        
    # Default disconnected response
    return [
        {
            "sensor_type": "ppg",
            "status": "disconnected",
            "signal_quality": 0.0,
            "last_ping": None
        },
        {
            "sensor_type": "ecg",
            "status": "disconnected",
            "signal_quality": 0.0,
            "last_ping": None
        }
    ]



@router.get("/sensors/data")
async def get_sensor_data():
    """
    Get current sensor readings
    """
    iot_service = get_iot_service()
    return iot_service.get_sensor_data()


@router.get("/medicine-box/status")
async def get_box_status():
    """
    Get overall status of medicine box (battery, connection)
    """
    is_online = await esp32_service.ping()
    return {"status": "online" if is_online else "offline"}


@router.get("/medicine-box/drawers")
async def get_drawers(
    db: AsyncSession = Depends(get_db)
):
    """
    Get status of all 6 drawers in the medicine box.
    Identifies which drawers are currently occupied by medications.
    """
    from app.models.medication import Medication
    from sqlalchemy import select
    
    # Query all active medications that have a drawer assigned
    result = await db.execute(
        select(Medication.drawer_number)
        .where(Medication.is_active == True)
        .where(Medication.drawer_number != None)
    )
    occupied_drawers = {row[0] for row in result.all()}
    
    drawers = []
    for i in range(1, 7): # 6 drawers
        drawers.append({
            "drawer_number": i,
            "is_active": i in occupied_drawers,
            "medication_name": "Assigned" if i in occupied_drawers else None
        })
        
    return drawers


@router.post("/medicine-box/deactivate-all")
async def deactivate_all_drawers():
    """
    Deactivate all drawers
    """
    await esp32_service.deactivate_all()
    return {"status": "success"}
