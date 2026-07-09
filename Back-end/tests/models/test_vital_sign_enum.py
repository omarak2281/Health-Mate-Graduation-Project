from sqlalchemy.dialects import postgresql

from app.models.vital_sign import MeasurementStatus, VitalSign


def test_measurement_status_binds_lowercase_values_for_postgres():
    enum_type = VitalSign.__table__.c.measurement_status.type
    bind_processor = enum_type.bind_processor(postgresql.dialect())

    assert enum_type.enums == ["completed", "completed_pending_bp", "rejected"]
    assert enum_type._db_value_for_elem(
        MeasurementStatus.COMPLETED_PENDING_BP
    ) == "completed_pending_bp"
    assert bind_processor(MeasurementStatus.COMPLETED_PENDING_BP) == "completed_pending_bp"
