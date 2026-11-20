/// Registry of every table the sync engine moves between Drift and Supabase,
/// with hand-written mappers between local rows and the remote (snake_case)
/// JSON shape. Hand-written on purpose: the remote shape is the API contract
/// with Postgres, and a codegen'd camelCase `toJson()` would silently drift.
///
/// Order matters — pulls run in this order so parents land before children.
library;

import 'package:drift/drift.dart';

import '../local/database.dart';
import '../remote/remote_gateway.dart' show Json;

class SyncedTable<D> {
  const SyncedTable({
    required this.name,
    required this.table,
    required this.fromRemote,
    required this.toRemote,
    required this.idOf,
    this.pushable = true,
  });

  /// Remote (and local) table name.
  final String name;
  final TableInfo<Table, D> Function(AppDatabase db) table;
  final Insertable<D> Function(Json json) fromRemote;
  final Json Function(D row) toRemote;
  final String Function(D row) idOf;

  /// False for tables only the server writes (settlements → settle-intent).
  final bool pushable;

  Future<void> upsertRemote(AppDatabase db, Json json) =>
      db.into(table(db)).insertOnConflictUpdate(fromRemote(json));
}

// ── Parsing helpers ─────────────────────────────────────────────────────────

DateTime _dt(Object? v) => DateTime.parse(v! as String);
DateTime? _dtn(Object? v) => v == null ? null : DateTime.parse(v as String);
int _int(Object? v) => (v! as num).toInt();
int? _intn(Object? v) => (v as num?)?.toInt();
String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

/// `TIME` columns arrive as "HH:MM:SS"; the app stores "HH:MM".
String? _hhmm(Object? v) {
  if (v is! String || v.length < 5) return null;
  return v.substring(0, 5);
}

String? _dateOnly(DateTime? d) => d?.toIso8601String().substring(0, 10);

// ── Tables ─────────────────────────────────────────────────────────────────

