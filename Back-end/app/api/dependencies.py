"""
Authentication dependencies for protected routes
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
from uuid import UUID

from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import User, UserRole

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Get current user from JWT token
    
    Raises 401 if token invalid or user not found
    """
    token = credentials.credentials
    payload = decode_token(token)
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    
    # Get user from database
    result = await db.execute(select(User).where(User.id == UUID(user_id)))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    
    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Get current active user
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    return current_user


def require_role(required_role: UserRole):
    """
    Dependency factory to require specific user role
    """
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role: {required_role.value}"
            )
        return current_user
    
    return role_checker


# Convenience dependencies
require_patient = require_role(UserRole.PATIENT)
require_caregiver = require_role(UserRole.CAREGIVER)


from fastapi import Header
import bcrypt
from app.models.registered_device import RegisteredDevice

async def get_device_from_headers(
    x_device_id: str = Header(..., alias="X-Device-ID"),
    x_device_token: str = Header(..., alias="X-Device-Token"),
    db: AsyncSession = Depends(get_db)
) -> RegisteredDevice:
    """Imported from device auth dependency block. Authenticates IoT hardware devices"""
    stmt = select(RegisteredDevice).where(
        RegisteredDevice.device_id == x_device_id,
        RegisteredDevice.is_active == True
    )
    res = await db.execute(stmt)
    device = res.scalar_one_or_none()
    
    if not device:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Registered IoT Device not found or is inactive"
        )
        
    # Verify token
    try:
        # bcrypt requires bytes
        hashed = device.token_hash.encode('utf-8')
        raw = x_device_token.encode('utf-8')
        if not bcrypt.checkpw(raw, hashed):
            raise ValueError()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid IoT Device credentials"
        )
        
    return device

