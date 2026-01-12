"""
User schemas for API requests and responses
NO HARDCODED VALUES - all validation rules parameterized
"""

from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional
from datetime import datetime
from uuid import UUID
from app.models.user import UserRole


# Registration Schema
class UserRegister(BaseModel):
    """User registration request"""
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)
    full_name: str = Field(..., min_length=2, max_length=255)
    phone: Optional[str] = Field(None, max_length=50)
    role: UserRole
    firebase_uid: Optional[str] = None
    
    @validator('password')
    def validate_password(cls, v):
        """Validate password strength"""
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        return v


# Login Schema
class UserLogin(BaseModel):
    """User login request"""
    email: EmailStr
    password: str


# Token Response
class Token(BaseModel):
    """JWT token response"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Token payload data"""
    user_id: Optional[UUID] = None
    role: Optional[UserRole] = None


# User Response
class UserResponse(BaseModel):
    """User data response"""
    id: UUID
    email: str
    full_name: str
    phone: Optional[str]
    role: UserRole
    profile_image_url: Optional[str]
    is_active: bool
    is_verified: bool
    firebase_uid: Optional[str]
    auth_provider: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


# User Update
class UserUpdate(BaseModel):
    """User profile update"""
    full_name: Optional[str] = Field(None, min_length=2, max_length=255)
    phone: Optional[str] = Field(None, max_length=50)
    profile_image_url: Optional[str] = Field(None, max_length=500)


# Password Change
class PasswordChange(BaseModel):
    """Password change request"""
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=100)
    
    @validator('new_password')
    def validate_new_password(cls, v):
        """Validate new password strength"""
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        return v


# Social Authentication (Firebase)
class SocialAuthRequest(BaseModel):
    """Social authentication request with Firebase ID token"""
    firebase_id_token: str = Field(..., min_length=1)
    role: UserRole  # Required for new users (patient or caregiver)
    
    class Config:
        json_schema_extra = {
            "example": {
                "firebase_id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
                "role": "patient"
            }
        }
