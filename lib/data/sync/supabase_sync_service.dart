import 'package:supabase_flutter/supabase_flutter.dart';

import 'phase1_sync_contract.dart';
import 'sync_remote_gateway.dart';

class SupabaseSyncService implements SyncRemoteGateway {
  SupabaseSyncService({SupabaseClient? client, SupabaseSyncClient? syncClient})
    : _syncClient = syncClient ?? _buildDefaultClient(client);

  final SupabaseSyncClient? _syncClient;

  @override
  bool get isConfigured => _syncClient != null;

  @override
  Future<void> upsertRecord({
    required String tableName,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    final SupabaseSyncClient? syncClient = _syncClient;
    if (syncClient == null) {
      throw StateError('Supabase sync is not configured.');
    }

    if (tableName == Phase1SyncTable.transactions.tableName &&
        payload['status'] is String &&
        !Phase1SyncContract.isTerminalTransactionStatus(
          payload['status']! as String,
        )) {
      throw StateError('Only terminal transactions may be synced to Supabase.');
    }

    await syncClient.upsert(
      tableName: tableName,
      payload: payload,
      onConflict: 'uuid',
    );
  }

  static SupabaseSyncClient? _buildDefaultClient(SupabaseClient? client) {
    if (client == null) {
      return null;
    }
    return _SupabaseFlutterSyncClient(client);
  }
}

abstract class SupabaseSyncClient {
  Future<void> upsert({
    required String tableName,
    required Map<String, Object?> payload,
    required String onConflict,
  });
}

class _SupabaseFlutterSyncClient implements SupabaseSyncClient {
  const _SupabaseFlutterSyncClient(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsert({
    required String tableName,
    required Map<String, Object?> payload,
    required String onConflict,
  }) async {
    await _client
        .from(tableName)
        .upsert(payload, onConflict: onConflict)
        .timeout(const Duration(seconds: 15));
  }
}
