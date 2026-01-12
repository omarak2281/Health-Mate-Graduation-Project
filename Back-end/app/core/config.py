"""
Application configuration using Pydantic Settings
No hardcoded values - all configuration from environment variables
"""

from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )
    
    # Application
    app_name: str = "Health Mate API"
    version: str = "1.0.0"
    environment: str = "development"
    debug: bool = True
    
    # Database
    database_url: str
    postgres_user: str = "healthmate"
    postgres_password: str = "healthmate123"
    postgres_db: str = "healthmate_db"
    
    # Redis
    redis_url: str = "redis://localhost:6379/0"
    
    # JWT
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    
    # IoT
    iot_mode: str = "mock"  # mock or production
    mqtt_broker_url: str = "mqtt://localhost:1883"
    mqtt_username: str = ""
    mqtt_password: str = ""
    
    # AI Models
    symptom_checker_model_path: str = "../Symptom-Checker/Output/Production/"
    bp_model_path: str = "../Predict-ABP/models/"
    
    # Cloudinary
    cloudinary_cloud_name: str = ""
    cloudinary_api_key: str = ""
    cloudinary_api_secret: str = ""
    
    # Firebase
    firebase_project_id: str = ""
    firebase_private_key: str = ""
    
    # WebRTC
    stun_server_1: str = "stun:stun.l.google.com:19302"
    stun_server_2: str = "stun:stun1.l.google.com:19302"
    turn_server_url: str = ""
    turn_username: str = ""
    turn_password: str = ""
    
    # CORS
    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    
    @property
    def cors_origins_list(self) -> List[str]:
        """Parse CORS origins string into list"""
        return [origin.strip() for origin in self.cors_origins.split(",")]
    
    @property
    def stun_servers(self) -> List[str]:
        """Get list of STUN servers"""
        servers = []
        if self.stun_server_1:
            servers.append(self.stun_server_1)
        if self.stun_server_2:
            servers.append(self.stun_server_2)
        return servers


# Global settings instance
settings = Settings()
