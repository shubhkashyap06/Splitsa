import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/ids.dart';
import '../local/database.dart';
import '../sync/outbox.dart';
import '../sync/sync_providers.dart';
import '../sync/synced_tables.dart';

part 'pot_repository.g.dart';

class PotValidationError implements Exception {
  const PotValidationError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Gradient presets for new Pot cards (UI_UX_SPEC.md §4 "Savings & Pots").
const kPotGradients = <(String, String)>[
  ('#F2A73B', '#E8763C'), // marigold
  ('#2F9E8F', '#1F6F65'), // jade
  ('#C1502E', '#8E3A22'), // rust
  ('#7A86FF', '#5A66FF'), // periwinkle
];

class PotRepository {
  PotRepository(this._db, {void Function()? onWrite})
    : _outbox = Outbox(_db),
      _onWrite = onWrite ?? _noop;

  final AppDatabase _db;
  final Outbox _outbox;
  final void Function() _onWrite;

  static void _noop() {}

  /// Personal pot when [roomId] is null, otherwise a group pot for that room.
  Future<String> createPot({
    required String userId,
    required String name,
    String? roomId,
    int? targetAmountPaise,
    DateTime? targetDate,
    int gradientIndex = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const PotValidationError('Name your pot');
    if (targetAmountPaise != null && targetAmountPaise <= 0) {
      throw const PotValidationError('Target must be more than ₹0');
    }
    final now = DateTime.now();
    final gradient = kPotGradients[gradientIndex % kPotGradients.length];
    final pot = PotsTableData(
      id: newId(),
      name: trimmed,
      ownerType: roomId == null ? 'personal' : 'group',
      userId: userId,
      roomId: roomId,
      targetAmountPaise: targetAmountPaise,
      targetDate: targetDate,
      icon: 'savings',
      gradientStart: gradient.$1,
      gradientEnd: gradient.$2,
      createdAt: now,
      updatedAt: now,
    );
    await _db.transaction(() async {
      await _db.into(_db.potsTable).insert(pot);
      await _outbox.insert(potsSync.name, pot.id, potsSync.toRemote(pot));
    });
    _onWrite();
    return pot.id;
  }

  /// The id doubles as the op_id idempotency key (PROJECT_BRIEF.md §4).
  Future<String> contribute({
    required String potId,
    required String userId,
    required int amountPaise,
  }) async {
    if (amountPaise <= 0) {
      throw const PotValidationError('Amount must be more than ₹0');
    }
    final now = DateTime.now();
    final row = PotContributionsTableData(
      id: newId(),
      potId: potId,
      userId: userId,
      amountPaise: amountPaise,
      createdAt: now,
      updatedAt: now,
    );
    await _db.transaction(() async {
      await _db.into(_db.potContributionsTable).insert(row);
      await _outbox.insert(
        potContributionsSync.name,
        row.id,
        potContributionsSync.toRemote(row),
      );
    });
    _onWrite();
    return row.id;
  }

  Future<void> deletePot(String potId) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.potsTable)..where((t) => t.id.equals(potId))).write(
        PotsTableCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _outbox.softDelete(potsSync.name, potId, now);
    });
    _onWrite();
  }
}

@Riverpod(keepAlive: true)
PotRepository potRepository(Ref ref) => PotRepository(
  ref.watch(appDatabaseProvider),
  onWrite: () => ref.read(syncSchedulerProvider).kick(),
);
