# Evaluation Report (Phase 4)

**Baseline caveat (plan §1.4/§8, restated per DoD requirement):** the old notebook's reported 0.9034 accuracy (Standard MLP, `CountVectorizer`) was measured on the same random-subset synthetic dataset it was trained on (narrow symptom-combination space, no severity/duration/vitals input) — it is not a fair baseline and should never be quoted as a real-world number. The metrics below are measured on a stratified 80/20 held-out split of the new structured dataset instead.

- Top-1 accuracy: **0.8581**
- Top-3 accuracy: **0.9549**

## Confusable-pair confusion table

### common_cold vs influenza vs covid_19

| true \ pred | common_cold | influenza | covid_19 |
|---|---|---|---|
| common_cold | 60 | 0 | 0 |
| influenza | 0 | 56 | 0 |
| covid_19 | 0 | 0 | 56 |

### hypertension vs migraine

| true \ pred | hypertension | migraine |
|---|---|---|
| hypertension | 59 | 0 |
| migraine | 0 | 59 |

### hypertension vs stroke

| true \ pred | hypertension | stroke |
|---|---|---|
| hypertension | 59 | 0 |
| stroke | 0 | 60 |

## 10 worst-performing classes (top-1 accuracy)

- `myocarditis`: 0.350
- `hypertrophic_cardiomyopathy`: 0.400
- `coronary_artery_disease`: 0.517
- `congestive_heart_failure`: 0.600
- `pericarditis`: 0.600
- `ventricular_tachycardia`: 0.650
- `heart_failure`: 0.683
- `pulmonary_hypertension`: 0.683
- `stable_angina`: 0.700
- `aortic_stenosis`: 0.750