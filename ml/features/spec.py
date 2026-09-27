"""
Splitsa — ML feature specification.

Single source of truth for all feature definitions used by:
  - The Python training pipeline (ml/train.py)
  - The Dart on-device feature builder (app/lib/features/ml/features/)

⚠️  STATUS: NOT BUILT. This file defines the planned feature set.
    Neither model is trained. v1 runs on the hand-written logic engine
    in app/lib/features/recommendations/logic_engine/.
    See docs/ML_PIPELINE.md for the full design.

Rule: a PR that changes a feature definition here must also update the
matching Dart mirror in app/lib/features/ml/features/ in the same commit.
"""

from dataclasses import dataclass
from typing import Literal

# ---------------------------------------------------------------------------
# Feature categories
# ---------------------------------------------------------------------------

FIXED_COST_CATEGORIES = frozenset({
    "rent",
    "electricity",
    "wifi",
    "subscriptions",
    "gas",
})
"""
Categories excluded from spend-volatility computation (Model 2).
Including Bills in volatility swamps the actual behavioral signal —
everyone has high fixed costs regardless of spending persona.
See docs/ML_PIPELINE.md §"Model 2".
"""


@dataclass(frozen=True)
class SpendFeatures:
    """
    Feature vector computed from a user's Expense + PersonalExpense history.
    Shared by both Model 1 (savings predictor) and Model 2 (persona classifier).

    All monetary values are in paise (₹ × 100) to avoid floating-point drift.
    """

    # --- Model 1 inputs (regression) ---
    rolling_4w_avg_paise: dict[str, float]
    """Rolling 4-week average spend per category, in paise."""

    last_week_spend_paise: dict[str, float]
    """Last week's total spend per category, in paise."""

    day_of_week: int
    """0 = Monday … 6 = Sunday at prediction time."""

    day_of_month: int
    """1–31 — captures rent/bill-cycle effects."""

    category_share: dict[str, float]
    """Each category's proportion of total spend (0.0–1.0). Sums to 1."""

    week_over_week_delta: dict[str, float]
    """(this_week − last_week) / last_week per category. NaN if last_week == 0."""

    # --- Model 2 inputs (clustering) ---
    weekend_vs_weekday_ratio: float
    """
    Total weekend spend / total weekday spend over the last 4 weeks.
    Threshold > 0.6 → Weekend Spender (logic engine) — see docs/PRODUCT_LOGIC.md §3.
    """

    spend_volatility_excl_fixed: float
    """
    Std-dev of weekly totals over 4 weeks, EXCLUDING fixed-cost categories.
    Bills excluded per docs/ML_PIPELINE.md §"Model 2" — the known gotcha.
    """

    max_single_transaction_ratio: float
    """
    Largest single transaction in the period / user's own median transaction size.
    Above 2.0 with high volatility → Bulk Buyer (logic engine).
    """

    transaction_frequency: float
    """Mean transactions per week over the last 4 weeks."""


WEEKS_FOR_COLD_START = 4
"""
Users with fewer than this many weeks of history use the cold-start heuristic
instead of category-level rolling averages.
See docs/PRODUCT_LOGIC.md §3 and docs/ML_PIPELINE.md §"Cold start".
"""

SAVINGS_SAFETY_FRACTION = 0.70
"""
The logic engine and ML pipeline alike recommend 70 % of the detected surplus,
not the full delta — conservative enough that the nudge never asks the user to
move money they might still need this week.
See docs/PRODUCT_LOGIC.md §3.
"""
