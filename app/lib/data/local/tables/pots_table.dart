import 'package:drift/drift.dart';
import 'profiles_table.dart';
import 'rooms_table.dart';

class PotsTable extends Table {
  @override
  String get tableName => 'pots';

  TextColumn     get id                 => text()();
  TextColumn     get name               => text()();
  TextColumn     get description        => text().nullable()();
  TextColumn     get ownerType          => text()(); // 'personal' | 'group'
  TextColumn     get userId             => text().nullable().references(ProfilesTable, #id)();
  TextColumn     get roomId             => text().nullable().references(RoomsTable, #id)();
  Int64Column    get targetAmountPaise  => int64().nullable()();
  DateTimeColumn get targetDate         => dateTime().nullable()();
  TextColumn     get icon               => text().withDefault(const Constant('savings'))();
  TextColumn     get gradientStart      => text().withDefault(const Constant('#F2A73B'))();
  TextColumn     get gradientEnd        => text().withDefault(const Constant('#E8962A'))();
  DateTimeColumn get createdAt          => dateTime()();
  DateTimeColumn get updatedAt          => dateTime()();
  DateTimeColumn get deletedAt          => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PotContributionsTable extends Table {
  @override
  String get tableName => 'pot_contributions';

  TextColumn     get id           => text()(); // = op_id
  TextColumn     get potId        => text().references(PotsTable, #id)();
  TextColumn     get userId       => text().references(ProfilesTable, #id)();
  Int64Column    get amountPaise  => int64()();
  DateTimeColumn get createdAt    => dateTime()();
  DateTimeColumn get updatedAt    => dateTime()();
  DateTimeColumn get deletedAt    => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
