"""
Splitsa ML Training Pipeline — train.py

Two models, both trained on the same feature set (ml/features/spec.py):

  Model 1 — Savings Predictor (XGBoost Regression)
    Input:  SpendFeatures (rolling averages, category shares, temporal features)
    Output: Recommended savings amount in paise
    Loss:   RMSE on surplus prediction
    Export: ONNX for on-device inference

  Model 2 — Persona Classifier (LightGBM Multi-class)
    Input:  SpendFeatures (weekend ratio, volatility, max/median ratio)
    Output: SpendPersona enum (weekend_spender, bulk_buyer, steady_spender)
    Loss:   Multi-class log-loss
    Export: ONNX for on-device inference

Algorithm choices:
  - XGBoost for regression: handles non-linear spend patterns, robust to
    outliers (bulk purchases), built-in L1/L2 regularization prevents
    overfitting on small datasets. Tree-based models capture the interaction
    between day-of-week and category spending naturally.
  - LightGBM for classification: faster training, lower memory footprint
    than XGBoost for multi-class, histogram-based splits handle the
    continuous features (ratios, volatility) well without manual binning.
  - Both export to ONNX: ~50KB models that run on-device via onnxruntime,
    no server round-trip needed (offline-first architecture).

Usage:
  cd e:/PROJECTS/SPLITSA
  python ml/generate_data.py   # generate synthetic training data
  python ml/train.py           # train both models + export ONNX
"""

import os
import json
import numpy as np
import pandas as pd
from datetime import datetime

from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import (
    mean_squared_error,
    mean_absolute_error,
    accuracy_score,
    classification_report,
    confusion_matrix,
)
from sklearn.preprocessing import LabelEncoder

import xgboost as xgb
import lightgbm as lgb

# ONNX export
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType
import onnxmltools
from onnxmltools.convert import convert_xgboost, convert_lightgbm


# ── Constants ────────────────────────────────────────────────────────────────

FEATURE_COLS = [
    'weekend_weekday_ratio',
    'spend_volatility_pct',
    'max_median_ratio',
    'surplus_paise',
    'txn_frequency',
    'total_spend_4w',
    'n_categories_used',
    'top_category_share',
]

PERSONA_LABELS = ['weekend_spender', 'bulk_buyer', 'steady_spender']
SAFETY_FRACTION = 0.70
NUDGE_FLOOR_PAISE = 20000  # ₹200

MODELS_DIR = 'ml/models'
DATA_DIR = 'ml/data'


def load_features() -> pd.DataFrame:
    """Load computed user features."""
    path = os.path.join(DATA_DIR, 'user_features.csv')
    if not os.path.exists(path):
        raise FileNotFoundError(
            f'{path} not found. Run `python ml/generate_data.py` first.'
        )
    return pd.read_csv(path)


# ── Model 1: Savings Predictor (XGBoost Regression) ─────────────────────────

def train_savings_model(df: pd.DataFrame) -> dict:
    """
    Train XGBoost regressor to predict how much surplus a user has.
    
    The target variable is `surplus_paise` — the difference between
    the user's rolling 4-week average and their last week's actual spend.
    A positive surplus means underspend → safe to nudge saving.
    
    The model learns to predict this surplus from behavioral features,
    which is more nuanced than the v1 logic engine's simple subtraction
    because it accounts for feature interactions (e.g., a weekend spender
    with high volatility might have a "surplus" that's actually just
    timing noise).
    """
    print('\n' + '=' * 60)
    print('MODEL 1: Savings Predictor (XGBoost Regression)')
    print('=' * 60)

    X = df[FEATURE_COLS].values.astype(np.float32)
    y = df['surplus_paise'].values.astype(np.float32)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    model = xgb.XGBRegressor(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_alpha=0.1,   # L1 regularization
        reg_lambda=1.0,  # L2 regularization
        random_state=42,
        verbosity=0,
    )

    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        verbose=False,
    )

    # Evaluate
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    mae = mean_absolute_error(y_test, y_pred)

    # Cross-validation
    cv_scores = cross_val_score(
        model, X, y, cv=5, scoring='neg_root_mean_squared_error'
    )

    print(f'  RMSE:     ₹{rmse / 100:.2f}')
    print(f'  MAE:      ₹{mae / 100:.2f}')
    print(f'  CV RMSE:  ₹{-cv_scores.mean() / 100:.2f} (±{cv_scores.std() / 100:.2f})')

    # Feature importance
    print('\n  Feature Importance:')
    importances = model.feature_importances_
    for feat, imp in sorted(zip(FEATURE_COLS, importances), key=lambda x: -x[1]):
        print(f'    {feat:30s} {imp:.4f}')

    # Export to ONNX
    os.makedirs(MODELS_DIR, exist_ok=True)
    onnx_model = convert_xgboost(
        model,
        initial_types=[('features', FloatTensorType([None, len(FEATURE_COLS)]))],
        target_opset=15,
    )
    onnx_path = os.path.join(MODELS_DIR, 'savings_predictor.onnx')
    onnxmltools.utils.save_model(onnx_model, onnx_path)
    model_size = os.path.getsize(onnx_path) / 1024
    print(f'\n  Exported: {onnx_path} ({model_size:.1f} KB)')

    return {
        'model': 'savings_predictor',
        'algorithm': 'XGBoost Regression',
        'rmse_paise': float(rmse),
        'mae_paise': float(mae),
        'cv_rmse_mean': float(-cv_scores.mean()),
        'n_estimators': 100,
        'max_depth': 4,
        'features': FEATURE_COLS,
        'onnx_path': onnx_path,
        'onnx_size_kb': round(model_size, 1),
        'trained_at': datetime.now().isoformat(),
    }


