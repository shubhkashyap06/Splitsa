/// RemoteGateway — the only surface the sync engine and repositories use to
/// talk to Supabase. Abstract so the engine is unit-testable with a fake,
/// and so no widget/provider can reach PostgREST directly (OFFLINE_SYNC.md
/// rule 1: the UI never blocks on the network).
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

/// How a failed remote call should be treated by the outbox.
enum RemoteFailureKind {
  /// Network down, timeout, 5xx, 429 — stop draining and back off.
  transient,

  /// The server will never accept this payload as-is (RLS, constraint,
  /// validation). Count it toward the dead-letter limit and move on.
  permanent,

  /// Session expired/revoked — fail closed: stop syncing, force re-auth.
  unauthorized,
}

class RemoteFailure implements Exception {
  const RemoteFailure(this.kind, this.message, {this.status, this.body});
  final RemoteFailureKind kind;
  final String message;
  final int? status;
  final Json? body;

  @override
  String toString() => 'RemoteFailure($kind, $status, $message)';
}

abstract class RemoteGateway {
  /// Plain INSERT (no RETURNING, so it doesn't need SELECT rights on the new
  /// row). A duplicate primary key counts as success — the op_id/row id is
  /// the idempotency key, so a replayed insert is a no-op.
  Future<void> insert(String table, Json row);

  /// UPDATE … WHERE id = [id].
  Future<void> update(String table, String id, Json values);

  /// Rows with `updated_at > since`, oldest first, at most [limit].
  Future<List<Json>> fetchSince(String table, DateTime? since, int limit);

  /// Rows whose [column] is in [values] — used to backfill a newly joined
  /// room, whose history is older than our delta watermark.
  Future<List<Json>> fetchWhereIn(
    String table,
    String column,
    List<String> values,
  );

  /// Calls an Edge Function and returns its JSON body. Non-2xx responses
  /// throw a [RemoteFailure] carrying the status and decoded body.
  Future<Json> invoke(String function, Json body);
}

class SupabaseRemoteGateway implements RemoteGateway {
  SupabaseRemoteGateway(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  @override
  Future<void> insert(String table, Json row) => _guard(() async {
    try {
      await _client.from(table).insert(row).timeout(_timeout);
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already applied — idempotent replay
      rethrow;
    }
  });

  @override
  Future<void> update(String table, String id, Json values) => _guard(
    () => _client.from(table).update(values).eq('id', id).timeout(_timeout),
  );

  @override
  Future<List<Json>> fetchSince(String table, DateTime? since, int limit) =>
      _guard(() async {
        var query = _client.from(table).select();
        if (since != null) {
          query = query.gt('updated_at', since.toUtc().toIso8601String());
        }
        final rows = await query
            .order('updated_at', ascending: true)
            .limit(limit)
            .timeout(_timeout);
        return List<Json>.from(rows);
      });

  @override
  Future<List<Json>> fetchWhereIn(
    String table,
    String column,
    List<String> values,
  ) => _guard(() async {
    if (values.isEmpty) return <Json>[];
    final rows = await _client
        .from(table)
        .select()
        .inFilter(column, values)
        .timeout(_timeout);
    return List<Json>.from(rows);
  });

  @override
  Future<Json> invoke(String function, Json body) => _guard(() async {
    try {
      final res = await _client.functions
          .invoke(function, body: body)
          .timeout(_timeout);
      final data = res.data;
      return data is Map ? Json.from(data) : <String, dynamic>{};
    } on FunctionException catch (e) {
      final details = e.details;
      final decoded = details is Map ? Json.from(details) : null;
      throw RemoteFailure(
        _kindForStatus(e.status),
        decoded?['error'] as String? ?? 'Request failed (${e.status})',
        status: e.status,
        body: decoded,
      );
    }
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on RemoteFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw RemoteFailure(_kindForPostgres(e), e.message);
    } on AuthException catch (e) {
      throw RemoteFailure(RemoteFailureKind.unauthorized, e.message);
    } on TimeoutException {
      throw const RemoteFailure(RemoteFailureKind.transient, 'Timed out');
    } on http.ClientException catch (e) {
      // IOClient wraps SocketException in ClientException, so this also
      // covers "no network" on Android without importing dart:io (PWA-safe).
      throw RemoteFailure(RemoteFailureKind.transient, e.message);
    }
  }

  static RemoteFailureKind _kindForStatus(int status) {
    if (status == 401) return RemoteFailureKind.unauthorized;
    if (status == 429 || status >= 500) return RemoteFailureKind.transient;
    return RemoteFailureKind.permanent;
  }

  static RemoteFailureKind _kindForPostgres(PostgrestException e) {
    final code = e.code ?? '';
    // PGRST301/303: JWT expired/invalid.
    if (code == 'PGRST301' || code == 'PGRST303') {
      return RemoteFailureKind.unauthorized;
    }
    // Class 23 (integrity), 42501 (RLS), 22 (data exception), PGRST1xx/2xx
    // (bad request shape) — retrying the same payload won't help.
    if (code.startsWith('23') ||
        code.startsWith('22') ||
        code == '42501' ||
        code.startsWith('PGRST1') ||
        code.startsWith('PGRST2')) {
      return RemoteFailureKind.permanent;
    }
    return RemoteFailureKind.transient;
  }
}
