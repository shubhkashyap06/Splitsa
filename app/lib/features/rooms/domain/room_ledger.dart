/// RoomLedger — pure balance math for one room (PRODUCT_LOGIC.md §2).
///
/// Net balances are derived from expenses/splits *and* settlements summed
/// together; a settlement is its own balance event, never an edit to an
/// expense. Nothing here is stored — it's recomputed on every view.
library;

import '../../../data/local/database.dart';
import '../../recommendations/logic_engine/debt_simplifier.dart';

class PairwiseDebt {
  const PairwiseDebt({
    required this.fromId,
    required this.toId,
    required this.amountPaise,
  });
  final String fromId;
  final String toId;
  final int amountPaise;
}

abstract final class RoomLedger {
  /// userId → net paise (positive = owed money, negative = owes money).
  ///
  /// Every id in [memberIds] gets an entry (possibly 0), plus anyone who
  /// appears in the history — a former member who still has open balances
  /// must not silently vanish from the math.
  static Map<String, int> netBalances({
    required Iterable<String> memberIds,
    required List<ExpensesTableData> expenses,
    required List<ExpenseSplitsTableData> splits,
    required List<SettlementsTableData> settlements,
  }) {
    final net = <String, int>{for (final id in memberIds) id: 0};
    final live = {
      for (final e in expenses)
        if (e.deletedAt == null) e.id: e,
    };

    for (final s in splits) {
      final e = live[s.expenseId];
      if (e == null || s.deletedAt != null) continue;
      // Payer fronted this share; the split's user consumed it.
      net[e.paidBy] = (net[e.paidBy] ?? 0) + s.amountPaise;
      net[s.userId] = (net[s.userId] ?? 0) - s.amountPaise;
    }
    for (final st in settlements) {
      if (st.deletedAt != null) continue;
      net[st.payerId] = (net[st.payerId] ?? 0) + st.amountPaise;
      net[st.payeeId] = (net[st.payeeId] ?? 0) - st.amountPaise;
    }
    return net;
  }

  /// The raw "who owes whom" before simplification, straight from the
  /// expense feed — shown above the simplified result in the disclosure
  /// sheet so a simplified number is never a black box.
  static List<PairwiseDebt> rawPairwiseDebts({
    required List<ExpensesTableData> expenses,
    required List<ExpenseSplitsTableData> splits,
    required List<SettlementsTableData> settlements,
  }) {
    final owes = <(String, String), int>{};
    void add(String from, String to, int amt) {
      if (from == to || amt == 0) return;
      owes[(from, to)] = (owes[(from, to)] ?? 0) + amt;
    }

    final live = {
      for (final e in expenses)
        if (e.deletedAt == null) e.id: e,
    };
    for (final s in splits) {
      final e = live[s.expenseId];
      if (e == null || s.deletedAt != null) continue;
      add(s.userId, e.paidBy, s.amountPaise);
    }
    for (final st in settlements) {
      if (st.deletedAt != null) continue;
      // Paying someone reduces what you owe them.
      add(st.payerId, st.payeeId, -st.amountPaise);
    }

    final out = <PairwiseDebt>[];
    final seen = <(String, String)>{};
    for (final key in owes.keys) {
      final (a, b) = key;
      if (seen.contains((b, a))) continue;
      seen.add(key);
      final d = (owes[(a, b)] ?? 0) - (owes[(b, a)] ?? 0);
      if (d > 0) out.add(PairwiseDebt(fromId: a, toId: b, amountPaise: d));
      if (d < 0) out.add(PairwiseDebt(fromId: b, toId: a, amountPaise: -d));
    }
    out.sort((x, y) => y.amountPaise.compareTo(x.amountPaise));
    return out;
  }

  static List<Settlement> simplified(Map<String, int> net) =>
      DebtSimplifier.simplify(net, tolerancePaise: 0);
}
