from fastapi import APIRouter
from app.services.iot_service import esp32_service

router = APIRouter(prefix="/hardware", tags=["Hardware"])

@router.get("/status")
async def get_hardware_status():
    """
    Lightweight status check for the ESP32 hardware.
    Returns whether the backend can currently ping the device.
    """
    is_connected = await esp32_service.ping()
    return {
        "status": "success",
        "data": {
            "connected": is_connected
        },
        "message": "Hardware status retrieved" if is_connected else "Hardware unreachable"
    }
