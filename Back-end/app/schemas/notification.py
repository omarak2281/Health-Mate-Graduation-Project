"""
Notifications schemas
"""

from pydantic import BaseModel
from typing import Optional, Dict, List
from datetime import datetime
from uuid import UUID
from app.models.notification import NotificationType


class NotificationResponse(BaseModel):
    """Notification response"""
    id: UUID
    user_id: UUID
    notification_type: NotificationType
    title: str
    message: str
    data: Optional[Dict]
    is_read: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class NotificationMarkRead(BaseModel):
    """Mark notification as read"""
    notification_ids: List[UUID]
