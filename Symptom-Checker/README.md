# ExperTIQ Healthcare Pro - Complete System Documentation

## Overview

ExperTIQ Healthcare Pro is a professional Arabic-first medical AI diagnostic platform featuring multi-page navigation, 100% Arabic localization, and professional PDF reporting with RTL support.

**⚠️ Status note (2026-07-01):** everything below this line documents the **v1 system**
(`app.py`, `train_model.py`/`Disease_Prediction_Model.ipynb`, `best_model.pkl`, the
`Data/General`/`Data/Heart` `.js`/`.json` files) — this is still what `Back-end/app/services/ai_service.py`
loads and serves in production today, and none of it has been deleted or modified. A parallel
**v2 pipeline** now exists alongside it (see the section immediately below) and is what the
new `Back-end/app/api/v1/ai.py` structured-assessment endpoints (`/categories`,
`/taxonomy/symptoms`, `/assessment`, `/bp-triage`, `/chat/from-assessment`) actually run on.
Full rationale and phase-by-phase execution log: `Plans/SYMPTOM_CHECKER_IMPLEMENTATION_PLAN.md`
and `Plans/SYMPTOM_CHECKER_PROGRESS.md` at the repo root.

---

## v2 Pipeline (new — Phases 1-4 of the implementation plan)

Replaces the v1 model architecture (`CountVectorizer` + `MLPClassifier` over a space-joined
symptom string, no severity/duration/vitals input) with a structured, ID-based taxonomy and a
LightGBM classifier that accepts severity/duration/age/risk-factors/vitals. The v1 model stays
in place as the production fallback until this is validated and rolled out (plan §12).

```
Symptom-Checker/
├── migration/
│   ├── migrate_legacy_taxonomy.py   # Phase 1 — reads Data/General, Data/Heart; outputs taxonomy/
│   └── migration_report.md          # dedup log, category mapping, orphan-symptom log
├── taxonomy/                        # Phase 1 output — stable-ID schema (see data_pipeline/schema.py)
│   ├── categories.json              # 9 fixed categories
│   ├── symptoms.json                # 108 entries (49 directly migrated + 59 orphan stubs — see migration_report.md)
│   └── diseases.json                # 41 entries, same disease set as v1
├── data_pipeline/
│   ├── schema.py                    # Pydantic models: Category, Symptom, Disease, TrainingCase
│   ├── constants.py                 # RISK_FACTOR_POOL — shared by dataset generation and feature engineering
│   ├── generate_structured_cases.py # Phase 3 — synthetic case generation from the taxonomy
│   └── validate_dataset.py          # Phase 3 — schema + class-balance validation
├── Data/cases/
│   ├── dataset.jsonl                # Phase 3 output — 12,300 structured training cases
│   └── dataset_report.md            # balance report + flagged limitations (see below)
├── training/
│   ├── feature_engineering.py       # single build_features() — imported by both training AND
│   │                                 # Back-end/app/infrastructure/ml/structured_feature_builder.py
│   ├── train_baseline.py            # LogisticRegression + RandomForest, comparison only
│   ├── train_final.py               # LightGBM — the actual candidate, top-3 confidence
│   └── evaluate.py                  # confusion matrix + confusable-pair report
└── Output/Production/
    ├── best_model.pkl, vectorizer.pkl, model_metadata.json   # v1 — untouched
    └── best_model_v2.pkl, label_encoder_v2.pkl,              # v2 — new, does not overwrite v1
        model_metadata_v2.json, baseline_comparison.json, evaluation_report_v2.md
```

### Running the v2 pipeline end to end

```bash
cd Symptom-Checker
python migration/migrate_legacy_taxonomy.py       # Phase 1 — only needed if Data/General|Heart change
python data_pipeline/generate_structured_cases.py  # Phase 3 — regenerate the synthetic dataset
python data_pipeline/validate_dataset.py           # must print PASS before training
python training/train_baseline.py                  # comparison baseline
python training/train_final.py                     # trains + saves best_model_v2.pkl
python training/evaluate.py                         # confusion matrix + confusable-pair report
```

Requires `scikit-learn>=1.9.0` and `lightgbm>=4.6.0` (see the inline note in
`requirements.txt` — these are bumped from the original `>=1.7.2` pin specifically because
`lightgbm<4.6.0` calls a `scikit-learn` API argument that `>=1.7` removed).
**`Back-end/requirements.txt` must stay on the same `scikit-learn` version** or the backend
can't unpickle `best_model_v2.pkl` — this has been kept in sync as of this writing.

