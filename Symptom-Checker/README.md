# ExperTIQ Healthcare Pro - Complete System Documentation

## Overview

ExperTIQ Healthcare Pro is a professional Arabic-first medical AI diagnostic platform featuring multi-page navigation, 100% Arabic localization, and professional PDF reporting with RTL support.

---

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
