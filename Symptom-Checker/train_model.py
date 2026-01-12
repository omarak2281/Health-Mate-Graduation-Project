"""
ExperTIQ Pro - Expert Disease Prediction Model Training Pipeline
================================================================

This script demonstrates the complete training process for the expert medical
diagnostic system, including data preparation, feature engineering, model selection,
and production deployment.

Author: ExperTIQ Medical AI Team
Version: 5.0
Date: 2025-12-29
"""

import pandas as pd
import numpy as np
import joblib
import json
import os
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.naive_bayes import MultinomialNB
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, accuracy_score, f1_score
from datetime import datetime

# ==========================================
# CONFIGURATION
# ==========================================
class Config:
    """Central configuration for the expert system"""
    
    # Paths
    DATA_DIR = "Data"
    OUTPUT_DIR = os.path.join("Output", "Production")
    
    # Model Parameters
    TEST_SIZE = 0.2
    RANDOM_STATE = 42
    CV_FOLDS = 5
    
    # TF-IDF Parameters
    MAX_FEATURES = 5000
    MIN_DF = 2
    MAX_DF = 0.8
    NGRAM_RANGE = (1, 3)
    
    # Categories
    HEART_CATEGORIES = [
        "Coronary Artery Disease", "Heart Failure", "Valvular Heart Disease",
        "Cardiomyopathy", "Arrhythmia", "Inflammatory Heart Disease", "Vascular Disease"
    ]
    
    GENERAL_CATEGORIES = [
        "Respiratory Infection", "Chronic Respiratory", "Gastrointestinal",
        "Metabolic", "Endocrine", "Musculoskeletal", "Neurological",
        "Psychiatric", "Dermatological", "Infectious Disease",
        "Hematological", "Liver Disease", "Renal"
    ]

# ==========================================
# STEP 1: DATA PREPARATION
# ==========================================
def load_and_prepare_data():
    """
    Load medical training data from CSV files and prepare for expert system.
    
    Returns:
        pd.DataFrame: Combined dataset with symptoms and disease labels
    """
    print("=" * 80)
    print("STEP 1: DATA PREPARATION")
    print("=" * 80)
    
    # Load datasets
    heart_data = pd.read_json(os.path.join(Config.DATA_DIR, "Heart", "heart_training_data.json"))
    general_data = pd.read_json(os.path.join(Config.DATA_DIR, "General", "general_training_data.json"))
    
    # Combine datasets
    combined_data = pd.concat([heart_data, general_data], ignore_index=True)
    
    print(f"✓ Loaded {len(heart_data):,} heart disease records")
    print(f"✓ Loaded {len(general_data):,} general disease records")
    print(f"✓ Total training samples: {len(combined_data):,}")
    print(f"✓ Unique diseases: {combined_data['disease'].nunique()}")
    print(f"✓ Feature columns: {combined_data.columns.tolist()[:5]}...")
    
    return combined_data

# ==========================================
# STEP 2: FEATURE ENGINEERING
# ==========================================
def create_symptom_text(data):
    """
    Convert symptom columns into text representation for TF-IDF vectorization.
    
    Args:
        data (pd.DataFrame): Raw medical data
        
    Returns:
        pd.Series: Text representation of symptoms
    """
    print("\n" + "=" * 80)
    print("STEP 2: FEATURE ENGINEERING")
    print("=" * 80)
    
    # Create symptom text by joining all symptom columns
    symptom_cols = [col for col in data.columns if col != 'disease']
    
    symptom_texts = []
    for idx, row in data.iterrows():
        # Only include symptoms that are present (value = 1)
        active_symptoms = [col for col in symptom_cols if row[col] == 1]
        symptom_texts.append(" ".join(active_symptoms))
    
    print(f"✓ Extracted {len(symptom_cols)} potential symptom features")
    print(f"✓ Average symptoms per case: {np.mean([len(text.split()) for text in symptom_texts]):.2f}")
    print(f"✓ Sample symptom text: {symptom_texts[0][:100]}...")
    
    return pd.Series(symptom_texts, index=data.index)

