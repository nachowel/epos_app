abstract class SyncRemoteGateway {
  bool get isConfigured;

  Future<void> upsertRecord({
    required String tableName,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  });
}
