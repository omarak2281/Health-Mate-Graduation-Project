import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from app.models.patient_calibration import PatientCalibration
from app.models.vital_sign import VitalSign, MeasurementStatus
from app.models.notification import NotificationType
from app.services.notification_service import get_notification_service


class BPDriftService:
    """
    Monitors blood pressure calibration drift and staleness.
    Runs as a scheduled daily job.
    Matches Smart Box BP Master Implementation Plan (Section 5.5).
    """

    async def check_all_patients(self, db: AsyncSession):
        """
        Check all active calibrations for drift and staleness.
        Sends a notification if flagged and cooldown has expired.
        """
        # Fetch all patient calibrations
        stmt = select(PatientCalibration)
        res = await db.execute(stmt)
        calibrations = res.scalars().all()

        notification_service = get_notification_service()

        for cal in calibrations:
            # Skip if calibration has no baseline raw values set
            if cal.baseline_raw_mean_sbp is None or cal.baseline_raw_mean_dbp is None:
                continue

            # Fetch last 10 valid RAW (pre-calibrated) readings
            readings_stmt = (
                select(VitalSign)
                .where(
                    VitalSign.user_id == cal.patient_id,
                    VitalSign.measurement_status == MeasurementStatus.COMPLETED,
                    VitalSign.model_systolic.is_not(None),
                    VitalSign.model_diastolic.is_not(None)
                )
                .order_by(desc(VitalSign.measured_at))
                .limit(10)
            )
            r_res = await db.execute(readings_stmt)
            readings = r_res.scalars().all()

            # Must have at least 5 readings to evaluate sustained drift
            if len(readings) < 5:
                continue

            recent_mean_sbp = float(np.mean([r.model_systolic for r in readings]))
            recent_mean_dbp = float(np.mean([r.model_diastolic for r in readings]))

            # sbp_drifted = abs(recent_mean_sbp - baseline_raw_mean_sbp) > 8 AND sustained over last 5 readings
            sbp_drifted = (
                abs(recent_mean_sbp - cal.baseline_raw_mean_sbp) > 8.0 and
                all(abs(r.model_systolic - cal.baseline_raw_mean_sbp) > 8.0 for r in readings[:5])
            )

            # dbp_drifted = abs(recent_mean_dbp - baseline_raw_mean_dbp) > 5 AND sustained over last 5 readings
            dbp_drifted = (
                abs(recent_mean_dbp - cal.baseline_raw_mean_dbp) > 5.0 and
                all(abs(r.model_diastolic - cal.baseline_raw_mean_dbp) > 5.0 for r in readings[:5])
            )

            # staleness check (90 days)
            is_stale = False
            if cal.last_calibrated_at:
                is_stale = (datetime.utcnow() - cal.last_calibrated_at) > timedelta(days=90)
            else:
                is_stale = True

            if sbp_drifted or dbp_drifted or is_stale:
                now = datetime.utcnow()
                # Cooldown check: 14 days
                if cal.last_drift_notification_at is None or (now - cal.last_drift_notification_at) > timedelta(days=14):
                    cal.drift_flag = True
                    cal.drift_reason = 'drift_detected' if (sbp_drifted or dbp_drifted) else 'calibration_stale'
                    cal.drift_flagged_at = now
                    cal.last_drift_notification_at = now
                    db.add(cal)
                    await db.commit()

                    # Send push notification
                    try:
                        title = "🔄 Blood Pressure Calibration Needed"
                        if cal.drift_reason == 'drift_detected':
                            message = "We detected a shift in your device signal patterns. Please perform a validation measurement with a BP cuff to recalibrate."
                        else:
                            message = "Your blood pressure calibration has expired. Please perform a cuff measurement to keep readings accurate."

                        await notification_service.create_notification(
                            db=db,
                            user_id=str(cal.patient_id),
                            notification_type=NotificationType.BP_DRIFT_ALERT,
                            title=title,
                            message=message,
                            data={
                                "patient_id": str(cal.patient_id),
                                "drift_reason": cal.drift_reason,
                                "action": "open_recalibration"
                            }
                        )
                    except Exception as e:
                        print(f"Failed to send drift notification: {e}")

# Singleton service
bp_drift_service = BPDriftService()


def get_bp_drift_service() -> BPDriftService:
    return bp_drift_service