def build_tfidf_vectorizer(symptom_texts):
    """
    Build and fit TF-IDF vectorizer for symptom text.
    
    Args:
        symptom_texts (pd.Series): Text representation of symptoms
        
    Returns:
        TfidfVectorizer: Fitted vectorizer
    """
    vectorizer = TfidfVectorizer(
        max_features=Config.MAX_FEATURES,
        min_df=Config.MIN_DF,
        max_df=Config.MAX_DF,
        ngram_range=Config.NGRAM_RANGE,
        token_pattern=r'\b\w+\b'
    )
    
    vectorizer.fit(symptom_texts)
    
    print(f"✓ Built TF-IDF vectorizer with {len(vectorizer.vocabulary_):,} features")
    print(f"✓ N-gram range: {Config.NGRAM_RANGE}")
    
    return vectorizer

# ==========================================
# STEP 3: MODEL TRAINING & SELECTION
# ==========================================
def train_expert_models(X_train, y_train, X_test, y_test):
    """
    Train multiple expert models and select the best performer.
    
    Args:
        X_train, y_train: Training data
        X_test, y_test: Testing data
        
    Returns:
        tuple: (best_model, performance_metrics)
    """
    print("\n" + "=" * 80)
    print("STEP 3: EXPERT MODEL TRAINING")
    print("=" * 80)
    
    models = {
        "Random Forest": RandomForestClassifier(n_estimators=200, max_depth=20, random_state=Config.RANDOM_STATE, n_jobs=-1),
        "Gradient Boosting": GradientBoostingClassifier(n_estimators=100, max_depth=10, random_state=Config.RANDOM_STATE),
        "SVM (Linear)": SVC(kernel='linear', probability=True, random_state=Config.RANDOM_STATE),
        "Logistic Regression": LogisticRegression(max_iter=1000, multi_class='multinomial', random_state=Config.RANDOM_STATE),
        "Naive Bayes": MultinomialNB(alpha=0.1)
    }
    
    results = {}
    
    for name, model in models.items():
        print(f"\n→ Training {name}...")
        
        # Train
        model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        f1 = f1_score(y_test, y_pred, average='weighted')
        
        # Cross-validation
        cv_scores = cross_val_score(model, X_train, y_train, cv=Config.CV_FOLDS, scoring='accuracy')
        
        results[name] = {
            'model': model,
            'accuracy': accuracy,
            'f1_score': f1,
            'cv_mean': cv_scores.mean(),
            'cv_std': cv_scores.std()
        }
        
        print(f"  ✓ Test Accuracy: {accuracy:.4f}")
        print(f"  ✓ F1-Score: {f1:.4f}")
        print(f"  ✓ CV Accuracy: {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")
    
    # Select best model
    best_name = max(results, key=lambda x: results[x]['accuracy'])
    best_model = results[best_name]['model']
    
    print("\n" + "=" * 80)
    print(f"🏆 BEST MODEL: {best_name}")
    print(f"   Accuracy: {results[best_name]['accuracy']:.4f}")
    print(f"   F1-Score: {results[best_name]['f1_score']:.4f}")
    print("=" * 80)
    
    return best_model, results

