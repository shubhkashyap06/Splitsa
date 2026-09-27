import 'package:drift/drift.dart';
import 'profiles_table.dart';
import 'rooms_table.dart';

class ExpensesTable extends Table {
  @override
  String get tableName => 'expenses';

  TextColumn     get id           => text()();
  TextColumn     get roomId       => text().references(RoomsTable, #id)();
  TextColumn     get paidBy       => text().references(ProfilesTable, #id)();
  TextColumn     get description  => text()();
  Int64Column    get amountPaise  => int64()();
  TextColumn     get category     => text().withDefault(const Constant('other'))();
  TextColumn     get subCategory  => text().nullable()();
  TextColumn     get splitMode    => text().withDefault(const Constant('equal'))();
  DateTimeColumn get createdAt    => dateTime()();
  DateTimeColumn get updatedAt    => dateTime()();
  DateTimeColumn get deletedAt    => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpenseSplitsTable extends Table {
  @override
  String get tableName => 'expense_splits';

  TextColumn     get id           => text()();
  TextColumn     get expenseId    => text().references(ExpensesTable, #id)();
  TextColumn     get userId       => text().references(ProfilesTable, #id)();
  Int64Column    get amountPaise  => int64()();
  DateTimeColumn get createdAt    => dateTime()();
  DateTimeColumn get updatedAt    => dateTime()();
  DateTimeColumn get deletedAt    => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonalExpensesTable extends Table {
  @override
  String get tableName => 'personal_expenses';

  TextColumn     get id           => text()();
  TextColumn     get userId       => text().references(ProfilesTable, #id)();
  TextColumn     get description  => text()();
  Int64Column    get amountPaise  => int64()();
  TextColumn     get category     => text().withDefault(const Constant('other'))();
  TextColumn     get subCategory  => text().nullable()();
  DateTimeColumn get createdAt    => dateTime()();
  DateTimeColumn get updatedAt    => dateTime()();
  DateTimeColumn get deletedAt    => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SettlementsTable extends Table {
  @override
  String get tableName => 'settlements';

  TextColumn     get id           => text()(); // = op_id
  TextColumn     get roomId       => text().references(RoomsTable, #id)();
  TextColumn     get payerId      => text().references(ProfilesTable, #id)();
  TextColumn     get payeeId      => text().references(ProfilesTable, #id)();
  Int64Column    get amountPaise  => int64()();
  DateTimeColumn get createdAt    => dateTime()();
  DateTimeColumn get updatedAt    => dateTime()();
  DateTimeColumn get deletedAt    => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
