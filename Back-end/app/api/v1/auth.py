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
from app.models.user import User, UserRole
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
    from app.core.firebase_admin import delete_firebase_user
    import traceback

    # Check if email already exists
    result = await db.execute(select(User).where(User.email == user_data.email))
    existing_user = result.scalar_one_or_none()
    
    if existing_user:
        # If user exists in DB but we're trying to register, check if we need to clean up Firebase
        # (Though usually the frontend should check this first)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    try:
        # Create new user
        new_user = User(
            email=user_data.email,
            hashed_password=get_password_hash(user_data.password),
            full_name=user_data.full_name,
            phone=user_data.phone,
            role=user_data.role,
            firebase_uid=user_data.firebase_uid,
            profile_image_url=user_data.profile_image_url,
            auth_provider='email',
            is_verified=False
        )
        
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        
        # Handle auto-linking if provided (for caregivers)
        if user_data.role == UserRole.CAREGIVER and user_data.linked_patient_id:
            from app.models.patient_caregiver_link import PatientCaregiverLink
            
            # Verify patient exists
            patient_result = await db.execute(select(User).where(User.id == user_data.linked_patient_id))
            patient = patient_result.scalar_one_or_none()
            
            if patient:
                new_link = PatientCaregiverLink(
                    patient_id=patient.id,
                    caregiver_id=new_user.id,
                    is_active=True
                )
                db.add(new_link)
                await db.commit()
                print(f"✅ Auto-linked caregiver {new_user.email} to patient {patient.email}")

        # Log registration
        audit_log = AuditLog(
            user_id=new_user.id,
            event_type="user_registered",
            event_description=f"User registered with role: {user_data.role}",
            event_data={"email": user_data.email, "role": user_data.role.value}
        )
        db.add(audit_log)
        await db.commit()
        
        return new_user

    except Exception as e:
        # CRITICAL: If database registration fails, we MUST delete the Firebase user 
        # to prevent orphaned Firebase accounts that can't login.
        print(f"❌ DATABASE REGISTRATION FAILED: {str(e)}")
        traceback.print_exc()
        
        if user_data.firebase_uid:
            await delete_firebase_user(user_data.firebase_uid)
            
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed. Please try again. Error: {str(e)}"
        )


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
    
    # CASE 1: User does not exist in Database (Possible DB reset or migration)
    if not user:
        # If we have a Firebase Token, we can try to recover/create the account
        if credentials.firebase_id_token:
            from app.core.firebase_admin import verify_firebase_token, extract_user_info_from_token
            
            # Verify token to ensure identity
            decoded_token = await verify_firebase_token(credentials.firebase_id_token)
            if not decoded_token:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid Firebase token"
                )
                
            # If we verified identity, we need a ROLE to create the account
            if not credentials.role:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Account recovery: Please confirm your role (patient or caregiver) to complete login."
                )
                
            # Create the Missing User
            user_info = extract_user_info_from_token(decoded_token)
            firebase_uid = user_info['firebase_uid']
            
            # Double check email match
            if user_info['email'].lower() != credentials.email.lower():
                 raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email mismatch between token and credentials"
                )

            # Create User
            user = User(
                email=credentials.email,
                hashed_password=get_password_hash(credentials.password), # Restore password hash
                full_name=user_info.get('display_name') or credentials.email.split('@')[0],
                role=credentials.role,
                firebase_uid=firebase_uid,
                auth_provider='email',
                is_verified=True,
                email_verified_at=datetime.utcnow() if user_info.get('email_verified') else None,
                profile_image_url=user_info.get('photo_url')
            )
            
            db.add(user)
            await db.commit()
            await db.refresh(user)
            
            # Continue to login...
        else:
            # No token, just standard failure
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"}
            )
    
    # CASE 2: User Exists
    # For users with Firebase UID, password is managed by Firebase
    if user.firebase_uid:
        # Firebase-authenticated user - password validation happens on client
        # Update the password hash in our database to stay in sync with Firebase
        # This handles cases where user reset password via Firebase
        user.hashed_password = get_password_hash(credentials.password)
        db.add(user)
        await db.commit()
    else:
        # Traditional email/password user - verify password hash
        if not verify_password(credentials.password, user.hashed_password):
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
    """
    from app.core.firebase_admin import verify_firebase_token, extract_user_info_from_token
    import traceback
    
    try:
        # 1. Verify Firebase token
        decoded_token = await verify_firebase_token(auth_data.firebase_id_token)
        if not decoded_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Firebase token"
            )
        
        # 2. Extract user info
        user_info = extract_user_info_from_token(decoded_token)
        firebase_uid = user_info['firebase_uid']
        email = user_info['email']
        email_verified = user_info['email_verified']
        
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email not provided by authentication provider"
            )
        
        # 3. Find User
        # First check by firebase_uid
        result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
        user = result.scalar_one_or_none()
        
        # If not found, check by email (Link existing email account)
        if not user:
            result = await db.execute(select(User).where(User.email == email))
            user = result.scalar_one_or_none()
            
            if user:
                # If this is a LOGIN attempt, we do NOT auto-link existing email accounts.
                # The user must specifically use the Register page to link their Google identity.
                if not auth_data.is_signup:
                    print(f"⚠️ Google Login attempt for existing email {email} but not linked via Google yet. Refusing.")
                    user = None # Treat as not found to trigger 404 below
                else:
                    # Expert Account Linking Logic (Only during Registration):
                    print(f"ℹ️ Linking existing account for {email} to social identity...")
                    
                    if user.firebase_uid != firebase_uid:
                        user.firebase_uid = firebase_uid
                    
                    if email_verified:
                        user.is_verified = True
                        user.email_verified_at = datetime.utcnow()
                    
                    if user.auth_provider == 'email':
                        user.auth_provider = user_info.get('auth_provider', 'google')
                    
                    db.add(user)
                    await db.commit()
                    await db.refresh(user)
        
        # 4. Create User if still not found
        if not user:
            # Check if this is a login attempt (not signup)
            if not auth_data.is_signup:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Login error: Not registered"
                )
            
            # For new users during signup, role is MANDATORY
            if not auth_data.role:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Please select a role (patient or caregiver) to complete registration."
                )
            
            user = User(
                email=email,
                hashed_password="",  # No password for social auth
                full_name=user_info.get('display_name') or email.split('@')[0],
                role=auth_data.role,
                phone=auth_data.phone,
                birth_date=auth_data.birth_date,
                gender=auth_data.gender,
                firebase_uid=firebase_uid,
                auth_provider=user_info.get('auth_provider', 'google'),
                is_verified=True,  # Social auth users are implicitly verified
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
                event_data={"email": email, "auth_provider": user_info['auth_provider'], "role": user.role.value}
            )
            db.add(audit_log)
            await db.commit()

        # 5. Handle Inactive Account
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is inactive"
            )
        
        # 6. Success - Generate Tokens
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
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )
    except Exception as e:
        print(f"❌ SOCIAL AUTH ERROR: {str(e)}")
        traceback.print_exc()
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
