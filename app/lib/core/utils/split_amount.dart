/// splitAmount — deterministic split rounding per docs/PRODUCT_LOGIC.md §1.
///
/// Splits [totalPaise] among [n] people. The payer (at [payerIndex])
/// absorbs any rounding remainder so the sum always equals [totalPaise]
/// exactly. This is a pure function — no state, no side effects.
///
/// Returns a List<int> of length [n] where each entry is the share
/// in paise for that index.
library;

/// Split [totalPaise] equally among [n] people.
/// The [payerIndex]'th person absorbs the rounding remainder.
List<int> splitAmount(int totalPaise, int n, int payerIndex) {
  assert(n > 0, 'Cannot split among 0 people');
  assert(payerIndex >= 0 && payerIndex < n, 'payerIndex out of bounds');

  final perPerson = totalPaise ~/ n; // floor division
  final remainder = totalPaise - (perPerson * n);

  return List.generate(n, (i) => i == payerIndex ? perPerson + remainder : perPerson);
}

/// Split [totalPaise] by explicit percentages.
/// [percentages] must have exactly [n] entries that sum to 100.0 (or close).
/// The [payerIndex]'th person absorbs the rounding remainder.
List<int> splitByPercentage(
  int totalPaise,
  List<double> percentages,
  int payerIndex,
) {
  assert(percentages.isNotEmpty);
  assert(payerIndex >= 0 && payerIndex < percentages.length);

  final shares = percentages.map((pct) => (totalPaise * pct / 100).floor()).toList();
  final allocated = shares.fold<int>(0, (s, v) => s + v);
  final remainder = totalPaise - allocated;

  shares[payerIndex] += remainder;
  return shares;
}

/// Split [totalPaise] by explicit amounts in paise.
/// The [payerIndex]'th person absorbs the rounding remainder.
List<int> splitByAmounts(
  int totalPaise,
  List<int> amounts,
  int payerIndex,
) {
  assert(amounts.isNotEmpty);
  assert(payerIndex >= 0 && payerIndex < amounts.length);

  final allocated = amounts.fold<int>(0, (s, v) => s + v);
  final remainder = totalPaise - allocated;

  final result = List<int>.from(amounts);
  result[payerIndex] += remainder;
  return result;
}
