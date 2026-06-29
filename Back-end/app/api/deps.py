from fastapi import Depends, HTTPException, status, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from typing import Optional, Dict, Any

from app.core.database import get_db
from app.core.firebase_admin import verify_firebase_token, extract_user_info_from_token
from app.models.user import User, UserRole

# HTTP Bearer security scheme
security = HTTPBearer()

async def get_firebase_user_from_token(
    cred: HTTPAuthorizationCredentials = Security(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Dependency to verify Firebase ID token and return/create local User.
    
    1. Verifies token with Firebase Admin SDK
    2. Checks if user exists in PostgreSQL by firebase_uid
    3. If user exists: returns user
    4. If user does not exist: creates new user (Patient role default)
    
    Raises 401 for invalid token, 403 for disabled user.
    """
    token = cred.credentials
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        # Verify Firebase Token
        decoded_token = await verify_firebase_token(token)
        if not decoded_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Firebase token",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        # Extract user info
        user_info = extract_user_info_from_token(decoded_token)
        firebase_uid = user_info['firebase_uid']
        email = user_info['email']
        
        # Check if user exists in DB
        result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
        user = result.scalar_one_or_none()
        
        if user:
            # User exists
            if not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="User account is disabled"
                )
            return user
            
        # User does not exist - Create new user
        # Note: We default to PATIENT role. Caregivers usually require explicit selection flow.
        # Since this dependency is generic, we assume safe defaults or basic access.
        
        # Check if email is already used by another account (not linked to this Firebase UID)
        if email:
            email_result = await db.execute(select(User).where(User.email == email))
            existing_email_user = email_result.scalar_one_or_none()
            if existing_email_user:
                 # Link attempt? Or conflict.
                 # For safety, we raise error or ideally link. 
                 # User instructions say: "If user does not exist -> create new user record"
                 # It doesn't specify linking. We'll raise error to avoid account takeover/confusion
                 # unless we implemented automatic linking logic.
                 raise HTTPException(
                     status_code=status.HTTP_400_BAD_REQUEST,
                     detail="Email already exists. Please login with existing credentials."
                 )
        
        new_user = User(
            email=email,
            hashed_password="", # No password for Firebase users
            full_name=user_info.get('display_name') or email.split('@')[0],
            role=UserRole.PATIENT, # Default role
            firebase_uid=firebase_uid,
            auth_provider=user_info.get('auth_provider', 'firebase'),
            is_verified=user_info.get('email_verified', False),
            email_verified_at=datetime.utcnow() if user_info.get('email_verified') else None,
            profile_image_url=user_info.get('photo_url')
        )
        
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        
        return new_user

    except ValueError as e:
        # Token verification failed
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        # Database or other error
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication failed: {str(e)}"
        )
