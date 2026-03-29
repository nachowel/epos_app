import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_transaction_graph.dart';

/// Single remote write boundary for mirrored sync payloads.
///
/// Local Drift creates and finalizes the operational truth.
/// Implementations here only persist synchronized mirror snapshots remotely.
abstract class SupabaseMirrorWriter {
  Future<void> writeTransactionGraph(SyncTransactionGraph graph);
}

/// Temporary client-side mirror writer.
///
/// This is intentionally named as a direct table writer so it is not mistaken
/// for a trusted production boundary. Hardened deployments should use the
/// trusted server-side writer path instead. This implementation remains only
/// for controlled non-production paths and explicit test wiring.
class DirectSupabaseMirrorWriter implements SupabaseMirrorWriter {
  const DirectSupabaseMirrorWriter(this._client);

  final SupabaseClient _client;

  @override
  Future<void> writeTransactionGraph(SyncTransactionGraph graph) async {
    for (final SyncGraphRecord record in graph.records) {
      await _client
          .from(record.tableName)
          .upsert(record.payload, onConflict: 'uuid')
          .timeout(const Duration(seconds: 15));
    }
  }
}
