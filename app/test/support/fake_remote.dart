import 'package:drift/native.dart';
import 'package:splitsa/data/local/database.dart';
import 'package:splitsa/data/remote/remote_gateway.dart';

AppDatabase memoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// In-memory stand-in for Supabase. Behaves like the real server where it
/// matters to the sync engine: duplicate-id inserts are no-ops (idempotent),
/// updated_at is server-assigned and strictly increasing, and the network
/// can be switched off.
class FakeRemote implements RemoteGateway {
  final Map<String, Map<String, Json>> tables = {};
  bool online = true;

  /// Row ids whose writes the "server" always rejects (RLS/constraint).
  final Set<String> rejectIds = {};

  /// Every write call, in order, as "op:table:id" — for asserting FIFO.
  final List<String> calls = [];
  int insertAttempts = 0;

  DateTime _clock = DateTime.utc(2026, 11, 1);
  String _nextTimestamp() {
    _clock = _clock.add(const Duration(milliseconds: 1));
    return _clock.toIso8601String();
  }

  void _checkOnline() {
    if (!online) {
      throw const RemoteFailure(RemoteFailureKind.transient, 'offline');
    }
  }

  /// Seeds a row as if another client had written it.
  void seed(String table, Json row) {
    tables.putIfAbsent(table, () => {})[row['id'] as String] = {
      'created_at': _nextTimestamp(),
      ...row,
      'updated_at': row['updated_at'] ?? _nextTimestamp(),
    };
  }

  @override
  Future<void> insert(String table, Json row) async {
    _checkOnline();
    insertAttempts++;
    final id = row['id'] as String;
    calls.add('insert:$table:$id');
    if (rejectIds.contains(id)) {
      throw const RemoteFailure(RemoteFailureKind.permanent, 'rejected');
    }
    final t = tables.putIfAbsent(table, () => {});
    if (t.containsKey(id)) return; // duplicate PK → idempotent no-op
    t[id] = {...row, 'updated_at': _nextTimestamp()};
  }

  @override
  Future<void> update(String table, String id, Json values) async {
    _checkOnline();
    calls.add('update:$table:$id');
    if (rejectIds.contains(id)) {
      throw const RemoteFailure(RemoteFailureKind.permanent, 'rejected');
    }
    final row = tables[table]?[id];
    if (row == null) return;
    row
      ..addAll(values)
      ..['updated_at'] = _nextTimestamp();
  }

  @override
  Future<List<Json>> fetchSince(
    String table,
    DateTime? since,
    int limit,
  ) async {
    _checkOnline();
    final rows =
        (tables[table]?.values ?? const <Json>[])
            .where(
              (r) =>
                  since == null ||
                  DateTime.parse(r['updated_at'] as String).isAfter(since),
            )
            .toList()
          ..sort(
            (a, b) => (a['updated_at'] as String).compareTo(
              b['updated_at'] as String,
            ),
          );
    return rows.take(limit).map(Json.from).toList();
  }

  @override
  Future<List<Json>> fetchWhereIn(
    String table,
    String column,
    List<String> values,
  ) async {
    _checkOnline();
    return (tables[table]?.values ?? const <Json>[])
        .where((r) => values.contains(r[column]))
        .map(Json.from)
        .toList();
  }

  @override
  Future<Json> invoke(String function, Json body) async {
    _checkOnline();
    throw UnimplementedError('invoke($function) not faked');
  }
}
