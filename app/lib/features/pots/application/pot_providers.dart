import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/local/database.dart';
import '../../../data/local/local_streams.dart';
import '../../../data/remote/session.dart';

part 'pot_providers.g.dart';

class PotView {
  const PotView({
    required this.pot,
    required this.savedPaise,
    required this.contributorIds,
    required this.roomName,
  });
  final PotsTableData pot;
  final int savedPaise;
  final Set<String> contributorIds;
  final String? roomName;

  /// 0–100, or null when the pot has no target.
  double? get progressPct {
    final t = pot.targetAmountPaise;
    if (t == null || t == 0) return null;
    return (savedPaise * 100 / t).clamp(0, 100).toDouble();
  }

  bool get isPersonal => pot.ownerType == 'personal';
}

/// Personal pots first (the first one is "Your Potli"), then group pots.
@riverpod
List<PotView>? potViews(Ref ref) {
  final me = ref.watch(currentUserIdProvider);
  final pots = ref.watch(allPotsProvider).valueOrNull;
  final contributions = ref.watch(allContributionsProvider).valueOrNull;
  final rooms = ref.watch(myRoomsProvider).valueOrNull;
  if (pots == null || contributions == null || rooms == null) return null;

  final roomNames = {for (final r in rooms) r.id: r.name};
  final savedByPot = <String, int>{};
  final contributors = <String, Set<String>>{};
  for (final c in contributions) {
    savedByPot[c.potId] = (savedByPot[c.potId] ?? 0) + c.amountPaise;
    contributors.putIfAbsent(c.potId, () => {}).add(c.userId);
  }

  final views = [
    for (final p in pots)
      if (p.ownerType == 'group' || p.userId == me)
        PotView(
          pot: p,
          savedPaise: savedByPot[p.id] ?? 0,
          contributorIds: contributors[p.id] ?? const {},
          roomName: p.roomId == null ? null : roomNames[p.roomId],
        ),
  ];
  views.sort((a, b) {
    if (a.isPersonal != b.isPersonal) return a.isPersonal ? -1 : 1;
    return a.pot.createdAt.compareTo(b.pot.createdAt);
  });
  return views;
}
