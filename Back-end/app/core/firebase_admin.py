"""
Firebase Admin SDK initialization and utilities
Handles Firebase token verification and user management
"""

import os
import firebase_admin
from firebase_admin import credentials, auth, messaging
from typing import Optional, Dict, List, Any
from app.core.config import settings


# Initialize Firebase Admin SDK
def initialize_firebase():
    """Initialize Firebase Admin SDK with credentials"""
    try:
        # Check if already initialized
        firebase_admin.get_app()
    except ValueError:
        # Not initialized, proceed with initialization.
        # Single source of truth: FIREBASE_CREDENTIALS_PATH env var, falling
        # back to "serviceAccountKey.json" in the working directory. Do NOT
        # add extra fallback filenames here -- silently picking whichever
        # credential file happens to exist on disk is what caused stale/
        # rotated keys to be loaded and produce "Invalid JWT Signature".
        import json
        file_name = os.getenv('FIREBASE_CREDENTIALS_PATH') or "serviceAccountKey.json"

        cred = None
        if os.path.exists(file_name):
            print(f"📂 Reading and sanitizing Firebase credentials: {file_name}")
            try:
                with open(file_name, 'r') as f:
                    cred_dict = json.load(f)
                # FIX: Manually ensure the private key has real newlines
                if 'private_key' in cred_dict:
                    cred_dict['private_key'] = cred_dict['private_key'].replace('\\n', '\n')
                cred = credentials.Certificate(cred_dict)
            except Exception as e:
                print(f"⚠️ Error reading {file_name}: {e}")

        if not cred:
            print(f"WARNING: Firebase credentials not found at '{file_name}'. Authentication may fail.")
            return

        import datetime
        try:
            # Ensure the credentials dict is clean if loading from dictionary
            # but here we use Certificate. We'll add extra logging.
            app = firebase_admin.initialize_app(cred)
            print(f"✅ Firebase Admin SDK initialized for project: {app.project_id}")
            print(f"⏰ Current Container Time: {datetime.datetime.now()}")
            print(f"🌍 Current UTC Time: {datetime.datetime.utcnow()}")
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


async def delete_firebase_user(firebase_uid: str) -> bool:
    """
    Delete a user from Firebase
    Used for cleanup if database registration fails
    """
    try:
        auth.delete_user(firebase_uid)
        print(f"🧹 Successfully deleted orphaned Firebase user: {firebase_uid}")
        return True
    except Exception as e:
        print(f"❌ Failed to delete Firebase user {firebase_uid}: {str(e)}")
        return False


# Initialize on module import
initialize_firebase()


async def send_push_notification(
    token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None
) -> tuple[Optional[str], bool]:
    """
    Send a push notification to a specific device via FCM

    Args:
        token: Device registration token
        title: Notification title
        body: Notification body
        data: Additional data payload (all values must be strings)

    Returns:
        Tuple of (message_id or None, token_is_invalid).
        `token_is_invalid` is only True when FCM confirms the *device token*
        itself is dead (unregistered/mismatched sender) -- callers should
        only wipe the user's stored fcm_token in that case. Any other
        failure (credentials, network, quota) is transient and must not be
        mistaken for a bad device token.
    """
    # Firebase requires all data values to be strings
    payload = data or {}
    string_payload = {k: str(v) for k, v in payload.items()}
    if 'title' not in string_payload:
        string_payload['title'] = title
    if 'body' not in string_payload:
        string_payload['body'] = body

    # By NOT providing the 'notification' parameter, Firebase sends a
    # "Data-only" message. This prevents the OS from showing its own silent
    # notification, avoiding duplication.
    message = messaging.Message(
        data=string_payload,
        token=token,
        android=messaging.AndroidConfig(
            priority='high',
        ),
    )

    try:
        response = messaging.send(message)
        print(f"✅ Successfully sent push notification: {response}")
        return response, False
    except (messaging.UnregisteredError, messaging.SenderIdMismatchError) as e:
        # The device token itself is dead -- safe to clear it.
        print(f"❌ FCM token invalid for this device: {str(e)}")
        return None, True
    except Exception as e:
        import datetime
        print(f"⏰ Server Local Time: {datetime.datetime.now()}")
        print(f"❌ FCM Error: {str(e)}")

        # If it's a credential/auth error, re-initialize and retry ONCE so
        # the notification isn't silently dropped for this trigger.
        if "invalid_grant" in str(e).lower() or "signature" in str(e).lower():
            print("🔄 Attempting to refresh Firebase initialization and retry send...")
            try:
                firebase_admin.delete_app(firebase_admin.get_app())
                initialize_firebase()
                response = messaging.send(message)
                print(f"✅ Retry succeeded: {response}")
                return response, False
            except (messaging.UnregisteredError, messaging.SenderIdMismatchError) as e2:
                print(f"❌ FCM token invalid for this device: {str(e2)}")
                return None, True
            except Exception as e2:
                print(f"❌ Retry after credential refresh also failed: {str(e2)}")
                return None, False

        # Transient/unknown error -- do NOT report the token as invalid.
        return None, False
