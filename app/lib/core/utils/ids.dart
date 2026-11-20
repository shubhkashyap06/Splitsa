import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Client-generated, time-sortable UUIDv7 — lets an offline-created row get
/// its real, globally unique id before it ever reaches the server
/// (OFFLINE_SYNC.md §1). Also used as the idempotency key for queued ops.
String newId() => _uuid.v7();
