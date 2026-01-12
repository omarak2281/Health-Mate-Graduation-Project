"""
IoT Mock Service for development
Simulates sensors and medicine box when real hardware not available
Environment-based switching via IOT_MODE setting
"""

import random
import numpy as np
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from app.core.config import settings
from app.models.iot_device import DeviceStatus


class IoTMockService:
    """
    Mock IoT service for development
    
    Simulates:
    - PPG/ECG sensors with realistic signal patterns
    - Signal quality degradation
    - Connection status changes
    - Medicine box drawers with LED/buzzer
    """
    
    def __init__(self):
        """Initialize mock service"""
        self.sensor_status = {
            "ppg": DeviceStatus.CONNECTED,
            "ecg": DeviceStatus.CONNECTED
        }
        self.signal_quality = {
            "ppg": 0.95,
            "ecg": 0.92
        }
        self.drawer_states = {i: {"led_on": False, "buzzer_on": False} for i in range(1, 9)}
    
    def get_sensor_status(self, sensor_type: str) -> Dict:
        """
        Get sensor connection status
        
        Randomly simulates disconnections for testing
        """
        # Randomly degrade connection (10% chance)
        if random.random() < 0.1:
            self.sensor_status[sensor_type] = random.choice([
                DeviceStatus.DISCONNECTED,
                DeviceStatus.UNSTABLE
            ])
            self.signal_quality[sensor_type] = random.uniform(0.3, 0.7)
        else:
            self.sensor_status[sensor_type] = DeviceStatus.CONNECTED
            self.signal_quality[sensor_type] = random.uniform(0.85, 1.0)
        
        return {
            "sensor_type": sensor_type,
            "status": self.sensor_status[sensor_type].value,
            "signal_quality": self.signal_quality[sensor_type],
            "last_ping": datetime.utcnow().isoformat()
        }
    
    def get_all_sensors_status(self) -> List[Dict]:
        """Get status of all sensors"""
        return [
            self.get_sensor_status("ppg"),
            self.get_sensor_status("ecg")
        ]
    
    def generate_ppg_signal(self, duration_seconds: int = 10, sample_rate: int = 100) -> List[float]:
        """
        Generate mock PPG signal with realistic pattern
        
        Args:
            duration_seconds: Signal duration
            sample_rate: Samples per second
        
        Returns:
            List of PPG values
        """
        num_samples = duration_seconds * sample_rate
        signal = []
        
        # Simulate heartbeat pattern
        heart_rate = random.randint(60, 100)  # BPM
        period = 60.0 / heart_rate
        
        for i in range(num_samples):
            t = i / sample_rate
            # Simple sine wave approximation of PPG
            value = 0.5 + 0.5 * np.sin(2 * np.pi * t / period)
            # Add noise
            value += random.gauss(0, 0.05)
            signal.append(max(0, min(1, value)))
        
        return signal
    
    def generate_ecg_signal(self, duration_seconds: int = 10, sample_rate: int = 250) -> List[float]:
        """
        Generate mock ECG signal with realistic pattern
        
        Args:
            duration_seconds: Signal duration
            sample_rate: Samples per second
        
        Returns:
            List of ECG values
        """
        num_samples = duration_seconds * sample_rate
        signal = []
        
        # Simulate ECG pattern (simplified)
        heart_rate = random.randint(60, 100)  # BPM
        period = 60.0 / heart_rate
        
        for i in range(num_samples):
            t = i / sample_rate
            # Simplified QRS complex approximation
            phase = (t % period) / period
            
            if 0.1 < phase < 0.15:  # QRS peak
                value = 1.0
            elif 0.15 < phase < 0.3:  # T wave
                value = 0.3
            else:
                value = 0.0
            
            # Add noise
            value += random.gauss(0, 0.02)
            signal.append(value)
        
        return signal
    
    def get_sensor_data(self) -> Dict:
        """
        Get current sensor readings
        
        Returns raw signals if sensors connected
        Otherwise returns None
        """
        ppg_status = self.get_sensor_status("ppg")
        ecg_status = self.get_sensor_status("ecg")
        
        if ppg_status["status"] == DeviceStatus.DISCONNECTED.value or \
           ecg_status["status"] == DeviceStatus.DISCONNECTED.value:
            return {
                "status": "sensors_offline",
                "message": "Cannot get readings - sensors disconnected",
                "use_cached": True
            }
        
        # Generate mock signals
        ppg_signal = self.generate_ppg_signal(duration_seconds=5)
        ecg_signal = self.generate_ecg_signal(duration_seconds=5)
        
        return {
            "status": "success",
            "ppg": {
                "signal": ppg_signal[:50],  # Return subset for API
                "quality": ppg_status["signal_quality"]
            },
            "ecg": {
                "signal": ecg_signal[:50],  # Return subset for API
                "quality": ecg_status["signal_quality"]
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def activate_drawer(self, drawer_number: int) -> Dict:
        """
        Activate medicine box drawer (LED + buzzer)
        
        Args:
            drawer_number: Drawer number (1-8)
        
        Returns:
            Status dict
        """
        if drawer_number not in self.drawer_states:
            return {"error": "Invalid drawer number"}
        
        self.drawer_states[drawer_number]["led_on"] = True
        self.drawer_states[drawer_number]["buzzer_on"] = True
        
        return {
            "drawer": drawer_number,
            "led_on": True,
            "buzzer_on": True,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def deactivate_drawer(self, drawer_number: int) -> Dict:
        """
        Deactivate medicine box drawer
        
        Args:
            drawer_number: Drawer number (1-8)
        
        Returns:
            Status dict
        """
        if drawer_number not in self.drawer_states:
            return {"error": "Invalid drawer number"}
        
        self.drawer_states[drawer_number]["led_on"] = False
        self.drawer_states[drawer_number]["buzzer_on"] = False
        
        return {
            "drawer": drawer_number,
            "led_on": False,
            "buzzer_on": False,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def get_drawer_status(self, drawer_number: int) -> Dict:
        """Get status of specific drawer"""
        if drawer_number not in self.drawer_states:
            return {"error": "Invalid drawer number"}
        
        return {
            "drawer": drawer_number,
            **self.drawer_states[drawer_number]
        }
    
    def get_all_drawers_status(self) -> List[Dict]:
        """Get status of all drawers"""
        return [
            {"drawer": num, **state}
            for num, state in self.drawer_states.items()
        ]


# Singleton instance
iot_mock = IoTMockService()


def get_iot_service() -> IoTMockService:
    """
    Get IoT service instance
    
    Returns mock service if IOT_MODE=mock
    Returns real service if IOT_MODE=production (TODO: implement real service)
    """
    if settings.iot_mode == "mock":
        return iot_mock
    else:
        # TODO: Return real IoT service instance
        raise NotImplementedError("Production IoT service not yet implemented")