# ==========================================
# STEP 4: METADATA GENERATION
# ==========================================
def generate_metadata(data, vectorizer):
    """
    Generate comprehensive metadata for the expert system.
    
    Args:
        data (pd.DataFrame): Training data
        vectorizer: Fitted TF-IDF vectorizer
        
    Returns:
        dict: Metadata dictionary
    """
    print("\n" + "=" * 80)
    print("STEP 4: METADATA GENERATION")
    print("=" * 80)
    
    # Get all symptoms
    all_symptoms = [col for col in data.columns if col != 'disease']
    
    # Create category mappings
    categories = {}
    for cat in Config.HEART_CATEGORIES + Config.GENERAL_CATEGORIES:
        # This is a simplified mapping - in reality, you'd load from your JS files
        categories[cat] = [s for s in all_symptoms if s in data.columns]
    
    metadata = {
        'model_type': 'Disease Prediction Expert System',
        'version': '5.0',
        'training_date': datetime.now().isoformat(),
        'total_diseases': data['disease'].nunique(),
        'total_symptoms': len(all_symptoms),
        'feature_count': len(vectorizer.vocabulary_),
        'categories': categories,
        'disease_list': data['disease'].unique().tolist(),
        'symptom_list': all_symptoms,
        'symptom_translations': {},  # Populated from JS files
        'disease_translations': {}   # Populated from JS files
    }
    
    print(f"✓ Generated metadata with {len(categories)} clinical categories")
    print(f"✓ Tracked {len(all_symptoms)} total symptoms")
    print(f"✓ Documented {metadata['total_diseases']} unique diseases")
    
    return metadata

# ==========================================
# STEP 5: PRODUCTION DEPLOYMENT
# ==========================================
def deploy_to_production(model, vectorizer, metadata):
    """
    Deploy the trained expert system to production.
    
    Args:
        model: Trained classifier
        vectorizer: Fitted TF-IDF vectorizer
        metadata: System metadata
    """
    print("\n" + "=" * 80)
    print("STEP 5: PRODUCTION DEPLOYMENT")
    print("=" * 80)
    
    # Create output directory
    os.makedirs(Config.OUTPUT_DIR, exist_ok=True)
    
    # Save model
    model_path = os.path.join(Config.OUTPUT_DIR, 'best_model.pkl')
    joblib.dump(model, model_path)
    print(f"✓ Saved model to: {model_path}")
    
    # Save vectorizer
    vec_path = os.path.join(Config.OUTPUT_DIR, 'vectorizer.pkl')
    joblib.dump(vectorizer, vec_path)
    print(f"✓ Saved vectorizer to: {vec_path}")
    
    # Save metadata
    meta_path = os.path.join(Config.OUTPUT_DIR, 'model_metadata.json')
    with open(meta_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    print(f"✓ Saved metadata to: {meta_path}")
    
    print("\n" + "=" * 80)
    print("✅ EXPERT SYSTEM DEPLOYMENT COMPLETE")
    print("=" * 80)
    print(f"\nProduction files ready in: {Config.OUTPUT_DIR}")
    print("You can now run: streamlit run app.py")

# ==========================================
# MAIN TRAINING PIPELINE
# ==========================================
def main():
    """Execute the complete expert system training pipeline."""
    
    print("\n")
    print("╔" + "=" * 78 + "╗")
    print("║" + " " * 20 + "ExperTIQ Pro - Expert Training Pipeline" + " " * 18 + "║")
    print("║" + " " * 25 + "Medical AI Diagnostic System" + " " * 25 + "║")
    print("╚" + "=" * 78 + "╝")
    print("\n")
    
    # Step 1: Load Data
    data = load_and_prepare_data()
    
    # Step 2: Feature Engineering
    symptom_texts = create_symptom_text(data)
    vectorizer = build_tfidf_vectorizer(symptom_texts)
    
    # Transform to TF-IDF features
    X = vectorizer.transform(symptom_texts)
    y = data['disease']
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, 
        test_size=Config.TEST_SIZE, 
        random_state=Config.RANDOM_STATE,
        stratify=y
    )
    
    print(f"\n✓ Train set: {X_train.shape[0]:,} samples")
    print(f"✓ Test set: {X_test.shape[0]:,} samples")
    
    # Step 3: Train Models
    best_model, results = train_expert_models(X_train, y_train, X_test, y_test)
    
    # Step 4: Generate Metadata
    metadata = generate_metadata(data, vectorizer)
    
    # Step 5: Deploy
    deploy_to_production(best_model, vectorizer, metadata)
    
    print("\n🎉 Training pipeline completed successfully!\n")

if __name__ == "__main__":
    main()
