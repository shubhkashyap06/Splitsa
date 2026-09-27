import 'package:drift/drift.dart';
import 'profiles_table.dart';

class RoomsTable extends Table {
  @override
  String get tableName => 'rooms';

  TextColumn     get id          => text()();
  TextColumn     get name        => text()();
  TextColumn     get description => text().nullable()();
  TextColumn     get icon        => text().withDefault(const Constant('house'))();
  TextColumn     get createdBy   => text().references(ProfilesTable, #id)();
  DateTimeColumn get createdAt   => dateTime()();
  DateTimeColumn get updatedAt   => dateTime()();
  DateTimeColumn get deletedAt   => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RoomMembersTable extends Table {
  @override
  String get tableName => 'room_members';

  TextColumn     get id        => text()();
  TextColumn     get roomId    => text().references(RoomsTable, #id)();
  TextColumn     get userId    => text().references(ProfilesTable, #id)();
  DateTimeColumn get joinedAt  => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RoomInvitesTable extends Table {
  @override
  String get tableName => 'room_invites';

  TextColumn     get id          => text()();
  TextColumn     get roomId      => text().references(RoomsTable, #id)();
  TextColumn     get token       => text()();
  TextColumn     get displayCode => text()();
  TextColumn     get createdBy   => text().references(ProfilesTable, #id)();
  DateTimeColumn get expiresAt   => dateTime()();
  IntColumn      get maxUses     => integer().withDefault(const Constant(10))();
  IntColumn      get usedCount   => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt   => dateTime()();
  DateTimeColumn get updatedAt   => dateTime()();
  DateTimeColumn get deletedAt   => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
