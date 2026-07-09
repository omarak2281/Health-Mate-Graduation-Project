from app.domain.entities.assessment import Vitals
from app.domain.rules_engine.bp_rules import classify_bp_vitals, is_bp_elevated


def test_classify_bp_vitals_none_returns_none():
    assert classify_bp_vitals(None) is None


def test_classify_bp_vitals_all_none_fields_returns_none():
    assert classify_bp_vitals(Vitals()) is None


def test_classify_bp_vitals_normal_returns_none():
    assert classify_bp_vitals(Vitals(systolic=118, diastolic=76, spo2=98)) is None


def test_classify_bp_vitals_critical_systolic():
    assert classify_bp_vitals(Vitals(systolic=185)) == "critical"


def test_classify_bp_vitals_critical_diastolic():
    assert classify_bp_vitals(Vitals(diastolic=125)) == "critical"


def test_classify_bp_vitals_critical_spo2():
    assert classify_bp_vitals(Vitals(spo2=88)) == "critical"


def test_classify_bp_vitals_high_systolic():
    assert classify_bp_vitals(Vitals(systolic=150)) == "high"


def test_classify_bp_vitals_high_hypotension_systolic():
    assert classify_bp_vitals(Vitals(systolic=85)) == "high"


def test_classify_bp_vitals_high_diastolic():
    assert classify_bp_vitals(Vitals(diastolic=95)) == "high"


def test_classify_bp_vitals_high_spo2():
    assert classify_bp_vitals(Vitals(spo2=92)) == "high"


def test_classify_bp_vitals_critical_takes_precedence_over_high():
    # SBP 185 alone is critical even though DBP 95 alone would only be "high"
    assert classify_bp_vitals(Vitals(systolic=185, diastolic=95)) == "critical"


def test_is_bp_elevated_none_vitals_false():
    assert is_bp_elevated(None) is False


def test_is_bp_elevated_all_none_fields_false():
    assert is_bp_elevated(Vitals()) is False


def test_is_bp_elevated_normal_false():
    assert is_bp_elevated(Vitals(systolic=115, diastolic=75)) is False


def test_is_bp_elevated_systolic_true():
    assert is_bp_elevated(Vitals(systolic=132, diastolic=75)) is True


def test_is_bp_elevated_diastolic_true():
    assert is_bp_elevated(Vitals(systolic=118, diastolic=84)) is True
