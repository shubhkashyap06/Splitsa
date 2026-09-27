/// DebtSimplifier — greedy debt simplification algorithm.
///
/// Input: a map of user_id → net_balance_paise (positive = owed money back).
/// Output: a minimal list of (payer, payee, amount) settlements that clear
/// all balances in the fewest possible transfers.
///
/// Algorithm (docs/PRODUCT_LOGIC.md §2):
///   1. Separate balances into creditors (positive) and debtors (negative)
///   2. Sort both lists by absolute value descending
///   3. Greedily match the largest debtor against the largest creditor
///   4. Repeat until all balances are settled to within ±1 paise rounding error
///
/// This is O(n log n). The greedy approach does not always produce the
/// globally optimal graph (NP-hard) but gives results that are practically
/// optimal for group sizes typical in Splitsa rooms (2–12 members).
library;

class Settlement {
  const Settlement({
    required this.payerId,
    required this.payeeId,
    required this.amountPaise,
  });

  final String payerId;
  final String payeeId;
  final int amountPaise;

  @override
  String toString() => 'Settlement($payerId → $payeeId: ₹${amountPaise / 100})';
}

abstract final class DebtSimplifier {
  /// Compute a minimum set of settlements to clear [balances].
  ///
  /// [balances] must be pre-computed net balances per user over the room's
  /// full history (expenses + prior settlements). Caller is responsible
  /// for deriving these from ExpenseDao.getSplitsForRoom + settlementsForRoom.
  ///
  /// Balances are expected to sum to 0 (to within ±[tolerancePaise]).
  /// If they don't, this is a data integrity bug — the function still proceeds
  /// but logs a warning.
  static List<Settlement> simplify(
    Map<String, int> balances, {
    int tolerancePaise = 2,
  }) {
    // Validate sum ≈ 0
    final total = balances.values.fold<int>(0, (s, v) => s + v);
    if (total.abs() > tolerancePaise) {
      // Callers should guard, but we don't throw — return what we can.
      assert(false, 'DebtSimplifier: balances sum to $total paise, expected 0');
    }

    // Build mutable lists of (userId, amount) for creditors and debtors
    final creditors = <({String id, int amount})>[];
    final debtors   = <({String id, int amount})>[];

    for (final entry in balances.entries) {
      if (entry.value > tolerancePaise) {
        creditors.add((id: entry.key, amount: entry.value));
      } else if (entry.value < -tolerancePaise) {
        debtors.add((id: entry.key, amount: -entry.value)); // store as positive
      }
    }

    // Sort descending by amount
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final settlements = <Settlement>[];

    // Greedy matching
    int ci = 0, di = 0;
    final creditAmounts = creditors.map((c) => c.amount).toList();
    final debtAmounts   = debtors.map((d) => d.amount).toList();

    while (ci < creditors.length && di < debtors.length) {
      final credit = creditAmounts[ci];
      final debt   = debtAmounts[di];
      final amount = credit < debt ? credit : debt;

      if (amount > tolerancePaise) {
        settlements.add(Settlement(
          payerId:     debtors[di].id,
          payeeId:     creditors[ci].id,
          amountPaise: amount,
        ));
      }

      creditAmounts[ci] -= amount;
      debtAmounts[di]   -= amount;

      if (creditAmounts[ci] <= tolerancePaise) ci++;
      if (debtAmounts[di]   <= tolerancePaise) di++;
    }

    return settlements;
  }
}
