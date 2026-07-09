from uuid import UUID
import logging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.patient_caregiver_link import PatientCaregiverLink

logger = logging.getLogger(__name__)


async def assign_is_primary_for_new_link(db: AsyncSession, patient_id: UUID, link: PatientCaregiverLink) -> None:
    """
    Check if the patient already has an active primary caregiver link.
    If not, set this link as primary.
    """
    stmt = (
        select(PatientCaregiverLink)
        .where(PatientCaregiverLink.patient_id == patient_id)
        .where(PatientCaregiverLink.is_active == True)
        .where(PatientCaregiverLink.is_primary == True)
        .where(PatientCaregiverLink.id != link.id)
    )
    result = db.execute(stmt) if not hasattr(db, "execute") else await db.execute(stmt)
    primary_active = result.scalar_one_or_none()
    
    if primary_active is None:
        link.is_primary = True
        logger.info(f"Setting link {link.id} as primary for patient {patient_id}")
    else:
        link.is_primary = False


async def promote_new_primary_if_needed(db: AsyncSession, patient_id: UUID, deactivated_link: PatientCaregiverLink) -> None:
    """
    Called when a primary caregiver link is deactivated (soft deleted).
    Promotes the oldest remaining active caregiver link for the patient to primary.
    """
    if not deactivated_link.is_primary:
        return
        
    stmt = (
        select(PatientCaregiverLink)
        .where(PatientCaregiverLink.patient_id == patient_id)
        .where(PatientCaregiverLink.is_active == True)
        .where(PatientCaregiverLink.id != deactivated_link.id)
        .order_by(PatientCaregiverLink.linked_at.asc())
    )
    result = db.execute(stmt) if not hasattr(db, "execute") else await db.execute(stmt)
    remaining_links = result.scalars().all()
    
    deactivated_link.is_primary = False
    
    if remaining_links:
        oldest_link = remaining_links[0]
        oldest_link.is_primary = True
        logger.info(f"Promoted oldest link {oldest_link.id} to primary for patient {patient_id}")
