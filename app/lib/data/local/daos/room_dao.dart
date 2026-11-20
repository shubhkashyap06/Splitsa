import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/profiles_table.dart';
import '../tables/rooms_table.dart';

part 'room_dao.g.dart';

@DriftAccessor(
  tables: [RoomsTable, RoomMembersTable, RoomInvitesTable, ProfilesTable],
)
class RoomDao extends DatabaseAccessor<AppDatabase> with _$RoomDaoMixin {
  RoomDao(super.db);

  /// Rooms [userId] is an active member of, newest first.
  Stream<List<RoomsTableData>> watchRoomsForUser(String userId) {
    final query =
        select(roomsTable).join([
            innerJoin(
              roomMembersTable,
              roomMembersTable.roomId.equalsExp(roomsTable.id),
            ),
          ])
          ..where(roomMembersTable.userId.equals(userId))
          ..where(roomsTable.deletedAt.isNull())
          ..where(roomMembersTable.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(roomsTable.createdAt)]);
    return query.map((row) => row.readTable(roomsTable)).watch();
  }

  Future<RoomsTableData?> getRoom(String roomId) =>
      (select(roomsTable)..where((t) => t.id.equals(roomId))).getSingleOrNull();

  /// Every active membership row in the local DB (all of the user's rooms).
  Stream<List<RoomMembersTableData>> watchAllMembers() =>
      (select(roomMembersTable)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<RoomMembersTableData>> getMembersForRoom(String roomId) =>
      (select(roomMembersTable)
            ..where((t) => t.roomId.equals(roomId))
            ..where((t) => t.deletedAt.isNull()))
          .get();

  Future<bool> isMember(String roomId, String userId) async {
    final row =
        await (select(roomMembersTable)
              ..where((t) => t.roomId.equals(roomId))
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull()))
            .getSingleOrNull();
    return row != null;
  }
}
