from app.models.medical_contact import MedicalContact


def test_contact_type_enum_uses_database_values():
    contact_type = MedicalContact.__table__.c.contact_type.type

    assert "FAMILY" in contact_type.enums
