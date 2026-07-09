from app.domain.entities.assessment import SelectedSymptom
from app.domain.rules_engine.red_flag_rules import evaluate_red_flags


def _symptom(id: str, severity: int, red_flag: bool) -> SelectedSymptom:
    return SelectedSymptom(id=id, severity=severity, red_flag=red_flag)


def test_non_red_flag_symptom_never_triggers_regardless_of_severity():
    symptoms = [_symptom("cough", severity=4, red_flag=False)]
    assert evaluate_red_flags(symptoms) == []


def test_red_flag_symptom_below_default_threshold_does_not_trigger():
    symptoms = [_symptom("chest_pain", severity=1, red_flag=True)]
    assert evaluate_red_flags(symptoms) == []


def test_red_flag_symptom_at_default_threshold_triggers():
    symptoms = [_symptom("chest_pain", severity=2, red_flag=True)]
    flags = evaluate_red_flags(symptoms)
    assert len(flags) == 1
    assert flags[0].code == "chest_pain"
    assert flags[0].symptom_id == "chest_pain"
    assert flags[0].severity == 2


def test_red_flag_symptom_above_default_threshold_triggers():
    symptoms = [_symptom("shortness_of_breath", severity=4, red_flag=True)]
    flags = evaluate_red_flags(symptoms)
    assert len(flags) == 1
    assert flags[0].code == "shortness_of_breath"


def test_syncope_triggers_at_severity_one():
    symptoms = [_symptom("syncope", severity=1, red_flag=True)]
    flags = evaluate_red_flags(symptoms)
    assert len(flags) == 1
    assert flags[0].code == "syncope"


def test_syncope_does_not_trigger_at_severity_zero():
    symptoms = [_symptom("syncope", severity=0, red_flag=True)]
    assert evaluate_red_flags(symptoms) == []


def test_loss_of_consciousness_triggers_at_severity_one():
    symptoms = [_symptom("loss_of_consciousness", severity=1, red_flag=True)]
    flags = evaluate_red_flags(symptoms)
    assert len(flags) == 1
    assert flags[0].code == "loss_of_consciousness"


def test_sudden_loss_of_consciousness_triggers_at_severity_one():
    symptoms = [_symptom("sudden_loss_of_consciousness", severity=1, red_flag=True)]
    flags = evaluate_red_flags(symptoms)
    assert len(flags) == 1
    assert flags[0].code == "sudden_loss_of_consciousness"


def test_stroke_symptom_combo_all_trigger():
    """Plan §6 Phase 2 DoD: stroke symptoms (sudden numbness / trouble speaking / loss of
    balance) = emergency. All three are red-flag symptoms that should trigger together."""
    symptoms = [
        _symptom("sudden_numbness", severity=2, red_flag=True),
        _symptom("trouble_speaking", severity=3, red_flag=True),
        _symptom("loss_of_balance", severity=2, red_flag=True),
    ]
    flags = evaluate_red_flags(symptoms)
    assert {f.code for f in flags} == {"sudden_numbness", "trouble_speaking", "loss_of_balance"}


def test_chest_pain_and_shortness_of_breath_combo_both_trigger():
    """Plan §6 Phase 2 DoD: 'chest pain + shortness of breath = urgent'."""
    symptoms = [
        _symptom("chest_pain", severity=2, red_flag=True),
        _symptom("shortness_of_breath", severity=2, red_flag=True),
    ]
    flags = evaluate_red_flags(symptoms)
    assert {f.code for f in flags} == {"chest_pain", "shortness_of_breath"}


def test_fainting_triggers_emergency_red_flag():
    """Plan §6 Phase 2 DoD: 'fainting = emergency' — modeled as syncope at severity 1."""
    symptoms = [_symptom("syncope", severity=1, red_flag=True)]
    flags = evaluate_red_flags(symptoms)
    assert len(flags) == 1


def test_empty_symptom_list_returns_no_flags():
    assert evaluate_red_flags([]) == []


def test_mixed_list_only_qualifying_symptoms_flagged():
    symptoms = [
        _symptom("cough", severity=4, red_flag=False),
        _symptom("headache", severity=1, red_flag=True),  # below default threshold
        _symptom("chest_pain", severity=3, red_flag=True),  # above default threshold
    ]
    flags = evaluate_red_flags(symptoms)
    assert {f.code for f in flags} == {"chest_pain"}
