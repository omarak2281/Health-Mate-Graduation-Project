"""
ESP32 Service for hardware communication
Handles HTTP communication with the ESP32 microcontroller
"""

import httpx
import logging
from typing import Dict, List, Optional
from app.core.config import settings

logger = logging.getLogger(__name__)

class ESP32Service:
    """
    Service for interacting with the physical Medication Box (ESP32)
    Uses httpx for asynchronous HTTP requests.
    """
    
    def __init__(self):
        self.base_url = f"http://{settings.esp32_local_ip}"
        self.timeout = 5.0 # Seconds
        
    async def _post(self, endpoint: str, data: Dict) -> Dict:
        """Helper to send POST requests to ESP32"""
        url = f"{self.base_url}{endpoint}"
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(url, json=data)
                response.raise_for_status()
                return {
                    "status": "success",
                    "data": response.json() if response.content else {"message": "Command received"}
                }
        except httpx.ConnectError:
            logger.warning(f"Failed to connect to ESP32 at {url}")
            return {"status": "error", "message": "Hardware unreachable"}
        except Exception as e:
            logger.warning(f"Error communicating with ESP32 at {url}: {type(e).__name__} - {str(e)}")
            return {"status": "error", "message": str(e)}

    async def activate(self, drawer_numbers: List[int]) -> None:
        """
        Activate specific drawers (LED + Buzzer)
        POST http://{ESP32_IP}/activate  body: { "drawers": drawer_numbers }
        """
        if not drawer_numbers:
            return
            
        valid_drawers = [d for d in drawer_numbers if 1 <= d <= settings.max_drawers]
        if not valid_drawers:
            return

        payload = {"drawers": valid_drawers}
        # on error: log warning only — do NOT raise, do NOT crash the alarm job
        await self._post(settings.esp32_activate_endpoint, payload)

    async def deactivate_all(self) -> None:
        """POST /activate with { "drawers": [] }"""
        payload = {"drawers": []}
        await self._post(settings.esp32_activate_endpoint, payload)

    async def ping(self) -> bool:
        """GET http://{ESP32_IP}/  with short timeout → return True/False, never raise"""
        url = self.base_url
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                response = await client.get(url)
                # Any response (even 404) means the device is reachable and web server is running
                return response.status_code < 500
        except Exception:
            return False

# Global instance
esp32_service = ESP32Service()

# For backward compatibility or if other files use 'iot_service'
iot_service = esp32_service