final profilesSync = SyncedTable<ProfilesTableData>(
  name: 'profiles',
  table: (db) => db.profilesTable,
  idOf: (r) => r.id,
  fromRemote: (j) => ProfilesTableCompanion.insert(
    id: j['id'] as String,
    displayName: j['display_name'] as String,
    avatarUrl: Value(j['avatar_url'] as String?),
    upiId: Value(j['upi_id'] as String?),
    email: Value(j['email'] as String?),
    notificationsRegularEnabled: Value(
      j['notifications_regular_enabled'] as bool? ?? true,
    ),
    quietHoursStart: Value(_hhmm(j['quiet_hours_start'])),
    quietHoursEnd: Value(_hhmm(j['quiet_hours_end'])),
    monthlyBudgetPaise: Value(_intn(j['monthly_budget_paise'])),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  // Only the user-editable fields — never email/created_at.
  toRemote: (r) => {
    'id': r.id,
    'display_name': r.displayName,
    'upi_id': r.upiId,
    'notifications_regular_enabled': r.notificationsRegularEnabled,
    'quiet_hours_start': r.quietHoursStart,
    'quiet_hours_end': r.quietHoursEnd,
    'monthly_budget_paise': r.monthlyBudgetPaise,
  },
);

final roomsSync = SyncedTable<RoomsTableData>(
  name: 'rooms',
  table: (db) => db.roomsTable,
  idOf: (r) => r.id,
  fromRemote: (j) => RoomsTableCompanion.insert(
    id: j['id'] as String,
    name: j['name'] as String,
    description: Value(j['description'] as String?),
    icon: Value(j['icon'] as String? ?? 'house'),
    createdBy: j['created_by'] as String,
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => {
    'id': r.id,
    'name': r.name,
    'description': r.description,
    'icon': r.icon,
    'created_by': r.createdBy,
    'created_at': _iso(r.createdAt),
    'deleted_at': _iso(r.deletedAt),
  },
);

final roomMembersSync = SyncedTable<RoomMembersTableData>(
  name: 'room_members',
  table: (db) => db.roomMembersTable,
  idOf: (r) => r.id,
  fromRemote: (j) => RoomMembersTableCompanion.insert(
    id: j['id'] as String,
    roomId: j['room_id'] as String,
    userId: j['user_id'] as String,
    joinedAt: _dt(j['joined_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => {
    'id': r.id,
    'room_id': r.roomId,
    'user_id': r.userId,
    'joined_at': _iso(r.joinedAt),
    'deleted_at': _iso(r.deletedAt),
  },
);

final expensesSync = SyncedTable<ExpensesTableData>(
  name: 'expenses',
  table: (db) => db.expensesTable,
  idOf: (r) => r.id,
  fromRemote: (j) => ExpensesTableCompanion.insert(
    id: j['id'] as String,
    roomId: j['room_id'] as String,
    paidBy: j['paid_by'] as String,
    description: j['description'] as String,
    amountPaise: _int(j['amount_paise']),
    category: Value(j['category'] as String? ?? 'other'),
    subCategory: Value(j['sub_category'] as String?),
    splitMode: Value(j['split_mode'] as String? ?? 'equal'),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => {
    'id': r.id,
    'room_id': r.roomId,
    'paid_by': r.paidBy,
    'description': r.description,
    'amount_paise': r.amountPaise,
    'category': r.category,
    'sub_category': r.subCategory,
    'split_mode': r.splitMode,
    'created_at': _iso(r.createdAt),
    'deleted_at': _iso(r.deletedAt),
  },
);

final expenseSplitsSync = SyncedTable<ExpenseSplitsTableData>(
  name: 'expense_splits',
  table: (db) => db.expenseSplitsTable,
  idOf: (r) => r.id,
  fromRemote: (j) => ExpenseSplitsTableCompanion.insert(
    id: j['id'] as String,
    expenseId: j['expense_id'] as String,
    userId: j['user_id'] as String,
    amountPaise: _int(j['amount_paise']),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => {
    'id': r.id,
    'expense_id': r.expenseId,
    'user_id': r.userId,
    'amount_paise': r.amountPaise,
    'created_at': _iso(r.createdAt),
    'deleted_at': _iso(r.deletedAt),
  },
);

final personalExpensesSync = SyncedTable<PersonalExpensesTableData>(
  name: 'personal_expenses',
  table: (db) => db.personalExpensesTable,
  idOf: (r) => r.id,
  fromRemote: (j) => PersonalExpensesTableCompanion.insert(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    description: j['description'] as String,
    amountPaise: _int(j['amount_paise']),
    category: Value(j['category'] as String? ?? 'other'),
    subCategory: Value(j['sub_category'] as String?),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => {
    'id': r.id,
    'user_id': r.userId,
    'description': r.description,
    'amount_paise': r.amountPaise,
    'category': r.category,
    'sub_category': r.subCategory,
    'created_at': _iso(r.createdAt),
    'deleted_at': _iso(r.deletedAt),
  },
);

final settlementsSync = SyncedTable<SettlementsTableData>(
  name: 'settlements',
  table: (db) => db.settlementsTable,
  idOf: (r) => r.id,
  pushable: false,
  fromRemote: (j) => SettlementsTableCompanion.insert(
    id: j['id'] as String,
    roomId: j['room_id'] as String,
    payerId: j['payer_id'] as String,
    payeeId: j['payee_id'] as String,
    amountPaise: _int(j['amount_paise']),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => throw UnsupportedError(
    'settlements are only created via the settle-intent Edge Function',
  ),
);

final potsSync = SyncedTable<PotsTableData>(
  name: 'pots',
  table: (db) => db.potsTable,
  idOf: (r) => r.id,
  fromRemote: (j) => PotsTableCompanion.insert(
    id: j['id'] as String,
    name: j['name'] as String,
    description: Value(j['description'] as String?),
    ownerType: j['owner_type'] as String,
    userId: Value(j['user_id'] as String?),
    roomId: Value(j['room_id'] as String?),
    targetAmountPaise: Value(_intn(j['target_amount_paise'])),
    targetDate: Value(_dtn(j['target_date'])),
    icon: Value(j['icon'] as String? ?? 'savings'),
    gradientStart: Value(j['gradient_start'] as String? ?? '#F2A73B'),
    gradientEnd: Value(j['gradient_end'] as String? ?? '#E8962A'),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => {
    'id': r.id,
    'name': r.name,
    'description': r.description,
    'owner_type': r.ownerType,
    'user_id': r.userId,
    'room_id': r.roomId,
    'target_amount_paise': r.targetAmountPaise,
    'target_date': _dateOnly(r.targetDate),
    'icon': r.icon,
    'gradient_start': r.gradientStart,
    'gradient_end': r.gradientEnd,
    'created_at': _iso(r.createdAt),
    'deleted_at': _iso(r.deletedAt),
  },
);

final potContributionsSync = SyncedTable<PotContributionsTableData>(
  name: 'pot_contributions',
  table: (db) => db.potContributionsTable,
  idOf: (r) => r.id,
  fromRemote: (j) => PotContributionsTableCompanion.insert(
    id: j['id'] as String,
    potId: j['pot_id'] as String,
    userId: j['user_id'] as String,
    amountPaise: _int(j['amount_paise']),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    deletedAt: Value(_dtn(j['deleted_at'])),
  ),
  toRemote: (r) => {
    'id': r.id,
    'pot_id': r.potId,
    'user_id': r.userId,
    'amount_paise': r.amountPaise,
    'created_at': _iso(r.createdAt),
    'deleted_at': _iso(r.deletedAt),
  },
);

/// Pull order: parents before children.
final List<SyncedTable<dynamic>> kSyncedTables = [
  profilesSync,
  roomsSync,
  roomMembersSync,
  expensesSync,
  expenseSplitsSync,
  personalExpensesSync,
  settlementsSync,
  potsSync,
  potContributionsSync,
];

SyncedTable<dynamic> syncedTableNamed(String name) =>
    kSyncedTables.firstWhere((t) => t.name == name);
