/// The airplane-mode matrix from OFFLINE_SYNC.md §6, as real tests against
/// an in-memory Drift DB and a fake Supabase.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitsa/data/local/daos/sync_dao.dart';
import 'package:splitsa/data/local/database.dart';
import 'package:splitsa/data/repositories/expense_repository.dart';
import 'package:splitsa/data/repositories/room_repository.dart';
import 'package:splitsa/data/sync/sync_engine.dart';

import '../../support/fake_remote.dart';

const me = '00000000-0000-7000-8000-000000000001';
const aditi = '00000000-0000-7000-8000-000000000002';

void main() {
  late AppDatabase db;
  late FakeRemote remote;
  late SyncEngine engine;
  late ExpenseRepository expenses;
  late RoomRepository rooms;

  setUp(() {
    db = memoryDb();
    remote = FakeRemote();
    engine = SyncEngine(db: db, remote: remote, currentUserId: () => me);
    expenses = ExpenseRepository(db);
    rooms = RoomRepository(db, remote, engine);
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<String> roomWithAditi() async {
    final roomId = await rooms.createRoom(name: 'Flat 4B', createdBy: me);
    // Aditi joined via invite on the server; pretend we already pulled her.
    await db
        .into(db.roomMembersTable)
        .insert(
          RoomMembersTableCompanion.insert(
            id: 'm-aditi',
            roomId: roomId,
            userId: aditi,
            joinedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    return roomId;
  }

  test(
    'a write in airplane mode lands locally and waits in the outbox',
    () async {
      remote.online = false;
      final roomId = await roomWithAditi();
      await expenses.addSharedExpense(
        roomId: roomId,
        paidBy: me,
        description: 'Pizza',
        amountPaise: 45000,
        category: 'food',
        shares: {me: 22500, aditi: 22500},
      );

      await engine.sync();

      expect(await db.expenseDao.watchAllExpenses().first, hasLength(1));
      expect(
        await db.syncDao.queueLength(),
        5,
      ); // room, member, expense, 2 splits
      expect(engine.status.phase, SyncPhase.offline);
      expect(remote.tables['expenses'], isNull);
    },
  );

  test(
    'reconnect drains the queue FIFO with no duplicates server-side',
    () async {
      remote.online = false;
      final roomId = await roomWithAditi();
      final expenseId = await expenses.addSharedExpense(
        roomId: roomId,
        paidBy: me,
        description: 'Groceries',
        amountPaise: 1000,
        category: 'food',
        shares: {me: 500, aditi: 500},
      );
      await engine.sync();

      remote.online = true;
      await engine.sync(force: true);

      expect(await db.syncDao.queueLength(), 0);
      expect(remote.tables['expenses']!.keys, [expenseId]);
      expect(remote.tables['expense_splits'], hasLength(2));

      // Parents strictly before children: room → member → expense → splits.
      final order = remote.calls.map((c) => c.split(':')[1]).toList();
      expect(order, [
        'rooms',
        'room_members',
        'expenses',
        'expense_splits',
        'expense_splits',
      ]);
    },
  );

  test(
    'replaying an already-applied op is a no-op (idempotency key)',
    () async {
      final roomId = await roomWithAditi();
      await engine.sync(force: true);
      final before = remote.tables['rooms']!.length;

      // Simulate "killed mid-sync": server applied it, but the queue row
      // survived on the device. Re-enqueue the same row and sync again.
      final room = (await db.select(db.roomsTable).get()).single;
      await db.syncDao.enqueue(
        SyncQueueTableCompanion.insert(
          opId: 'replay-1',
          tableName_: 'rooms',
          rowId: room.id,
          operation: 'insert',
          payloadJson: jsonEncode({
            'id': roomId,
            'name': room.name,
            'created_by': me,
          }),
          createdAt: DateTime.now(),
        ),
      );
      await engine.sync(force: true);

      expect(remote.tables['rooms']!.length, before);
      expect(await db.syncDao.queueLength(), 0);
    },
  );

  test(
    'a permanently rejected op is dead-lettered and does not block others',
    () async {
      final roomId = await roomWithAditi();
      await engine.sync(force: true);

      final badId = await expenses.addPersonalExpense(
        userId: me,
        description: 'Bad row',
        amountPaise: 100,
        category: 'other',
      );
      remote.rejectIds.add(badId);
      final goodId = await expenses.addPersonalExpense(
        userId: me,
        description: 'Chai',
        amountPaise: 2000,
        category: 'food',
      );

      for (var i = 0; i < kMaxSyncRetries; i++) {
        await engine.sync(force: true);
      }

      expect(remote.tables['personal_expenses']!.keys, contains(goodId));
      expect(remote.tables['personal_expenses']!.keys, isNot(contains(badId)));
      expect(
        await db.syncDao.queueLength(),
        0,
        reason: 'bad op parked, not pending',
      );
      final parked = await db.select(db.syncQueueTable).get();
      expect(parked.single.rowId, badId);
      expect(parked.single.retryCount, kMaxSyncRetries);
      expect(roomId, isNotEmpty);
    },
  );

  test('delta pull upserts remote rows and advances the watermark', () async {
    final roomId = await roomWithAditi();
    await engine.sync(force: true);

    remote.seed('expenses', {
      'id': 'remote-exp-1',
      'room_id': roomId,
      'paid_by': aditi,
      'description': 'Uber',
      'amount_paise': 22000,
      'category': 'travel',
      'split_mode': 'equal',
      'created_at': DateTime.utc(2026, 11, 2).toIso8601String(),
    });
    await engine.sync(force: true);

    final local = await db.expenseDao.getExpense('remote-exp-1');
    expect(local?.description, 'Uber');
    expect(await db.syncDao.getWatermark('expenses'), isNotNull);
  });

  test(
    'a pending local edit is not clobbered by an older server copy',
    () async {
      final roomId = await roomWithAditi();
      remote.online = false;
      final id = await expenses.addSharedExpense(
        roomId: roomId,
        paidBy: me,
        description: 'Mine, offline',
        amountPaise: 1000,
        category: 'food',
        shares: {me: 500, aditi: 500},
      );
      // Some stale server copy of the same id shows up (e.g. another device).
      remote.online = true;
      remote.seed('expenses', {
        'id': id,
        'room_id': roomId,
        'paid_by': me,
        'description': 'Stale server copy',
        'amount_paise': 1000,
        'category': 'food',
      });
      // Block the push so the local op stays pending during the pull.
      remote.rejectIds.add(id);
      await engine.sync(force: true);

      expect(
        (await db.expenseDao.getExpense(id))!.description,
        'Mine, offline',
      );
    },
  );

  test('joining a room backfills history older than the watermark', () async {
    await engine.sync(force: true); // establishes watermarks

    // A room that existed long before we joined, with old history.
    final old = DateTime.utc(2025, 1, 1).toIso8601String();
    remote.seed('rooms', {
      'id': 'room-goa',
      'name': 'Goa Trip',
      'icon': 'trip',
      'created_by': aditi,
      'updated_at': old,
    });
    remote.seed('profiles', {
      'id': aditi,
      'display_name': 'Aditi',
      'updated_at': old,
    });
    remote.seed('expenses', {
      'id': 'old-exp',
      'room_id': 'room-goa',
      'paid_by': aditi,
      'description': 'Villa',
      'amount_paise': 900000,
      'category': 'travel',
      'updated_at': old,
    });
    remote.seed('expense_splits', {
      'id': 's1',
      'expense_id': 'old-exp',
      'user_id': me,
      'amount_paise': 450000,
      'updated_at': old,
    });
    remote.seed('room_members', {
      'id': 'm-a',
      'room_id': 'room-goa',
      'user_id': aditi,
      'joined_at': old,
      'updated_at': old,
    });
    // Our membership is the only fresh row.
    remote.seed('room_members', {
      'id': 'm-me',
      'room_id': 'room-goa',
      'user_id': me,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });

    await engine.sync(force: true);

    expect((await db.roomDao.getRoom('room-goa'))?.name, 'Goa Trip');
    expect((await db.expenseDao.getExpense('old-exp'))?.description, 'Villa');
    expect(await db.expenseDao.getSplitsForExpense('old-exp'), hasLength(1));
    expect((await db.profileDao.getProfile(aditi))?.displayName, 'Aditi');
  });

  test('backoff grows with failures and is capped at 5 minutes', () {
    final d1 = engine.backoffFor(1);
    final d8 = engine.backoffFor(8);
    final d20 = engine.backoffFor(20);
    expect(d1.inSeconds, inInclusiveRange(1, 2));
    expect(d8.inSeconds, inInclusiveRange(128, 256));
    expect(d20.inSeconds, lessThanOrEqualTo(300));
  });
}
