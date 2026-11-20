/// Sample data for demo mode (`--dart-define=DEMO=true`, dev builds only).
///
/// Written straight into the local tables — not the outbox — so it looks
/// like data that already synced. Dates are relative to "now" so the
/// insights, nudge and spending summary always have a current week to show.
library;

import '../../core/utils/split_amount.dart';
import '../remote/demo_gateway.dart';
import 'database.dart';

const _aditi = '019a0000-0000-7000-8000-00000000d002';
const _kabir = '019a0000-0000-7000-8000-00000000d003';
const _meera = '019a0000-0000-7000-8000-00000000d004';
const _flat = '019a0000-0000-7000-8000-0000000f1a70';
const _goa = '019a0000-0000-7000-8000-00000000609a';

Future<void> seedDemoData(AppDatabase db) async {
  final existing = await db.profileDao.getProfile(kDemoUserId);
  if (existing != null) return; // already seeded on a previous launch

  final now = DateTime.now();
  DateTime ago(int days, {int hour = 13}) => DateTime(
    now.year,
    now.month,
    now.day,
    hour,
  ).subtract(Duration(days: days));
  var seq = 0;
  String id(String p) =>
      '019a0000-0000-7000-8000-${p.padLeft(6, '0')}${(seq++).toString().padLeft(6, '0')}';

  await db.transaction(() async {
    // ── People ───────────────────────────────────────────────────────────
    for (final (pid, name, upi) in [
      (kDemoUserId, 'Shubh', 'shubh@okaxis'),
      (_aditi, 'Aditi', 'aditi@okicici'),
      (_kabir, 'Kabir', 'kabir@ybl'),
      (_meera, 'Meera', 'meera@oksbi'),
    ]) {
      await db
          .into(db.profilesTable)
          .insert(
            ProfilesTableData(
              id: pid,
              displayName: name,
              upiId: upi,
              email: pid == kDemoUserId ? kDemoEmail : null,
              notificationsRegularEnabled: true,
              monthlyBudgetPaise: pid == kDemoUserId ? 3000000 : null,
              createdAt: ago(200),
              updatedAt: ago(200),
            ),
          );
    }

    // ── Rooms ────────────────────────────────────────────────────────────
    final rooms = {
      _flat: ('Flat 4B', 'house', [kDemoUserId, _aditi, _kabir]),
      _goa: ('Goa Trip', 'trip', [kDemoUserId, _aditi, _kabir, _meera]),
    };
    for (final MapEntry(key: rid, value: (name, icon, members))
        in rooms.entries) {
      await db
          .into(db.roomsTable)
          .insert(
            RoomsTableData(
              id: rid,
              name: name,
              icon: icon,
              createdBy: kDemoUserId,
              createdAt: ago(60),
              updatedAt: ago(60),
            ),
          );
      for (final m in members) {
        await db
            .into(db.roomMembersTable)
            .insert(
              RoomMembersTableData(
                id: id('m'),
                roomId: rid,
                userId: m,
                joinedAt: ago(60),
                updatedAt: ago(60),
              ),
            );
      }
    }

    // ── Shared expenses (equal splits, remainder on payer) ───────────────
    Future<void> shared(
      String room,
      String payer,
      String desc,
      int rupees,
      String cat,
      int daysAgo,
    ) async {
      final members = rooms[room]!.$3;
      final eid = id('e');
      final total = rupees * 100;
      await db
          .into(db.expensesTable)
          .insert(
            ExpensesTableData(
              id: eid,
              roomId: room,
              paidBy: payer,
              description: desc,
              amountPaise: total,
              category: cat,
              splitMode: 'equal',
              createdAt: ago(daysAgo),
              updatedAt: ago(daysAgo),
            ),
          );
      final shares = splitAmount(total, members.length, members.indexOf(payer));
      for (var i = 0; i < members.length; i++) {
        await db
            .into(db.expenseSplitsTable)
            .insert(
              ExpenseSplitsTableData(
                id: id('s'),
                expenseId: eid,
                userId: members[i],
                amountPaise: shares[i],
                createdAt: ago(daysAgo),
                updatedAt: ago(daysAgo),
              ),
            );
      }
    }

    await shared(_flat, _aditi, 'November rent', 36000, 'rent', 19);
    await shared(_flat, kDemoUserId, 'WiFi bill', 999, 'wifi', 17);
    await shared(_flat, _kabir, 'Groceries — BigBasket', 2340, 'food', 12);
    await shared(_flat, kDemoUserId, 'Electricity', 1860, 'electricity', 9);
    await shared(_flat, _aditi, 'Pizza night', 1350, 'food', 4);
    await shared(_flat, _kabir, 'Milk & eggs', 420, 'food', 1);

    await shared(_goa, kDemoUserId, 'Villa booking', 18000, 'travel', 26);
    await shared(_goa, _meera, 'Airport cab', 1240, 'travel', 24);
    await shared(_goa, _aditi, 'Beach shack dinner', 3800, 'food', 23);
    await shared(_goa, _kabir, 'Scooter rentals', 2400, 'travel', 22);

    // One settle-up already happened.
    await db
        .into(db.settlementsTable)
        .insert(
          SettlementsTableData(
            id: id('t'),
            roomId: _goa,
            payerId: _meera,
            payeeId: kDemoUserId,
            amountPaise: 300000,
            createdAt: ago(15),
            updatedAt: ago(15),
          ),
        );

    // ── Personal spends: weekend-heavy, and this week came in light ──────
    final personal = <(int, String, int, String)>[
      (34, 'Movie + popcorn', 680, 'entertainment'),
      (33, 'Zomato', 450, 'food'),
      (29, 'Gym membership', 1800, 'health'),
      (27, 'Brunch', 1100, 'food'),
      (26, 'Concert tickets', 2200, 'entertainment'),
      (22, 'Swiggy', 380, 'food'),
      (20, 'Saturday shopping', 2600, 'shopping'),
      (19, 'Cafe', 540, 'food'),
      (15, 'Uber', 320, 'travel'),
      (13, 'Weekend dinner', 1450, 'food'),
      (12, 'Bowling', 900, 'entertainment'),
      (8, 'Medicines', 260, 'health'),
      (6, 'Saturday market', 1700, 'shopping'),
      (5, 'Late-night Zomato', 520, 'food'),
      (2, 'Chai + samosa', 80, 'food'),
      (1, 'Metro card top-up', 300, 'travel'),
    ];
    for (final (d, desc, rupees, cat) in personal) {
      await db
          .into(db.personalExpensesTable)
          .insert(
            PersonalExpensesTableData(
              id: id('p'),
              userId: kDemoUserId,
              description: desc,
              amountPaise: rupees * 100,
              category: cat,
              createdAt: ago(d, hour: 20),
              updatedAt: ago(d, hour: 20),
            ),
          );
    }

    // ── Pots ─────────────────────────────────────────────────────────────
    Future<void> pot(
      String name,
      String? room,
      int? target,
      String g1,
      String g2,
      List<(String, int, int)> adds,
    ) async {
      final pid = id('k');
      await db
          .into(db.potsTable)
          .insert(
            PotsTableData(
              id: pid,
              name: name,
              ownerType: room == null ? 'personal' : 'group',
              userId: kDemoUserId,
              roomId: room,
              targetAmountPaise: target == null ? null : target * 100,
              icon: 'savings',
              gradientStart: g1,
              gradientEnd: g2,
              createdAt: ago(90),
              updatedAt: ago(90),
            ),
          );
      for (final (who, rupees, d) in adds) {
        await db
            .into(db.potContributionsTable)
            .insert(
              PotContributionsTableData(
                id: id('c'),
                potId: pid,
                userId: who,
                amountPaise: rupees * 100,
                createdAt: ago(d),
                updatedAt: ago(d),
              ),
            );
      }
    }

    await pot('Rainy Day Fund', null, 50000, '#2F9E8F', '#1F6F65', [
      (kDemoUserId, 25000, 80),
      (kDemoUserId, 4000, 40),
      (kDemoUserId, 2000, 3),
    ]);
    await pot('Goa Trip 2.0', _goa, 50000, '#F2A73B', '#E8763C', [
      (kDemoUserId, 8000, 30),
      (_aditi, 9000, 28),
      (_kabir, 7000, 20),
      (_meera, 7000, 10),
    ]);
    await pot('PS5 Fund', null, 45000, '#7A86FF', '#5A66FF', [
      (kDemoUserId, 12000, 45),
    ]);
  });
}