### Known limitations (flagged, not hidden — full detail in `Plans/SYMPTOM_CHECKER_PROGRESS.md`)

- 59 of the 108 migrated symptoms are "orphan stubs" (referenced by a disease's related-symptom
  list but never defined as their own entry in the original `.json` files) — they have no
  `name_ar`/description yet and need a human review pass before Phase 3-generated data that
  uses them is treated as clinically final.
- The risk-factor vocabulary (`data_pipeline/constants.RISK_FACTOR_POOL`) isn't sourced from
  any taxonomy file — none exists. It's a small pool of already-migrated chronic disease ids
  reused as risk-factor tokens, following the plan's own two worked examples.
- The synthetic dataset's urgency labels skew high for ~18 heart-disease classes whose related
  symptoms happen to include a red-flag symptom (e.g. chest pain) — see
  `Data/cases/dataset_report.md` for the full per-disease breakdown.
- Top-1 accuracy is 85.8%, top-3 is 95.5% on a held-out split (`Output/Production/evaluation_report_v2.md`).
  The confusable respiratory triad (Common Cold/Influenza/COVID-19) and Hypertension vs.
  Migraine/Stroke show zero cross-confusion; the weakest classes are a cluster of clinically
  similar heart diseases (myocarditis, hypertrophic cardiomyopathy, coronary artery disease...)
  that share almost identical symptom profiles in the taxonomy.

---

## v1 System (original — still in production via `ai_service.py`)

## Installation

### Prerequisites

```bash
# Install required Python packages
pip install streamlit joblib numpy pandas scikit-learn
pip install fpdf2 arabic-reshaper python-bidi
```

### Required Files Structure

```
Graduation_Project/
├── app.py                          # Main Streamlit application
├── Disease_Prediction_Model.ipynb   # Advanced Jupyter training pipeline
├── best_model.pkl                  # Standard MLP Model (Production)
├── vectorizer.pkl                  # TF-IDF Vectorizer
├── model_metadata.json             # System Metadata (Categories/Translations)
├── Data/
│   ├── Heart/
│   │   ├── HeartDiseases.js       # Heart disease database with Arabic
│   │   └── HeartSymptoms.js       # Heart symptom database with Arabic
│   └── General/
│       ├── GeneralDiseases.js     # General disease database with Arabic
│       └── GeneralSymptoms.js     # General symptom database with Arabic
└── Output/                         # Training logs and reports
```

---

## Running the Application

### Start the Streamlit App

```bash
streamlit run app.py
```

The app will open at: `http://localhost:8501`

### If Port is Already in Use

```powershell
# Kill existing Streamlit processes
Get-Process -Name streamlit -ErrorAction SilentlyContinue | Stop-Process -Force

# Then run again
streamlit run app.py
```

---

## Features

### 1. **100% Arabic Localization** ✅

- **Language Selection**: Choose between English 🇺🇸 and Arabic 🇪🇬
- **Arabic Sub-Categories**: "تدقيق سياق التخصص" displays all medical specialties in Arabic
- **Arabic Symptoms**: "حدد جميع العلامات الحيوية المكتشفة" shows symptoms in Arabic
- **Arabic Report**: "تقرير الحالة الصحي" with full localization

### 2. **Dynamic Context Filtering** ✅

- Symptom choices update automatically based on selected medical specialty
- Prevents cross-category symptom leakage
- Ensures clinical accuracy

### 3. **Professional PDF Export** ✅

- **RTL Support**: Proper right-to-left rendering for Arabic text
- **Bilingual**: Adapts to selected language (English/Arabic)
- **Clinical Template**: Professional header/footer with branding
- **One-Click Download**: Generates PDF in real-time

### 4. **4-Page Diagnostic Flow** ✅

1. **Language Selection** (اللغة)
2. **Specialty Selection** (التخصص) - Heart & Vascular or General Medicine
3. **Symptom Selection** (الأعراض) - Dynamic multi-select
4. **Analysis & Report** (التحليل) - Results with PDF download

---

## Training a New Model

### Run the Training Pipeline

```bash
python train_model.py
```

### Training Process

The `train_model.py` script performs:

1. **Data Preparation**: Comprehensive loading of medical datasets
2. **Feature Engineering**: Advanced TF-IDF vectorization with n-grams
3. **Model Benchmarking**: Automated tournament testing 11 architectures:
   - **Standard MLP (Winner: 90.3%)**
   - Deep Neural Networks
   - Random Forest (Ensemble)
   - Extra Trees / Gradient Boosting
   - Logistic Regression / SVM
