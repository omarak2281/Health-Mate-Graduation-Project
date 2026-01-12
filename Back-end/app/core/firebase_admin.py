"""
Firebase Admin SDK initialization and utilities
Handles Firebase token verification and user management
"""

import os
import firebase_admin
from firebase_admin import credentials, auth
from typing import Optional, Dict, Any
from app.core.config import settings


# Initialize Firebase Admin SDK
def initialize_firebase():
    """Initialize Firebase Admin SDK with credentials"""
    try:
        # Check if already initialized
        firebase_admin.get_app()
    except ValueError:
        # Not initialized, proceed with initialization
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        
        if cred_path and os.path.exists(cred_path):
            # Use environment variable path
            cred = credentials.Certificate(cred_path)
        elif os.path.exists("healt-mate-44e8b-firebase-adminsdk-fbsvc-ff9a15b67d.json"):
            # Use provided service account file in root/backend
            cred = credentials.Certificate("healt-mate-44e8b-firebase-adminsdk-fbsvc-ff9a15b67d.json")
        else:
            # Check environment variables
            firebase_project_id = os.getenv('FIREBASE_PROJECT_ID')
            # ... (rest of logic)
            if firebase_project_id:
                 # ... construct cred_dict
                 pass
            else:
                 print("WARNING: Firebase Credentials not found. Authentication may fail.")
                 return

        try:
             firebase_admin.initialize_app(cred)
             print("✅ Firebase Admin SDK initialized successfully")
        except ValueError:
             # Already initialized
             pass
        except Exception as e:
            print(f"❌ Failed to initialize Firebase Admin SDK: {e}")


async def verify_firebase_token(id_token: str) -> Optional[Dict[str, Any]]:
    """
    Verify Firebase ID token and return decoded token data
    
    Args:
        id_token: Firebase ID token from client
        
    Returns:
        Decoded token data with user info or None if invalid
        
    Raises:
        auth.InvalidIdTokenError: If token is invalid
        auth.ExpiredIdTokenError: If token is expired
        auth.RevokedIdTokenError: If token is revoked
    """
    try:
        # Verify the ID token
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except auth.InvalidIdTokenError as e:
        raise ValueError(f"Invalid Firebase token: {str(e)}")
    except auth.ExpiredIdTokenError as e:
        raise ValueError(f"Expired Firebase token: {str(e)}")
    except auth.RevokedIdTokenError as e:
        raise ValueError(f"Revoked Firebase token: {str(e)}")
    except Exception as e:
        raise ValueError(f"Firebase token verification failed: {str(e)}")


async def get_firebase_user(firebase_uid: str) -> Optional[Dict[str, Any]]:
    """
    Get Firebase user data by UID
    
    Args:
        firebase_uid: Firebase user UID
        
    Returns:
        User data dictionary or None if not found
    """
    try:
        user = auth.get_user(firebase_uid)
        return {
            'uid': user.uid,
            'email': user.email,
            'email_verified': user.email_verified,
            'display_name': user.display_name,
            'photo_url': user.photo_url,
            'disabled': user.disabled,
        }
    except auth.UserNotFoundError:
        return None
    except Exception as e:
        raise ValueError(f"Failed to get Firebase user: {str(e)}")


async def check_email_verified(firebase_uid: str) -> bool:
    """
    Check if Firebase user's email is verified
    
    Args:
        firebase_uid: Firebase user UID
        
    Returns:
        True if email is verified, False otherwise
    """
    try:
        user = auth.get_user(firebase_uid)
        return user.email_verified
    except Exception:
        return False


def extract_user_info_from_token(decoded_token: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract user information from decoded Firebase token
    
    Args:
        decoded_token: Decoded Firebase ID token
        
    Returns:
        Dictionary with user info (uid, email, name, picture, email_verified)
    """
    return {
        'firebase_uid': decoded_token.get('uid'),
        'email': decoded_token.get('email'),
        'email_verified': decoded_token.get('email_verified', False),
        'display_name': decoded_token.get('name'),
        'photo_url': decoded_token.get('picture'),
        'auth_provider': _get_auth_provider(decoded_token),
    }


def _get_auth_provider(decoded_token: Dict[str, Any]) -> str:
    """
    Determine auth provider from Firebase token
    
    Args:
        decoded_token: Decoded Firebase ID token
        
    Returns:
        'google' or 'email'
    """
    firebase_data = decoded_token.get('firebase', {})
    sign_in_provider = firebase_data.get('sign_in_provider', '')
    
    if 'google' in sign_in_provider.lower():
        return 'google'
    else:
        return 'email'


# Initialize on module import
initialize_firebase()
