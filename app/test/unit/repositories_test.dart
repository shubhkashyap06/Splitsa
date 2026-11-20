import 'package:flutter_test/flutter_test.dart';
import 'package:splitsa/core/utils/money.dart';
import 'package:splitsa/data/local/database.dart';
import 'package:splitsa/data/repositories/expense_repository.dart';
import 'package:splitsa/data/repositories/pot_repository.dart';
import 'package:splitsa/data/repositories/profile_repository.dart';

import '../support/fake_remote.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('ExpenseRepository', () {
    test(
      'rejects shares that do not add up — nothing written, nothing queued',
      () async {
        final repo = ExpenseRepository(db);
        await expectLater(
          repo.addSharedExpense(
            roomId: 'r',
            paidBy: 'a',
            description: 'x',
            amountPaise: 1000,
            category: 'food',
            shares: {'a': 400, 'b': 400},
          ),
          throwsA(isA<ExpenseValidationError>()),
        );
        expect(await db.select(db.expensesTable).get(), isEmpty);
        expect(await db.syncDao.queueLength(), 0);
      },
    );

    test('rejects zero amounts', () async {
      expect(
        () => ExpenseRepository(db).addPersonalExpense(
          userId: 'a',
          description: '',
          amountPaise: 0,
          category: 'food',
        ),
        throwsA(isA<ExpenseValidationError>()),
      );
    });

    test('only the payer can delete a shared expense', () async {
      final repo = ExpenseRepository(db);
      final id = await repo.addSharedExpense(
        roomId: 'r',
        paidBy: 'a',
        description: 'x',
        amountPaise: 1000,
        category: 'food',
        shares: {'a': 500, 'b': 500},
      );
      expect(
        () => repo.deleteSharedExpense(id, byUserId: 'b'),
        throwsA(isA<ExpenseValidationError>()),
      );
      await repo.deleteSharedExpense(id, byUserId: 'a');
      expect((await db.expenseDao.getExpense(id))!.deletedAt, isNotNull);
    });

    test('blank description falls back to a label, never empty', () async {
      final id = await ExpenseRepository(db).addPersonalExpense(
        userId: 'a',
        description: '   ',
        amountPaise: 100,
        category: 'food',
      );
      final row = await (db.select(
        db.personalExpensesTable,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.description, 'Expense');
    });
  });

  group('PotRepository', () {
    test('a personal pot has no room; contributions are queued', () async {
      final repo = PotRepository(db);
      final potId = await repo.createPot(userId: 'a', name: 'Goa');
      await repo.contribute(potId: potId, userId: 'a', amountPaise: 34000);
      final pot = (await db.select(db.potsTable).get()).single;
      expect(pot.ownerType, 'personal');
      expect(pot.roomId, isNull);
      expect(await db.syncDao.queueLength(), 2);
    });

    test('rejects empty names and non-positive amounts', () async {
      final repo = PotRepository(db);
      expect(
        () => repo.createPot(userId: 'a', name: ' '),
        throwsA(isA<PotValidationError>()),
      );
      expect(
        () => repo.contribute(potId: 'p', userId: 'a', amountPaise: 0),
        throwsA(isA<PotValidationError>()),
      );
    });
  });

  group('ProfileRepository.validateUpi', () {
    test('accepts real-looking VPAs, rejects junk', () {
      expect(ProfileRepository.validateUpi('aditi@okicici'), isNull);
      expect(ProfileRepository.validateUpi('9876543210@ybl'), isNull);
      expect(ProfileRepository.validateUpi(''), isNull);
      expect(ProfileRepository.validateUpi('aditi'), isNotNull);
      expect(ProfileRepository.validateUpi('a@b@c'), isNotNull);
    });
  });

  group('money helpers', () {
    test('parseRupeesToPaise', () {
      expect(parseRupeesToPaise('230'), 23000);
      expect(parseRupeesToPaise('230.5'), 23050);
      expect(parseRupeesToPaise('1,200.05'), 120005);
      expect(parseRupeesToPaise(''), isNull);
      expect(parseRupeesToPaise('-5'), isNull);
      expect(parseRupeesToPaise('1.234'), isNull);
    });

    test('groupRupeeInput keeps a half-typed amount readable', () {
      expect(groupRupeeInput(''), '0');
      expect(groupRupeeInput('11464'), '11,464');
      expect(groupRupeeInput('123456'), '1,23,456');
      expect(groupRupeeInput('1200.'), '1,200.');
      expect(groupRupeeInput('1200.5'), '1,200.5');
    });

    test('formatPaise uses Indian grouping and hides zero paise', () {
      expect(formatPaise(12345000), '₹1,23,450');
      expect(formatPaise(23050), '₹230.50');
      expect(formatPaise(-500), '−₹5');
    });
  });
}