4. **Validation**: Weighted F1-Score analysis (>90.4%)
5. **Deployment**: Automatic export of the winning "Champion" model

### Expected Output

```
✓ Dataset: 10,250+ cases
✓ F1-Score: 0.9044
🏆 BEST MODEL: Standard MLP (Neural)
```

---

## Arabic Translation System

### How It Works

The app uses a **deep parsing engine** to extract Arabic translations from your JavaScript medical databases:

```python
def parse_expert_js(file_path):
    # Extracts nameAr, descriptionAr, severity, category
    # from HeartDiseases.js, HeartSymptoms.js, etc.
```

### Translation Coverage

- **Diseases**: Pulled from `nameAr` field
- **Symptoms**: Pulled from `nameAr` field
- **Descriptions/Advice**: Pulled from `descriptionAr` field
- **Categories**: Translated via dictionary mapping

### Example JS Structure

```javascript
"Common Cold": {
  nameAr: "الزكام",
  description: "Viral infection of nose and throat",
  descriptionAr: "عدوى فيروسية في الأنف والحلق",
  severity: "low",
  category: "Respiratory Infection"
}
```

---

## Troubleshooting

### Issue: "Port 8501 is already in use"

**Solution**:

```powershell
# Kill all Streamlit processes
Get-Process -Name streamlit | Stop-Process -Force

# Run app again
streamlit run app.py
```

### Issue: "Arabic text not displaying correctly"

**Solution**:

- Ensure `fpdf2`, `arabic-reshaper`, and `python-bidi` are installed
- Windows fonts should include `arial.ttf` for Unicode support
- Check that JS files have proper UTF-8 encoding

### Issue: "Model not found"

**Solution**:

```bash
# Train the model first
python train_model.py

# Then run the app
streamlit run app.py
```

### Issue: "Symptoms not updating when changing specialty"

**Solution**:

- This is fixed in v5.0 with dynamic filtering
- Make sure you're using the latest `app.py`
- The `meta['categories']` dictionary maps specialties to symptoms

---

## Technical Architecture

### Frontend

- **Framework**: Streamlit
- **Styling**: Custom CSS with glassmorphism
- **Fonts**: Outfit (English) + Noto Sans Arabic

### Backend

- **ML Framework**: scikit-learn
- **Vectorization**: TF-IDF with n-grams
- **Models**: Ensemble approach with 5 classifiers

### PDF Generation

- **Library**: fpdf2
- **RTL Processing**: arabic-reshaper + python-bidi
- **Font**: DejaVu (Unicode support)

### Data Pipeline

- **Source**: JavaScript medical databases
- **Parsing**: Regex-based extraction
- **Storage**: JSON metadata + pickled models

---

## Performance Metrics

- **Best Model**: Standard MLP (Neural Network)
- **Accuracy**: 90.3%
- **Weighted F1-Score**: 90.4%
- **Training Dataset**: 10,250+ cases

---

## File Descriptions

| File                  | Purpose                                     |
| --------------------- | ------------------------------------------- |
| `app.py`              | Main Streamlit application with 4-page flow |
| `train_model.py`      | Complete ML training pipeline               |
| `HeartDiseases.js`    | Heart disease database (English + Arabic)   |
| `HeartSymptoms.js`    | Heart symptom database (English + Arabic)   |
| `GeneralDiseases.js`  | General disease database (English + Arabic) |
| `GeneralSymptoms.js`  | General symptom database (English + Arabic) |
| `best_model.pkl`      | Trained classifier (auto-generated)         |
| `vectorizer.pkl`      | TF-IDF vectorizer (auto-generated)          |
| `model_metadata.json` | System metadata (auto-generated)            |

---

## Quick Start Guide

1. **Install dependencies**:

   ```bash
   pip install streamlit joblib numpy pandas scikit-learn fpdf2 arabic-reshaper python-bidi
   ```

2. **Train the model** (if not already trained):

   ```bash
   python train_model.py
   ```

3. **Run the app**:

   ```bash
   streamlit run app.py
   ```

4. **Test Arabic flow**:
   - Click "العربية 🇪🇬"
   - Select specialty: "القلب والأوعية الدموية"
   - Choose sub-category in Arabic
   - Select symptoms in Arabic
   - View "تقرير الحالة الصحي"
   - Download Arabic PDF

---

## Support

For issues or questions:

- Check the JS files have proper `nameAr` and `descriptionAr` fields
- Verify all dependencies are installed
- Ensure UTF-8 encoding for Arabic support
- Check terminal output for specific error messages

**Version**: 5.0  
**Last Updated**: 2025-12-29
