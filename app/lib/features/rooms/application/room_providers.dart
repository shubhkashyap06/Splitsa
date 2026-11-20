import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/local/database.dart';
import '../../../data/local/local_streams.dart';
import '../../../data/remote/session.dart';
import '../../../data/sync/sync_providers.dart';
import '../../recommendations/logic_engine/debt_simplifier.dart';
import '../domain/room_ledger.dart';

part 'room_providers.g.dart';

/// Display name for [id], "You" for the current user.
String nameFor(String id, String? me, Map<String, ProfilesTableData> profiles) {
  if (id == me) return 'You';
  return profiles[id]?.displayName ?? 'Someone';
}

class RoomSummary {
  const RoomSummary({
    required this.room,
    required this.memberIds,
    required this.myNetPaise,
    required this.transfers,
  });
  final RoomsTableData room;
  final List<String> memberIds;

  /// Positive = the room owes me; negative = I owe the room.
  final int myNetPaise;
  final List<Settlement> transfers;
}

class FeedItem {
  const FeedItem({
    required this.expense,
    required this.splitUserIds,
    required this.myDeltaPaise,
    required this.involvesMe,
    required this.pending,
  });
  final ExpensesTableData expense;
  final List<String> splitUserIds;

  /// What this expense did to *my* balance: + I lent, − I borrowed.
  final int myDeltaPaise;
  final bool involvesMe;

  /// Written locally, not yet confirmed by the server.
  final bool pending;
}

class RoomDetail {
  const RoomDetail({
    required this.room,
    required this.memberIds,
    required this.feed,
    required this.net,
    required this.transfers,
    required this.rawDebts,
  });
  final RoomsTableData room;
  final List<String> memberIds;
  final List<FeedItem> feed;
  final Map<String, int> net;
  final List<Settlement> transfers;
  final List<PairwiseDebt> rawDebts;
}

/// Groups every local row by room once, so each screen doesn't re-scan.
class _Ledger {
  _Ledger({
    required List<RoomMembersTableData> members,
    required List<ExpensesTableData> expenses,
    required List<ExpenseSplitsTableData> splits,
    required List<SettlementsTableData> settlements,
  }) {
    for (final m in members) {
      membersByRoom.putIfAbsent(m.roomId, () => []).add(m.userId);
    }
    final roomOfExpense = <String, String>{};
    for (final e in expenses) {
      expensesByRoom.putIfAbsent(e.roomId, () => []).add(e);
      roomOfExpense[e.id] = e.roomId;
    }
    for (final s in splits) {
      final room = roomOfExpense[s.expenseId];
      if (room == null) continue;
      splitsByRoom.putIfAbsent(room, () => []).add(s);
      splitsByExpense.putIfAbsent(s.expenseId, () => []).add(s);
    }
    for (final s in settlements) {
      settlementsByRoom.putIfAbsent(s.roomId, () => []).add(s);
    }
  }

  final membersByRoom = <String, List<String>>{};
  final expensesByRoom = <String, List<ExpensesTableData>>{};
  final splitsByRoom = <String, List<ExpenseSplitsTableData>>{};
  final splitsByExpense = <String, List<ExpenseSplitsTableData>>{};
  final settlementsByRoom = <String, List<SettlementsTableData>>{};

  Map<String, int> netFor(String roomId) => RoomLedger.netBalances(
    memberIds: membersByRoom[roomId] ?? const [],
    expenses: expensesByRoom[roomId] ?? const [],
    splits: splitsByRoom[roomId] ?? const [],
    settlements: settlementsByRoom[roomId] ?? const [],
  );
}

