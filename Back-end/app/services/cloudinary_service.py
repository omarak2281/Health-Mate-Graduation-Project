import cloudinary
import cloudinary.uploader
from cloudinary.utils import cloudinary_url
from typing import Optional, Dict, Any
from fastapi import UploadFile, HTTPException, status
from app.core.config import settings

class CloudinaryService:
    """
    Cloudinary API integration
    
    Uploads images to Cloudinary and returns public URLs
    """
    
    def __init__(self):
        """Initialize Cloudinary service"""
        self.cloud_name = settings.cloudinary_cloud_name
        self.api_key = settings.cloudinary_api_key
        self.api_secret = settings.cloudinary_api_secret
        
        if not all([self.cloud_name, self.api_key, self.api_secret]):
            print("⚠️ Cloudinary credentials not fully configured. Image upload will not work.")
        else:
            cloudinary.config(
                cloud_name=self.cloud_name,
                api_key=self.api_key,
                api_secret=self.api_secret,
                secure=True
            )
    
    async def upload_image(
        self,
        file: UploadFile,
        folder: str = "health_mate",
        public_id: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Upload image to Cloudinary
        """
        if not all([self.cloud_name, self.api_key, self.api_secret]):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Image upload service not configured."
            )
            
        # Validate file type
        if not file.content_type or not file.content_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only images are allowed."
            )
            
        try:
            # Read file content
            file_content = await file.read()
            
            # Upload to Cloudinary
            upload_result = cloudinary.uploader.upload(
                file_content,
                folder=folder,
                public_id=public_id,
                context=metadata if metadata else {}
            )
            
            return {
                "image_id": upload_result.get("public_id"),
                "url": upload_result.get("secure_url"),
                "filename": file.filename,
                "uploaded_at": upload_result.get("created_at")
            }
            
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Cloudinary upload failed: {str(e)}"
            )
        finally:
            await file.seek(0)
            
    async def delete_image(self, public_id: str) -> bool:
        """
        Delete image from Cloudinary
        """
        if not all([self.cloud_name, self.api_key, self.api_secret]):
            return False
            
        try:
            result = cloudinary.uploader.destroy(public_id)
            return result.get("result") == "ok"
        except Exception:
            return False

# Singleton instance
cloudinary_service = CloudinaryService()

def get_cloudinary_service() -> CloudinaryService:
    """Get Cloudinary service instance"""
    return cloudinary_service
