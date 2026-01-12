"""
Authentication router
Handles login, registration, token refresh
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import timedelta, datetime
from typing import Dict, Any, List

from app.core.database import get_db
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token
)
from app.core.config import settings
from app.models.user import User
from app.schemas.user import UserRegister, UserLogin, Token, UserResponse, SocialAuthRequest
from app.models.audit_log import AuditLog

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserRegister,
    db: AsyncSession = Depends(get_db)
):
    """
    Register new user (Patient or Caregiver)
    
    - **email**: Valid email address
    - **password**: Min 8 chars, must include digit and uppercase
    - **full_name**: User's full name
    - **phone**: Optional phone number
    - **role**: patient or caregiver (CRITICAL - determines UI)
    """
    # Check if email already exists
    result = await db.execute(select(User).where(User.email == user_data.email))
    existing_user = result.scalar_one_or_none()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user
    db_user = User(
        email=user_data.email,
        hashed_password=get_password_hash(user_data.password),
        full_name=user_data.full_name,
        phone=user_data.phone,
        role=user_data.role,
        firebase_uid=user_data.firebase_uid
    )
    
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    
    # Log registration
    audit_log = AuditLog(
        user_id=db_user.id,
        event_type="user_registered",
        event_description=f"User registered with role: {user_data.role}",
        event_data={"email": user_data.email, "role": user_data.role.value}
    )
    db.add(audit_log)
    await db.commit()
    
    return db_user


@router.post("/login", response_model=Token)
async def login(
    credentials: UserLogin,
    db: AsyncSession = Depends(get_db)
):
    """
    Login with email and password
    
    Returns JWT access token and refresh token
    """
    # Find user by email
    result = await db.execute(select(User).where(User.email == credentials.email))
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive"
        )
    
    # Create tokens
    token_data = {
        "sub": str(user.id),
        "email": user.email,
        "role": user.role.value
    }
    
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)
    
    # Update last login
    user.last_login_at = datetime.utcnow()
    await db.commit()
    
    # Log login
    audit_log = AuditLog(
        user_id=user.id,
        event_type="user_login",
        event_description=f"User logged in",
        event_data={"email": user.email}
    )
    db.add(audit_log)
    await db.commit()
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token
    )


@router.post("/refresh", response_model=Token)
async def refresh_token(
    refresh_token: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Refresh access token using refresh token
    """
    payload = decode_token(refresh_token)
    
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    user_id = payload.get("sub")
    
    # Verify user still exists and is active
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )
    
    # Create new tokens
    token_data = {
        "sub": str(user.id),
        "email": user.email,
        "role": user.role.value
    }
    
    new_access_token = create_access_token(data=token_data)
    new_refresh_token = create_refresh_token(data=token_data)
    
    return Token(
        access_token=new_access_token,
        refresh_token=new_refresh_token
    )


@router.post("/social", response_model=Token)
async def social_auth(
    auth_data: SocialAuthRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Social authentication (Google Sign-In) via Firebase
    
    - **firebase_id_token**: Firebase ID token from Google Sign-In
    - **role**: User role (patient/caregiver) - required for new users
    
    Flow:
    1. Verify Firebase ID token
    2. Extract user data (UID, email, name, photo)
    3. Check if user exists by firebase_uid
    4. If exists: login and return JWT tokens
    5. If new: create user and return JWT tokens
    """
    from app.core.firebase_admin import verify_firebase_token, extract_user_info_from_token
    
    try:
        # Verify Firebase token
        decoded_token = await verify_firebase_token(auth_data.firebase_id_token)
        if not decoded_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Firebase token"
            )
        
        # Extract user info
        user_info = extract_user_info_from_token(decoded_token)
        firebase_uid = user_info['firebase_uid']
        email = user_info['email']
        email_verified = user_info['email_verified']
        
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email not provided by authentication provider"
            )
        
        # Check if user exists by firebase_uid
        result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
        user = result.scalar_one_or_none()
        
        if not user:
            # Check if email already exists (linked to different account)
            result = await db.execute(select(User).where(User.email == email))
            existing_user = result.scalar_one_or_none()
            
            if existing_user:
                if existing_user.firebase_uid is None:
                    # Account exists but not linked to Firebase - Link it now
                    existing_user.firebase_uid = firebase_uid
                    if email_verified:
                        existing_user.is_verified = True
                        existing_user.email_verified_at = datetime.utcnow()
                    
                    db.add(existing_user)
                    await db.commit()
                    await db.refresh(existing_user)
                    user = existing_user
                else:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="An account with this email already exists. Please login with Email/Password."
                    )
            
            if not user:
                # Create new user
                user = User(
                email=email,
                hashed_password="",  # No password for social auth
                full_name=user_info.get('display_name') or email.split('@')[0],
                role=auth_data.role,
                firebase_uid=firebase_uid,
                auth_provider=user_info['auth_provider'],
                is_verified=True,  # Social auth users are auto-verified
                email_verified_at=datetime.utcnow() if email_verified else None,
                profile_image_url=user_info.get('photo_url')
            )
            
            db.add(user)
            await db.commit()
            await db.refresh(user)
            
            # Log registration
            audit_log = AuditLog(
                user_id=user.id,
                event_type="user_registered",
                event_description=f"User registered via {user_info['auth_provider']}",
                event_data={"email": email, "auth_provider": user_info['auth_provider']}
            )
            db.add(audit_log)
            await db.commit()
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is inactive"
            )
        
        # Create tokens
        token_data = {
            "sub": str(user.id),
            "email": user.email,
            "role": user.role.value
        }
        
        access_token = create_access_token(data=token_data)
        refresh_token = create_refresh_token(data=token_data)
        
        # Update last login
        user.last_login_at = datetime.utcnow()
        await db.commit()
        
        # Log login
        audit_log = AuditLog(
            user_id=user.id,
            event_type="user_login",
            event_description=f"User logged in via {user_info['auth_provider']}",
            event_data={"email": email, "auth_provider": user_info['auth_provider']}
        )
        db.add(audit_log)
        await db.commit()
        
        return Token(
            access_token=access_token,
            refresh_token=refresh_token
        )
        
    except ValueError as e:
        # Firebase token verification errors
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication failed: {str(e)}"
        )


@router.post("/verify-email")
async def verify_email(
    firebase_uid: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Update email verification status
    
    Called after user verifies email through Firebase
    """
    from app.core.firebase_admin import check_email_verified
    
    try:
        # Check Firebase if email is verified
        is_verified = await check_email_verified(firebase_uid)
        
        if not is_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email not yet verified in Firebase"
            )
        
        # Update user record
        result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        user.email_verified_at = datetime.utcnow()
        user.is_verified = True
        await db.commit()
        
        return {"message": "Email verified successfully"}
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Verification failed: {str(e)}"
        )


@router.post("/logout")
async def logout(
    db: AsyncSession = Depends(get_db)
):
    """
    Logout user
    
    In production, should blacklist token in Redis
    For now, client should delete token
    """
    return {"message": "Successfully logged out"}
