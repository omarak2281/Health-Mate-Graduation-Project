"""
IoT router for sensor and medicine box endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import Dict, List
from app.services.iot_mock import get_iot_service

router = APIRouter(prefix="/iot", tags=["IoT Devices"])


@router.get("/sensors/status")
async def get_sensors_status():
    """
    Get status of all sensors (PPG, ECG)
    
    Returns connection status and signal quality
    """
    iot_service = get_iot_service()
    return iot_service.get_all_sensors_status()


@router.get("/sensors/data")
async def get_sensor_data():
    """
    Get current sensor readings
    
    Returns raw PPG and ECG signals if sensors connected
    Otherwise returns error with use_cached flag
    """
    iot_service = get_iot_service()
    return iot_service.get_sensor_data()


@router.get("/medicine-box/drawers")
async def get_all_drawers():
    """
    Get status of all medicine box drawers
    
    Returns LED and buzzer states for each drawer
    """
    iot_service = get_iot_service()
    return iot_service.get_all_drawers_status()


@router.get("/medicine-box/drawer/{drawer_number}")
async def get_drawer_status(drawer_number: int):
    """
    Get status of specific drawer
    """
    iot_service = get_iot_service()
    result = iot_service.get_drawer_status(drawer_number)
    
    if "error" in result:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result["error"]
        )
    
    return result


@router.post("/medicine-box/drawer/{drawer_number}/activate")
async def activate_drawer(drawer_number: int):
    """
    Activate drawer LED and buzzer for medication reminder
    """
    iot_service = get_iot_service()
    result = iot_service.activate_drawer(drawer_number)
    
    if "error" in result:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result["error"]
        )
    
    return result


@router.post("/medicine-box/drawer/{drawer_number}/deactivate")
async def deactivate_drawer(drawer_number: int):
    """
    Deactivate drawer LED and buzzer
    
    Called when patient confirms medication taken
    """
    iot_service = get_iot_service()
    result = iot_service.deactivate_drawer(drawer_number)
    
    if "error" in result:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result["error"]
        )
    
    return result
