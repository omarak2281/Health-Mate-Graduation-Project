import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, delete

from app.models.patient_calibration import PatientCalibration, CalibrationSample


class CalibrationService:
    """
    Manages patient-specific blood pressure calibration.
    Follows Smart Box BP Master Implementation Plan (Section 4.3):
    1. Under 8 samples: Additive-only median offset (resists noisy individual points).
    2. 8+ samples: Linear regression mapping model BP to cuff BP.
    Clamps coefficients (scale [0.7, 1.3], offset [-25.0, 25.0]) to protect safety.
    """

    LINEAR_UPGRADE_THRESHOLD = 8
    SCALE_CLAMP = (0.7, 1.3)
    OFFSET_CLAMP = (-25.0, 25.0)

    async def add_calibration_sample(
        self,
        db: AsyncSession,
        patient_id: UUID,
        model_sbp: float,
        model_dbp: float,
        cuff_sbp: float,
        cuff_dbp: float,
        signal_quality: float = 1.0,
    ) -> CalibrationSample:
        """
        Record a pair of model-predicted BP vs reference cuff-measured BP.
        Validates quality and physiological range.
        """
        # Validate physiological range (cuff SBP 70-200, DBP 40-130, SBP > DBP)
        if not (70 <= cuff_sbp <= 200) or not (40 <= cuff_dbp <= 130) or (cuff_sbp <= cuff_dbp):
            raise ValueError("Reference cuff BP out of physiological bounds")

        # Validate predicted range
        if not (50 <= model_sbp <= 300) or not (30 <= model_dbp <= 200) or (model_sbp <= model_dbp):
            raise ValueError("Model predicted BP out of physiological bounds")

        sample = CalibrationSample(
            patient_id=patient_id,
            model_sbp=model_sbp,
            model_dbp=model_dbp,
            cuff_sbp=cuff_sbp,
            cuff_dbp=cuff_dbp,
            signal_quality=signal_quality,
            measured_at=datetime.utcnow()
        )
        db.add(sample)
        await db.commit()
        await db.refresh(sample)
        
        # Clean up samples older than 30 days to prevent stale drift data
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        stmt = delete(CalibrationSample).where(
            CalibrationSample.patient_id == patient_id,
            CalibrationSample.measured_at < thirty_days_ago
        )
        await db.execute(stmt)
        await db.commit()
        
        # Recalculate calibration fit automatically
        await self.fit_calibration(db, patient_id)
        
        return sample

    async def fit_calibration(self, db: AsyncSession, patient_id: UUID) -> Optional[PatientCalibration]:
        """
        Fits calibration according to sample count:
        - If < 8: Additive-only (median offset, scale = 1.0).
        - If >= 8: Least squares fit (scale and offset).
        Clamps parameters and sets drift baseline check values.
        """
        # Get active samples
        stmt = (
            select(CalibrationSample)
            .where(CalibrationSample.patient_id == patient_id)
            .order_by(desc(CalibrationSample.measured_at))
            .limit(10)
        )
        res = await db.execute(stmt)
        samples = res.scalars().all()
        
        # Get or create calibration record
        c_stmt = select(PatientCalibration).where(PatientCalibration.patient_id == patient_id)
        c_res = await db.execute(c_stmt)
        calibration = c_res.scalar_one_or_none()
        
        if not calibration:
            calibration = PatientCalibration(patient_id=patient_id)
            db.add(calibration)
            
        calibration.samples_count = len(samples)
        
        if len(samples) == 0:
            calibration.calibration_status = "not_calibrated"
            calibration.sbp_scale = 1.0
            calibration.sbp_offset = 0.0
            calibration.dbp_scale = 1.0
            calibration.dbp_offset = 0.0
            calibration.baseline_raw_mean_sbp = None
            calibration.baseline_raw_mean_dbp = None
            await db.commit()
            await db.refresh(calibration)
            return calibration

        try:
            # 1. Under upgrade threshold: Additive-only
            if len(samples) < self.LINEAR_UPGRADE_THRESHOLD:
                sbp_diffs = [s.cuff_sbp - s.model_sbp for s in samples]
                dbp_diffs = [s.cuff_dbp - s.model_dbp for s in samples]
                
                sbp_offset = float(np.median(sbp_diffs))
                dbp_offset = float(np.median(dbp_diffs))
                
                # Clamp offset
                calibration.sbp_scale = 1.0
                calibration.sbp_offset = float(np.clip(sbp_offset, self.OFFSET_CLAMP[0], self.OFFSET_CLAMP[1]))
                calibration.dbp_scale = 1.0
                calibration.dbp_offset = float(np.clip(dbp_offset, self.OFFSET_CLAMP[0], self.OFFSET_CLAMP[1]))
                
                calibration.calibration_status = "cold_start" if len(samples) == 1 else "additive"
            else:
                # 2. Linear regression fitting
                x_sbp = np.array([s.model_sbp for s in samples], dtype=np.float64)
                y_sbp = np.array([s.cuff_sbp for s in samples], dtype=np.float64)
                
                if np.std(x_sbp) < 1e-4:
                    sbp_scale = 1.0
                    sbp_offset = np.mean(y_sbp) - np.mean(x_sbp)
                else:
                    sbp_scale, sbp_offset = np.polyfit(x_sbp, y_sbp, 1)
                    
                x_dbp = np.array([s.model_dbp for s in samples], dtype=np.float64)
                y_dbp = np.array([s.cuff_dbp for s in samples], dtype=np.float64)
                
                if np.std(x_dbp) < 1e-4:
                    dbp_scale = 1.0
                    dbp_offset = np.mean(y_dbp) - np.mean(x_dbp)
                else:
                    dbp_scale, dbp_offset = np.polyfit(x_dbp, y_dbp, 1)
                
                # Check clamping to detect weak calibration
                clamped_sbp_scale = float(np.clip(sbp_scale, self.SCALE_CLAMP[0], self.SCALE_CLAMP[1]))
                clamped_sbp_offset = float(np.clip(sbp_offset, self.OFFSET_CLAMP[0], self.OFFSET_CLAMP[1]))
                clamped_dbp_scale = float(np.clip(dbp_scale, self.SCALE_CLAMP[0], self.SCALE_CLAMP[1]))
                clamped_dbp_offset = float(np.clip(dbp_offset, self.OFFSET_CLAMP[0], self.OFFSET_CLAMP[1]))
                
                is_clamped = (
                    clamped_sbp_scale != sbp_scale or
                    clamped_sbp_offset != sbp_offset or
                    clamped_dbp_scale != dbp_scale or
                    clamped_dbp_offset != dbp_offset
                )
                
                calibration.sbp_scale = clamped_sbp_scale
                calibration.sbp_offset = clamped_sbp_offset
                calibration.dbp_scale = clamped_dbp_scale
                calibration.dbp_offset = clamped_dbp_offset
                
                calibration.calibration_status = "weak" if is_clamped else "linear"

            # Set baseline check parameters (Section 4.3): seed baseline using last min(10, len(points))
            # (Note: samples is already limited to 10 by query)
            calibration.baseline_raw_mean_sbp = float(np.mean([s.model_sbp for s in samples]))
            calibration.baseline_raw_mean_dbp = float(np.mean([s.model_dbp for s in samples]))
            calibration.last_calibrated_at = datetime.utcnow()
            
            # Clear drift flag on successful recalculation
            calibration.drift_flag = False
            calibration.drift_reason = None
            calibration.drift_flagged_at = None

        except Exception as e:
            # Fallback to defaults on fitting failure
            print(f"Calibration fit calculation failed: {e}")
            calibration.sbp_scale = 1.0
            calibration.sbp_offset = 0.0
            calibration.dbp_scale = 1.0
            calibration.dbp_offset = 0.0
            calibration.calibration_status = "not_calibrated"
            
        await db.commit()
        await db.refresh(calibration)
        return calibration

    async def get_calibration_status(self, db: AsyncSession, patient_id: UUID) -> Dict:
        """
        Get patient's calibration configuration status.
        Triggers "recalibration_due" if last calibrated > 30 days ago.
        """
        stmt = select(PatientCalibration).where(PatientCalibration.patient_id == patient_id)
        res = await db.execute(stmt)
        calibration = res.scalar_one_or_none()
        
        if not calibration:
            return {
                "status": "not_calibrated",
                "samples_count": 0,
                "last_calibrated_at": None,
                "recalibration_due": True,
                "coefficients": {
                    "sbp_scale": 1.0,
                    "sbp_offset": 0.0,
                    "dbp_scale": 1.0,
                    "dbp_offset": 0.0,
                },
                "drift_flag": False
            }
            
        # Check expiry (30 days)
        recal_due = False
        status_val = calibration.calibration_status
        
        if calibration.last_calibrated_at:
            age = datetime.utcnow() - calibration.last_calibrated_at
            if age > timedelta(days=30):
                recal_due = True
                status_val = "recalibration_due"
                # Update status in db list
                if calibration.calibration_status != "recalibration_due":
                    calibration.calibration_status = "recalibration_due"
                    await db.commit()
        else:
            recal_due = True
            
        return {
            "status": status_val,
            "samples_count": calibration.samples_count,
            "last_calibrated_at": calibration.last_calibrated_at.isoformat() if calibration.last_calibrated_at else None,
            "recalibration_due": recal_due or calibration.drift_flag,
            "coefficients": {
                "sbp_scale": calibration.sbp_scale,
                "sbp_offset": calibration.sbp_offset,
                "dbp_scale": calibration.dbp_scale,
                "dbp_offset": calibration.dbp_offset,
            },
            "drift_flag": calibration.drift_flag,
            "drift_reason": calibration.drift_reason
        }

    async def apply_calibration(
        self, db: AsyncSession, patient_id: UUID, model_sbp: float, model_dbp: float
    ) -> Dict[str, float]:
        """
        Apply patient scale and offset calibration to raw predicted SBP/DBP.
        """
        stmt = select(PatientCalibration).where(PatientCalibration.patient_id == patient_id)
        res = await db.execute(stmt)
        cal = res.scalar_one_or_none()
        
        if not cal or cal.calibration_status == "not_calibrated":
            return {
                "systolic": model_sbp,
                "diastolic": model_dbp,
                "calibration_status": "not_calibrated"
            }
            
        cal_sbp = cal.sbp_scale * model_sbp + cal.sbp_offset
        cal_dbp = cal.dbp_scale * model_dbp + cal.dbp_offset
        
        # Clamp to physiological maxima/minima
        cal_sbp = float(np.clip(cal_sbp, 50.0, 300.0))
        cal_dbp = float(np.clip(cal_dbp, 30.0, 200.0))
        
        # Check recalibration due date dynamically
        status_val = cal.calibration_status
        if cal.last_calibrated_at:
            if (datetime.utcnow() - cal.last_calibrated_at) > timedelta(days=30):
                status_val = "recalibration_due"
                
        # If drift flagged, reflect it in status
        if cal.drift_flag:
            status_val = "recalibration_due"
                
        return {
            "systolic": round(cal_sbp, 1),
            "diastolic": round(cal_dbp, 1),
            "calibration_status": status_val
        }


# Singleton service
calibration_service = CalibrationService()


def get_calibration_service() -> CalibrationService:
    return calibration_service
