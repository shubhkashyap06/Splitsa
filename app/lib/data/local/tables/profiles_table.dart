import 'package:drift/drift.dart';

/// Local mirror of the `profiles` Supabase table.
/// id is a UUIDv7 string (client-generated), matching the remote primary key.
class ProfilesTable extends Table {
  @override
  String get tableName => 'profiles';

  TextColumn  get id                         => text()();
  TextColumn  get displayName                => text()();
  TextColumn  get avatarUrl                  => text().nullable()();
  TextColumn  get upiId                      => text().nullable()();
  TextColumn  get email                      => text().nullable()();
  BoolColumn  get notificationsRegularEnabled => boolean().withDefault(const Constant(true))();
  TextColumn  get quietHoursStart            => text().nullable()(); // "HH:MM"
  TextColumn  get quietHoursEnd              => text().nullable()(); // "HH:MM"
  DateTimeColumn get createdAt               => dateTime()();
  DateTimeColumn get updatedAt               => dateTime()();
  DateTimeColumn get deletedAt               => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
