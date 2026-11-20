import 'package:flutter_test/flutter_test.dart';
import 'package:splitsa/data/local/database.dart';
import 'package:splitsa/features/recommendations/logic_engine/logic_recommendation_engine.dart';
import 'package:splitsa/features/recommendations/recommendation_engine.dart';
import 'package:splitsa/features/recommendations/spend_feature_builder.dart';

final _now = DateTime(2026, 11, 20, 12);

PersonalExpensesTableData _spend(
  int daysAgo,
  int paise, {
  String category = 'food',
}) {
  final at = _now.subtract(Duration(days: daysAgo));
  return PersonalExpensesTableData(
    id: 'p$daysAgo-$paise-$category',
    userId: 'me',
    description: 'x',
    amountPaise: paise,
    category: category,
    createdAt: at,
    updatedAt: at,
  );
}

SpendFeatureData _features(List<PersonalExpensesTableData> rows) =>
    const SpendFeatureBuilder().build(
      personalExpenses: rows,
      sharedExpenses: const [],
      sharedSplits: const [],
      now: _now,
    );

void main() {
  const engine = LogicRecommendationEngine();

  test(
    'no history → cold start persona, no nudge (nothing to compare)',
    () async {
      final f = _features(const []);
      expect(await engine.classifyPersona(f), SpendPersona.coldStart);
      expect(await engine.generateNudge(f), isNull);
    },
  );

  test(
    'cold start with a quieter week still gets a real nudge (PRODUCT_LOGIC.md §3)',
    () async {
      // Two weeks of history: ₹2,000 last week, ₹500 this week.
      final f = _features([_spend(10, 200000), _spend(2, 50000)]);
      expect(f.totalWeeksOfHistory, lessThan(kColdStartWeeks));
      final nudge = await engine.generateNudge(f);
      expect(nudge, isNotNull);
      // 70% of (2000 − 500) = ₹1,050.
      expect(nudge!.recommendedAmountPaise, 105000);
    },
  );

  test('surplus below the ₹200 floor produces no nudge', () async {
    final f = _features([_spend(10, 30000), _spend(2, 20000)]);
    expect(await engine.generateNudge(f), isNull);
  });

  test(
    'fixed costs are excluded from volatility but counted in weekly totals',
    () {
      final f = _features([
        _spend(3, 1500000, category: 'rent'),
        _spend(2, 10000),
      ]);
      expect(f.weeklyTotalsExclFixed.first, 10000);
      expect(f.weeklyTotalsAll.first, 1510000);
    },
  );

  test('weekend-heavy month classifies as Weekend Spender', () async {
    // 20 Nov 2026 is a Friday; build 5 weeks with big Saturday spends.
    final rows = <PersonalExpensesTableData>[];
    for (var w = 0; w < 5; w++) {
      rows
        ..add(_spend(6 + 7 * w, 300000)) // Saturday
        ..add(_spend(2 + 7 * w, 100000)); // Wednesday
    }
    final f = _features(rows);
    expect(await engine.classifyPersona(f), SpendPersona.weekendSpender);
  });
}
