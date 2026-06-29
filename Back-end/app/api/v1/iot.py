"""
IoT router for sensor and medicine box endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, List
from app.core.database import get_db
from app.services.iot_service import esp32_service
from app.services.iot_mock import get_iot_service # Still used for sensors

router = APIRouter(prefix="/iot", tags=["IoT Devices"])


@router.get("/sensors/status")
async def get_sensors_status():
    """
    Get status of all sensors (PPG, ECG)
    """
    iot_service = get_iot_service()
    return iot_service.get_all_sensors_status()


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
