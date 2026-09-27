"""
Splitsa ML — Model evaluation and analysis.

Loads trained ONNX models and runs comprehensive evaluation:
  - Prediction accuracy on held-out test data
  - Feature importance visualization
  - Persona confusion matrix heatmap
  - Savings prediction error distribution

Usage:
  python ml/evaluate.py
"""

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    confusion_matrix,
    classification_report,
    mean_squared_error,
    mean_absolute_error,
)
from sklearn.preprocessing import LabelEncoder
import onnxruntime as ort


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
MODELS_DIR = 'ml/models'
DATA_DIR = 'ml/data'
PLOTS_DIR = 'ml/plots'


def evaluate_savings_model(df: pd.DataFrame):
    """Evaluate savings predictor ONNX model."""
    print('\n' + '=' * 60)
    print('EVALUATING: Savings Predictor')
    print('=' * 60)

    onnx_path = os.path.join(MODELS_DIR, 'savings_predictor.onnx')
    if not os.path.exists(onnx_path):
        print('  ⚠ Model not found. Run train.py first.')
        return

    session = ort.InferenceSession(onnx_path)
    X = df[FEATURE_COLS].values.astype(np.float32)
    y = df['surplus_paise'].values

    _, X_test, _, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    y_pred = session.run(None, {'features': X_test})[0].flatten()

    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    mae = mean_absolute_error(y_test, y_pred)
    print(f'  ONNX RMSE: ₹{rmse / 100:.2f}')
    print(f'  ONNX MAE:  ₹{mae / 100:.2f}')

    # Error distribution plot
    os.makedirs(PLOTS_DIR, exist_ok=True)
    errors = (y_pred - y_test) / 100  # to rupees

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.hist(errors, bins=40, color='#f2a73b', alpha=0.8, edgecolor='white')
    ax.axvline(0, color='#2f9e8f', linewidth=2, linestyle='--', label='Perfect prediction')
    ax.set_xlabel('Prediction Error (₹)')
    ax.set_ylabel('Count')
    ax.set_title('Savings Predictor — Error Distribution')
    ax.legend()
    plt.tight_layout()
    plt.savefig(os.path.join(PLOTS_DIR, 'savings_error_dist.png'), dpi=150)
    plt.close()
    print(f'  Plot saved: {PLOTS_DIR}/savings_error_dist.png')


def evaluate_persona_model(df: pd.DataFrame):
    """Evaluate persona classifier ONNX model."""
    print('\n' + '=' * 60)
    print('EVALUATING: Persona Classifier')
    print('=' * 60)

    onnx_path = os.path.join(MODELS_DIR, 'persona_classifier.onnx')
    if not os.path.exists(onnx_path):
        print('  ⚠ Model not found. Run train.py first.')
        return

    le = LabelEncoder()
    le.fit(PERSONA_LABELS)

    session = ort.InferenceSession(onnx_path)
    X = df[FEATURE_COLS].values.astype(np.float32)
    y = le.transform(df['persona'].values)

    _, X_test, _, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    y_pred = session.run(None, {'features': X_test})[0].flatten()

    print(classification_report(y_test, y_pred, target_names=PERSONA_LABELS, digits=3))

    # Confusion matrix
    cm = confusion_matrix(y_test, y_pred)
    fig, ax = plt.subplots(figsize=(7, 6))
    sns.heatmap(
        cm, annot=True, fmt='d', cmap='YlOrBr',
        xticklabels=PERSONA_LABELS, yticklabels=PERSONA_LABELS, ax=ax,
    )
    ax.set_xlabel('Predicted')
    ax.set_ylabel('Actual')
    ax.set_title('Persona Classifier — Confusion Matrix')
    plt.tight_layout()
    plt.savefig(os.path.join(PLOTS_DIR, 'persona_confusion.png'), dpi=150)
    plt.close()
    print(f'  Plot saved: {PLOTS_DIR}/persona_confusion.png')


def main():
    df = pd.read_csv(os.path.join(DATA_DIR, 'user_features.csv'))
    print(f'Loaded {len(df)} user feature vectors')

    evaluate_savings_model(df)
    evaluate_persona_model(df)

    print('\n✓ Evaluation complete. Plots saved to ml/plots/.')


if __name__ == '__main__':
    main()
