import 'package:flutter_test/flutter_test.dart';
import 'package:splitsa/core/utils/split_amount.dart';
import 'package:splitsa/data/local/database.dart';
import 'package:splitsa/features/rooms/domain/room_ledger.dart';

final _t = DateTime(2026, 11, 1);

ExpensesTableData _expense(
  String id,
  String paidBy,
  int amount, {
  DateTime? deletedAt,
}) => ExpensesTableData(
  id: id,
  roomId: 'r',
  paidBy: paidBy,
  description: id,
  amountPaise: amount,
  category: 'food',
  splitMode: 'equal',
  createdAt: _t,
  updatedAt: _t,
  deletedAt: deletedAt,
);

ExpenseSplitsTableData _split(String expenseId, String user, int amount) =>
    ExpenseSplitsTableData(
      id: '$expenseId-$user',
      expenseId: expenseId,
      userId: user,
      amountPaise: amount,
      createdAt: _t,
      updatedAt: _t,
    );

SettlementsTableData _settle(String from, String to, int amount) =>
    SettlementsTableData(
      id: 's-$from-$to-$amount',
      roomId: 'r',
      payerId: from,
      payeeId: to,
      amountPaise: amount,
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  group('splitAmount (PRODUCT_LOGIC.md §1)', () {
    test('₹100 three ways puts the leftover paisa on the payer', () {
      expect(splitAmount(10000, 3, 0), [3334, 3333, 3333]);
      expect(splitAmount(10000, 3, 2), [3333, 3333, 3334]);
    });

    test('shares always sum to the total', () {
      for (final n in [1, 2, 3, 7, 12]) {
        for (final total in [1, 99, 10001, 123457]) {
          expect(splitAmount(total, n, n - 1).reduce((a, b) => a + b), total);
        }
      }
    });

    test('percentage remainder lands on the payer', () {
      final shares = splitByPercentage(10000, [33.33, 33.33, 33.34], 1);
      expect(shares.reduce((a, b) => a + b), 10000);
    });
  });

  group('RoomLedger', () {
    test('net balances sum to zero and reflect who fronted money', () {
      final net = RoomLedger.netBalances(
        memberIds: ['a', 'b', 'c'],
        expenses: [_expense('e1', 'a', 9000)],
        splits: [
          _split('e1', 'a', 3000),
          _split('e1', 'b', 3000),
          _split('e1', 'c', 3000),
        ],
        settlements: const [],
      );
      expect(net, {'a': 6000, 'b': -3000, 'c': -3000});
      expect(net.values.reduce((x, y) => x + y), 0);
    });

    test('a settlement is its own balance event, not an expense edit', () {
      final net = RoomLedger.netBalances(
        memberIds: ['a', 'b'],
        expenses: [_expense('e1', 'a', 1000)],
        splits: [_split('e1', 'a', 500), _split('e1', 'b', 500)],
        settlements: [_settle('b', 'a', 500)],
      );
      expect(net, {'a': 0, 'b': 0});
    });

    test('deleted expenses are ignored', () {
      final net = RoomLedger.netBalances(
        memberIds: ['a', 'b'],
        expenses: [_expense('e1', 'a', 1000, deletedAt: _t)],
        splits: [_split('e1', 'a', 500), _split('e1', 'b', 500)],
        settlements: const [],
      );
      expect(net, {'a': 0, 'b': 0});
    });

    test('a former member with history still counts', () {
      final net = RoomLedger.netBalances(
        memberIds: ['a'],
        expenses: [_expense('e1', 'gone', 1000)],
        splits: [_split('e1', 'a', 1000)],
        settlements: const [],
      );
      expect(net, {'a': -1000, 'gone': 1000});
    });

    test(
      'simplification turns a chain into one transfer, raw debts show the chain',
      () {
        // me owes Kabir 150 (Kabir paid), Kabir owes Aditi 150 (Aditi paid).
        final expenses = [
          _expense('e1', 'kabir', 150),
          _expense('e2', 'aditi', 150),
        ];
        final splits = [_split('e1', 'me', 150), _split('e2', 'kabir', 150)];
        final net = RoomLedger.netBalances(
          memberIds: ['me', 'kabir', 'aditi'],
          expenses: expenses,
          splits: splits,
          settlements: const [],
        );
        final simplified = RoomLedger.simplified(net);
        expect(simplified, hasLength(1));
        expect(simplified.single.payerId, 'me');
        expect(simplified.single.payeeId, 'aditi');
        expect(simplified.single.amountPaise, 150);

        final raw = RoomLedger.rawPairwiseDebts(
          expenses: expenses,
          splits: splits,
          settlements: const [],
        );
        expect(raw, hasLength(2));
      },
    );

    test(
      'raw pairwise debts net opposite directions and subtract settlements',
      () {
        final raw = RoomLedger.rawPairwiseDebts(
          expenses: [_expense('e1', 'a', 1000), _expense('e2', 'b', 400)],
          splits: [_split('e1', 'b', 1000), _split('e2', 'a', 400)],
          settlements: [_settle('b', 'a', 100)],
        );
        expect(raw, hasLength(1));
        expect(raw.single.fromId, 'b');
        expect(raw.single.toId, 'a');
        expect(raw.single.amountPaise, 500);
      },
    );

    test('all settled → no transfers', () {
      expect(RoomLedger.simplified({'a': 0, 'b': 0}), isEmpty);
    });
  });
}
