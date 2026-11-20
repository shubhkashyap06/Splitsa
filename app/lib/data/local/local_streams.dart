/// Raw Drift watch() streams exposed as providers. Feature providers combine
/// these; widgets never touch the database directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../remote/session.dart';
import 'database.dart';

part 'local_streams.g.dart';

@riverpod
Stream<List<RoomsTableData>> myRooms(Ref ref) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(appDatabaseProvider).roomDao.watchRoomsForUser(me);
}

@riverpod
Stream<List<RoomMembersTableData>> allMembers(Ref ref) =>
    ref.watch(appDatabaseProvider).roomDao.watchAllMembers();

@riverpod
Stream<List<ExpensesTableData>> allExpenses(Ref ref) =>
    ref.watch(appDatabaseProvider).expenseDao.watchAllExpenses();

@riverpod
Stream<List<ExpenseSplitsTableData>> allSplits(Ref ref) =>
    ref.watch(appDatabaseProvider).expenseDao.watchAllSplits();

@riverpod
Stream<List<SettlementsTableData>> allSettlements(Ref ref) =>
    ref.watch(appDatabaseProvider).expenseDao.watchAllSettlements();

@riverpod
Stream<List<PersonalExpensesTableData>> myPersonalExpenses(Ref ref) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(appDatabaseProvider).expenseDao.watchPersonalExpenses(me);
}

@riverpod
Stream<Map<String, ProfilesTableData>> profilesById(Ref ref) => ref
    .watch(appDatabaseProvider)
    .profileDao
    .watchAllProfiles()
    .map((rows) => {for (final p in rows) p.id: p});

@riverpod
Stream<ProfilesTableData?> myProfile(Ref ref) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return Stream.value(null);
  return ref.watch(appDatabaseProvider).profileDao.watchProfile(me);
}

@riverpod
Stream<List<PotsTableData>> allPots(Ref ref) =>
    ref.watch(appDatabaseProvider).potDao.watchPots();

@riverpod
Stream<List<PotContributionsTableData>> allContributions(Ref ref) =>
    ref.watch(appDatabaseProvider).potDao.watchContributions();
