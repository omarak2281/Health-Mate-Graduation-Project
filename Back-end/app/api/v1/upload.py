"""
File upload router for images
Handles profile pictures and medication images
"""

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.services.cloudinary_service import get_cloudinary_service, CloudinaryService

router = APIRouter(prefix="/upload", tags=["File Upload"])


@router.post("/image")
async def upload_generic_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    cloudinary: CloudinaryService = Depends(get_cloudinary_service)
):
    """
    Generic image upload
    """
    result = await cloudinary.upload_image(
        file=file,
        metadata={
            "user_id": str(current_user.id),
            "type": "generic"
        }
    )
    return {
        "message": "Image uploaded successfully",
        "url": result["url"],
        "image_id": result["image_id"]
    }


@router.post("/profile-picture")
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    cloudinary: CloudinaryService = Depends(get_cloudinary_service)
):
    """
    Upload profile picture for current user
    
    - **file**: Image file (JPG, PNG, WebP)
    
    Returns Cloudinary image URL and saves to user profile
    """
    # Upload to Cloudinary
    result = await cloudinary.upload_image(
        file=file,
        folder="profile_pictures",
        metadata={
            "user_id": str(current_user.id),
            "type": "profile_picture"
        }
    )
    
    # Update user profile with image URL
    current_user.profile_image_url = result["url"]
    await db.commit()
    await db.refresh(current_user)
    
    return {
        "message": "Profile picture uploaded successfully",
        "url": result["url"],
        "image_url": result["url"],
        "image_id": result["image_id"]
    }


@router.post("/medication-image")
async def upload_medication_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    cloudinary: CloudinaryService = Depends(get_cloudinary_service)
):
    """
    Upload medication image
    
    - **file**: Image file (JPG, PNG, WebP)
    
    Returns Cloudinary image URL (to be saved with medication record)
    """
    # Upload to Cloudinary
    result = await cloudinary.upload_image(
        file=file,
        folder="medications",
        metadata={
            "user_id": str(current_user.id),
            "type": "medication_image"
        }
    )
    
    return {
        "message": "Medication image uploaded successfully",
        "url": result["url"],
        "image_url": result["url"],
        "image_id": result["image_id"]
    }


@router.delete("/image/{image_id}")
async def delete_image(
    image_id: str,
    current_user: User = Depends(get_current_user),
    cloudinary: CloudinaryService = Depends(get_cloudinary_service)
):
    """
    Delete image from Cloudinary
    
    - **image_id**: Cloudinary public ID
    """
    success = await cloudinary.delete_image(image_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete image"
        )
    
    return {"message": "Image deleted successfully"}
