from app.domain.entities.assessment import AssessmentInput, SelectedSymptom, Vitals
from app.domain.entities.red_flag import RedFlag
from app.domain.rules_engine.red_flag_rules import evaluate_red_flags
from app.domain.rules_engine.urgency_rules import determine_urgency


def _assessment(**kwargs) -> AssessmentInput:
    return AssessmentInput(**kwargs)


def test_critical_from_high_severity_red_flag():
    red_flags = [RedFlag(code="chest_pain", symptom_id="chest_pain", severity=3)]
    assessment = _assessment(symptoms=[SelectedSymptom(id="chest_pain", severity=3, red_flag=True)])
    assert determine_urgency(assessment, red_flags) == "critical"


def test_critical_from_vitals_alone_even_without_red_flags():
    assessment = _assessment(vitals=Vitals(systolic=190))
    assert determine_urgency(assessment, []) == "critical"


def test_high_from_low_severity_red_flag_present():
    red_flags = [RedFlag(code="syncope", symptom_id="syncope", severity=1)]
    assessment = _assessment(symptoms=[SelectedSymptom(id="syncope", severity=1, red_flag=True)])
    assert determine_urgency(assessment, red_flags) == "high"


def test_high_from_vitals_alone_no_red_flags():
    assessment = _assessment(vitals=Vitals(systolic=150))
    assert determine_urgency(assessment, []) == "high"


def test_moderate_from_two_symptoms_severity_two_or_more():
    assessment = _assessment(
        symptoms=[
            SelectedSymptom(id="headache", severity=2, red_flag=False),
            SelectedSymptom(id="dizziness", severity=3, red_flag=False),
        ]
    )
    assert determine_urgency(assessment, []) == "moderate"


def test_moderate_from_known_hypertension_plus_elevated_bp():
    assessment = _assessment(
        known_conditions=["Hypertension"],
        vitals=Vitals(systolic=132, diastolic=78),
    )
    assert determine_urgency(assessment, []) == "moderate"


def test_not_moderate_when_hypertension_known_but_bp_not_elevated():
    assessment = _assessment(known_conditions=["Hypertension"], vitals=Vitals(systolic=115, diastolic=75))
    assert determine_urgency(assessment, []) == "low"


def test_not_moderate_when_bp_elevated_but_no_known_hypertension():
    assessment = _assessment(vitals=Vitals(systolic=132, diastolic=78))
    assert determine_urgency(assessment, []) == "low"


def test_not_moderate_with_only_one_symptom_severity_two():
    assessment = _assessment(symptoms=[SelectedSymptom(id="headache", severity=2, red_flag=False)])
    assert determine_urgency(assessment, []) == "low"


def test_low_fallback_no_symptoms_no_vitals():
    assessment = _assessment()
    assert determine_urgency(assessment, []) == "low"


def test_low_fallback_mild_symptoms_only():
    assessment = _assessment(
        symptoms=[
            SelectedSymptom(id="cough", severity=1, red_flag=False),
            SelectedSymptom(id="runny_nose", severity=1, red_flag=False),
        ]
    )
    assert determine_urgency(assessment, []) == "low"


# --- End-to-end through evaluate_red_flags, matching plan §6 Phase 2 DoD scenarios ---


def test_e2e_chest_pain_and_shortness_of_breath_is_high():
    symptoms = [
        SelectedSymptom(id="chest_pain", severity=2, red_flag=True),
        SelectedSymptom(id="shortness_of_breath", severity=2, red_flag=True),
    ]
    assessment = _assessment(symptoms=symptoms)
    red_flags = evaluate_red_flags(symptoms)
    assert determine_urgency(assessment, red_flags) == "high"


def test_e2e_fainting_is_emergency():
    symptoms = [SelectedSymptom(id="syncope", severity=1, red_flag=True)]
    assessment = _assessment(symptoms=symptoms)
    red_flags = evaluate_red_flags(symptoms)
    assert determine_urgency(assessment, red_flags) == "high"


def test_e2e_stroke_symptoms_is_emergency():
    symptoms = [
        SelectedSymptom(id="sudden_numbness", severity=3, red_flag=True),
        SelectedSymptom(id="trouble_speaking", severity=3, red_flag=True),
        SelectedSymptom(id="loss_of_balance", severity=3, red_flag=True),
    ]
    assessment = _assessment(symptoms=symptoms)
    red_flags = evaluate_red_flags(symptoms)
    assert determine_urgency(assessment, red_flags) == "critical"