# ── Model 2: Persona Classifier (LightGBM) ──────────────────────────────────

def train_persona_model(df: pd.DataFrame) -> dict:
    """
    Train LightGBM multi-class classifier for spending persona.
    
    Personas (from PRODUCT_LOGIC.md §3):
      - weekend_spender: weekend/weekday ratio > 0.6
      - bulk_buyer: high volatility + large single transactions
      - steady_spender: default / consistent patterns
    
    LightGBM is chosen over XGBoost for classification because:
      1. Faster training with histogram-based splits
      2. Better handling of categorical features (not needed here but
         useful when we add sub-category features in v2)
      3. Lower memory footprint for on-device inference
    """
    print('\n' + '=' * 60)
    print('MODEL 2: Persona Classifier (LightGBM Multi-class)')
    print('=' * 60)

    le = LabelEncoder()
    le.fit(PERSONA_LABELS)

    X = df[FEATURE_COLS].values.astype(np.float32)
    y = le.transform(df['persona'].values)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = lgb.LGBMClassifier(
        n_estimators=80,
        max_depth=3,
        learning_rate=0.1,
        num_leaves=8,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_alpha=0.1,
        reg_lambda=1.0,
        class_weight='balanced',
        random_state=42,
        verbose=-1,
    )

    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
    )

    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)

    print(f'  Accuracy: {accuracy:.4f}')
    print(f'\n  Classification Report:')
    print(classification_report(
        y_test, y_pred,
        target_names=PERSONA_LABELS,
        digits=3,
    ))

    # Cross-validation
    cv_scores = cross_val_score(model, X, y, cv=5, scoring='accuracy')
    print(f'  CV Accuracy: {cv_scores.mean():.4f} (±{cv_scores.std():.4f})')

    # Feature importance
    print('\n  Feature Importance:')
    importances = model.feature_importances_
    for feat, imp in sorted(zip(FEATURE_COLS, importances), key=lambda x: -x[1]):
        print(f'    {feat:30s} {imp}')

    # Export to ONNX
    onnx_model = convert_lightgbm(
        model,
        initial_types=[('features', FloatTensorType([None, len(FEATURE_COLS)]))],
        target_opset=15,
    )
    onnx_path = os.path.join(MODELS_DIR, 'persona_classifier.onnx')
    onnxmltools.utils.save_model(onnx_model, onnx_path)
    model_size = os.path.getsize(onnx_path) / 1024
    print(f'\n  Exported: {onnx_path} ({model_size:.1f} KB)')

    return {
        'model': 'persona_classifier',
        'algorithm': 'LightGBM Multi-class',
        'accuracy': float(accuracy),
        'cv_accuracy_mean': float(cv_scores.mean()),
        'n_estimators': 80,
        'max_depth': 3,
        'num_leaves': 8,
        'classes': PERSONA_LABELS,
        'features': FEATURE_COLS,
        'onnx_path': onnx_path,
        'onnx_size_kb': round(model_size, 1),
        'trained_at': datetime.now().isoformat(),
    }


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    print('Splitsa ML Training Pipeline')
    print('─' * 40)

    df = load_features()
    print(f'Loaded {len(df)} user feature vectors')
    print(f'Persona distribution:')
    for persona, count in df['persona'].value_counts().items():
        print(f'  {persona}: {count}')

    results = []
    results.append(train_savings_model(df))
    results.append(train_persona_model(df))

    # Save training metadata
    meta_path = os.path.join(MODELS_DIR, 'training_metadata.json')
    with open(meta_path, 'w') as f:
        json.dump(results, f, indent=2)
    print(f'\nTraining metadata saved to {meta_path}')
    print('\n✓ Pipeline complete.')


if __name__ == '__main__':
    main()
