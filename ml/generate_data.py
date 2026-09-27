"""
Splitsa — Synthetic data generator for ML training.

Generates realistic expense data that mimics real user spending patterns.
Each synthetic user is assigned a persona (Weekend Spender, Bulk Buyer,
Steady Spender) and their transactions are sampled from persona-specific
distributions.

Output: ml/data/synthetic_train.csv — used by ml/train.py.
"""

import os
import random
from datetime import datetime, timedelta
import numpy as np
import pandas as pd

# ── Persona distributions ────────────────────────────────────────────────────

CATEGORIES = ['food', 'travel', 'home', 'entertainment', 'shopping', 'health']
FIXED_CATEGORIES = {'rent', 'electricity', 'wifi', 'subscriptions', 'gas'}

PERSONA_CONFIGS = {
    'weekend_spender': {
        'weekend_multiplier': 2.5,   # spends 2.5x more on weekends
        'weekday_base': (200, 800),  # paise range per txn
        'weekend_base': (500, 3000),
        'txns_per_week': (8, 15),
        'category_weights': [0.35, 0.15, 0.10, 0.25, 0.10, 0.05],
    },
    'bulk_buyer': {
        'weekend_multiplier': 1.1,
        'weekday_base': (150, 600),
        'weekend_base': (200, 800),
        'txns_per_week': (4, 8),
        'bulk_probability': 0.15,    # 15% chance of a "bulk" transaction
        'bulk_multiplier': (5, 15),  # bulk txns are 5-15x normal
        'category_weights': [0.25, 0.10, 0.15, 0.10, 0.30, 0.10],
    },
    'steady_spender': {
        'weekend_multiplier': 1.0,
        'weekday_base': (300, 1000),
        'weekend_base': (300, 1000),
        'txns_per_week': (10, 18),
        'category_weights': [0.30, 0.15, 0.15, 0.15, 0.15, 0.10],
    },
}


def generate_user_transactions(
    user_id: str,
    persona: str,
    n_weeks: int = 8,
    seed: int | None = None,
) -> pd.DataFrame:
    """Generate synthetic transactions for a single user."""
    rng = np.random.default_rng(seed)
    config = PERSONA_CONFIGS[persona]

    records = []
    base_date = datetime.now() - timedelta(weeks=n_weeks)

    for week in range(n_weeks):
        n_txns = rng.integers(*config['txns_per_week'])

        for _ in range(n_txns):
            day_offset = rng.integers(0, 7)
            txn_date = base_date + timedelta(weeks=week, days=int(day_offset))
            is_weekend = txn_date.weekday() >= 5

            # Base amount
            if is_weekend:
                lo, hi = config['weekend_base']
            else:
                lo, hi = config['weekday_base']

            amount = int(rng.integers(lo, hi))

            # Bulk buyer spike
            if persona == 'bulk_buyer' and rng.random() < config.get('bulk_probability', 0):
                mult_lo, mult_hi = config['bulk_multiplier']
                amount = int(amount * rng.integers(mult_lo, mult_hi))

            # Category
            cat_idx = rng.choice(len(CATEGORIES), p=config['category_weights'])
            category = CATEGORIES[cat_idx]

            records.append({
                'user_id': user_id,
                'persona': persona,
                'category': category,
                'amount_paise': amount * 100,  # convert to paise
                'day_of_week': txn_date.weekday(),
                'is_weekend': int(is_weekend),
                'created_at': txn_date.isoformat(),
                'week_index': week,
            })

    return pd.DataFrame(records)


def generate_dataset(n_users_per_persona: int = 200, n_weeks: int = 8) -> pd.DataFrame:
    """Generate a full synthetic dataset."""
    all_frames = []
    user_counter = 0

    for persona in PERSONA_CONFIGS:
        for i in range(n_users_per_persona):
            user_id = f'user_{user_counter:04d}'
            df = generate_user_transactions(
                user_id=user_id,
                persona=persona,
                n_weeks=n_weeks,
                seed=user_counter * 42 + i,
            )
            all_frames.append(df)
            user_counter += 1

    return pd.concat(all_frames, ignore_index=True)


def compute_user_features(user_df: pd.DataFrame) -> dict:
    """Compute the feature vector for a single user's transactions."""
    user_df = user_df.copy()
    user_df['created_at'] = pd.to_datetime(user_df['created_at'])

    # Rolling 4-week average by category
    recent = user_df[user_df['week_index'] >= user_df['week_index'].max() - 3]
    cat_weekly = recent.groupby(['week_index', 'category'])['amount_paise'].sum().unstack(fill_value=0)
    rolling_avg = cat_weekly.mean()

    # Last week's actual
    last_week = user_df[user_df['week_index'] == user_df['week_index'].max()]
    last_week_by_cat = last_week.groupby('category')['amount_paise'].sum()

    # Weekend vs weekday
    weekend_spend = recent[recent['is_weekend'] == 1]['amount_paise'].sum()
    weekday_spend = recent[recent['is_weekend'] == 0]['amount_paise'].sum()
    ww_ratio = weekend_spend / weekday_spend if weekday_spend > 0 else 0

    # Volatility (excl fixed)
    variable = recent[~recent['category'].isin(FIXED_CATEGORIES)]
    weekly_totals = variable.groupby('week_index')['amount_paise'].sum()
    volatility = weekly_totals.std() if len(weekly_totals) > 1 else 0
    mean_weekly = weekly_totals.mean() if len(weekly_totals) > 0 else 1
    volatility_pct = volatility / mean_weekly if mean_weekly > 0 else 0

    # Max/median ratio
    all_amounts = recent['amount_paise']
    max_txn = all_amounts.max() if len(all_amounts) > 0 else 0
    median_txn = all_amounts.median() if len(all_amounts) > 0 else 1
    max_median_ratio = max_txn / median_txn if median_txn > 0 else 0

    # Category shares
    total = recent['amount_paise'].sum()
    cat_shares = recent.groupby('category')['amount_paise'].sum() / total if total > 0 else pd.Series()

    # Surplus
    total_avg = rolling_avg.sum()
    total_actual = last_week_by_cat.sum()
    surplus = total_avg - total_actual

    # Txn frequency
    n_weeks_data = len(recent['week_index'].unique())
    txn_frequency = len(recent) / n_weeks_data if n_weeks_data > 0 else 0

    return {
        'weekend_weekday_ratio': ww_ratio,
        'spend_volatility_pct': volatility_pct,
        'max_median_ratio': max_median_ratio,
        'surplus_paise': surplus,
        'txn_frequency': txn_frequency,
        'total_spend_4w': total,
        'n_categories_used': len(cat_shares[cat_shares > 0]),
        'top_category_share': cat_shares.max() if len(cat_shares) > 0 else 0,
    }


if __name__ == '__main__':
    os.makedirs('ml/data', exist_ok=True)

    print('Generating synthetic dataset...')
    dataset = generate_dataset(n_users_per_persona=200, n_weeks=8)
    dataset.to_csv('ml/data/synthetic_train.csv', index=False)
    print(f'  → {len(dataset)} transactions for {dataset["user_id"].nunique()} users')

    # Also compute per-user features
    print('Computing per-user features...')
    feature_rows = []
    for user_id, user_df in dataset.groupby('user_id'):
        features = compute_user_features(user_df)
        features['user_id'] = user_id
        features['persona'] = user_df['persona'].iloc[0]
        feature_rows.append(features)

    features_df = pd.DataFrame(feature_rows)
    features_df.to_csv('ml/data/user_features.csv', index=False)
    print(f'  → {len(features_df)} user feature vectors')
    print('Done.')