@riverpod
_Ledger? _ledger(Ref ref) {
  final members = ref.watch(allMembersProvider).valueOrNull;
  final expenses = ref.watch(allExpensesProvider).valueOrNull;
  final splits = ref.watch(allSplitsProvider).valueOrNull;
  final settlements = ref.watch(allSettlementsProvider).valueOrNull;
  if (members == null ||
      expenses == null ||
      splits == null ||
      settlements == null) {
    return null; // still loading from disk
  }
  return _Ledger(
    members: members,
    expenses: expenses,
    splits: splits,
    settlements: settlements,
  );
}

/// All my rooms with my balance in each. Null while loading.
@riverpod
List<RoomSummary>? roomSummaries(Ref ref) {
  final rooms = ref.watch(myRoomsProvider).valueOrNull;
  final ledger = ref.watch(_ledgerProvider);
  final me = ref.watch(currentUserIdProvider);
  if (rooms == null || ledger == null || me == null) return null;

  return [
    for (final room in rooms)
      () {
        final net = ledger.netFor(room.id);
        return RoomSummary(
          room: room,
          memberIds: ledger.membersByRoom[room.id] ?? const [],
          myNetPaise: net[me] ?? 0,
          transfers: RoomLedger.simplified(net),
        );
      }(),
  ];
}

@riverpod
RoomDetail? roomDetail(Ref ref, String roomId) {
  final rooms = ref.watch(myRoomsProvider).valueOrNull;
  final ledger = ref.watch(_ledgerProvider);
  final me = ref.watch(currentUserIdProvider);
  final pending =
      ref.watch(pendingRowIdsProvider).valueOrNull ?? const <String>{};
  if (rooms == null || ledger == null) return null;

  final room = rooms.where((r) => r.id == roomId).firstOrNull;
  if (room == null) return null;

  final expenses = ledger.expensesByRoom[roomId] ?? const [];
  final feed = <FeedItem>[];
  for (final e in expenses) {
    final splits = ledger.splitsByExpense[e.id] ?? const [];
    final myShare = splits
        .where((s) => s.userId == me)
        .fold<int>(0, (sum, s) => sum + s.amountPaise);
    final iPaid = e.paidBy == me;
    feed.add(
      FeedItem(
        expense: e,
        splitUserIds: splits.map((s) => s.userId).toList(),
        myDeltaPaise: iPaid ? e.amountPaise - myShare : -myShare,
        involvesMe: iPaid || myShare > 0,
        pending: pending.contains(e.id),
      ),
    );
  }

  final net = ledger.netFor(roomId);
  return RoomDetail(
    room: room,
    memberIds: ledger.membersByRoom[roomId] ?? const [],
    feed: feed,
    net: net,
    transfers: RoomLedger.simplified(net),
    rawDebts: RoomLedger.rawPairwiseDebts(
      expenses: expenses,
      splits: ledger.splitsByRoom[roomId] ?? const [],
      settlements: ledger.settlementsByRoom[roomId] ?? const [],
    ),
  );
}

/// Simplified transfers involving me, across every room — feeds Home's
/// "You owe / Owed to you" boxes and the account-deletion gate.
class MyDebts {
  const MyDebts({required this.iOwe, required this.owedToMe});
  final List<(String roomId, Settlement transfer)> iOwe;
  final List<(String roomId, Settlement transfer)> owedToMe;

  int get totalIOwe => iOwe.fold(0, (s, t) => s + t.$2.amountPaise);
  int get totalOwedToMe => owedToMe.fold(0, (s, t) => s + t.$2.amountPaise);
}

@riverpod
MyDebts? myDebts(Ref ref) {
  final summaries = ref.watch(roomSummariesProvider);
  final me = ref.watch(currentUserIdProvider);
  if (summaries == null || me == null) return null;
  final iOwe = <(String, Settlement)>[];
  final owed = <(String, Settlement)>[];
  for (final s in summaries) {
    for (final t in s.transfers) {
      if (t.payerId == me) iOwe.add((s.room.id, t));
      if (t.payeeId == me) owed.add((s.room.id, t));
    }
  }
  return MyDebts(iOwe: iOwe, owedToMe: owed);
}
