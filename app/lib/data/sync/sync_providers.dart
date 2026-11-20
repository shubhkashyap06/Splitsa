import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local/database.dart';
import '../remote/session.dart';
import 'sync_engine.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) {
  final engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    remote: ref.watch(remoteGatewayProvider),
    currentUserId: () => ref.read(currentUserIdProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
}

/// SyncScheduler — decides *when* to sync (OFFLINE_SYNC.md §3 step 1):
/// on sign-in, on app resume, every 60s while foregrounded, and shortly
/// after any local write (debounced, so a burst of writes is one push).
///
/// On the PWA this foreground cadence is the whole story — iOS Safari gives
/// installed PWAs no reliable background execution (documented limitation).
class SyncScheduler {
  SyncScheduler(this._engine) {
    _periodic = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _engine.sync(),
    );
    _lifecycle = AppLifecycleListener(
      onResume: () => _engine.sync(force: true),
    );
  }

  final SyncEngine _engine;
  late final Timer _periodic;
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;

  /// Call after a local write; pushes ~1s later.
  void kick() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _engine.sync);
  }

  Future<void> syncNow() => _engine.sync(force: true);

  void dispose() {
    _periodic.cancel();
    _debounce?.cancel();
    _lifecycle.dispose();
  }
}

@Riverpod(keepAlive: true)
SyncScheduler syncScheduler(Ref ref) {
  final scheduler = SyncScheduler(ref.watch(syncEngineProvider));
  ref.onDispose(scheduler.dispose);

  // Sync as soon as a session exists (cold start with a cached session, or
  // a fresh sign-in).
  ref.listen<String?>(currentUserIdProvider, (prev, next) {
    if (next != null && next != prev) scheduler.syncNow();
  }, fireImmediately: true);

  return scheduler;
}

@riverpod
Stream<SyncStatus> syncStatus(Ref ref) async* {
  final engine = ref.watch(syncEngineProvider);
  yield engine.status;
  yield* engine.statusStream;
}

/// Row ids with an unsynced local write — drives the "pending" marker.
@riverpod
Stream<Set<String>> pendingRowIds(Ref ref) =>
    ref.watch(appDatabaseProvider).syncDao.watchPendingRowIds();
