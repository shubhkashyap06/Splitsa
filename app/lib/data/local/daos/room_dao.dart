import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/rooms_table.dart';
import '../tables/profiles_table.dart';

part 'room_dao.g.dart';

@DriftAccessor(tables: [RoomsTable, RoomMembersTable, RoomInvitesTable, ProfilesTable])
class RoomDao extends DatabaseAccessor<AppDatabase> with _$RoomDaoMixin {
  RoomDao(super.db);

  // ── Rooms ────────────────────────────────────────────────────────────────

  /// All rooms the current user is a member of (not soft-deleted).
  Future<List<RoomsTableData>> getRoomsForUser(String userId) {
    final query = select(roomsTable).join([
      innerJoin(roomMembersTable, roomMembersTable.roomId.equalsExp(roomsTable.id)),
    ])
      ..where(roomMembersTable.userId.equals(userId))
      ..where(roomsTable.deletedAt.isNull())
      ..where(roomMembersTable.deletedAt.isNull());
    return query.map((row) => row.readTable(roomsTable)).get();
  }

  Stream<List<RoomsTableData>> watchRoomsForUser(String userId) {
    final query = select(roomsTable).join([
      innerJoin(roomMembersTable, roomMembersTable.roomId.equalsExp(roomsTable.id)),
    ])
      ..where(roomMembersTable.userId.equals(userId))
      ..where(roomsTable.deletedAt.isNull())
      ..where(roomMembersTable.deletedAt.isNull());
    return query.map((row) => row.readTable(roomsTable)).watch();
  }

  Future<RoomsTableData?> getRoom(String roomId) =>
      (select(roomsTable)..where((t) => t.id.equals(roomId))).getSingleOrNull();

  Future<void> upsertRoom(RoomsTableCompanion companion) =>
      into(roomsTable).insertOnConflictUpdate(companion);

  // ── Room members ─────────────────────────────────────────────────────────

  Future<List<RoomMembersTableData>> getMembersForRoom(String roomId) =>
      (select(roomMembersTable)
        ..where((t) => t.roomId.equals(roomId))
        ..where((t) => t.deletedAt.isNull()))
          .get();

  Stream<List<RoomMembersTableData>> watchMembersForRoom(String roomId) =>
      (select(roomMembersTable)
        ..where((t) => t.roomId.equals(roomId))
        ..where((t) => t.deletedAt.isNull()))
          .watch();

  Future<void> upsertMember(RoomMembersTableCompanion companion) =>
      into(roomMembersTable).insertOnConflictUpdate(companion);

  Future<bool> isMember(String roomId, String userId) async {
    final row = await (select(roomMembersTable)
      ..where((t) => t.roomId.equals(roomId))
      ..where((t) => t.userId.equals(userId))
      ..where((t) => t.deletedAt.isNull()))
        .getSingleOrNull();
    return row != null;
  }

  // ── Invites ──────────────────────────────────────────────────────────────

  Future<void> upsertInvite(RoomInvitesTableCompanion companion) =>
      into(roomInvitesTable).insertOnConflictUpdate(companion);
}
