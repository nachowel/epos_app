import 'phase1_sync_contract.dart';
import 'sync_transaction_graph.dart';

enum MirrorWriteFailureType {
  networkUnreachable,
  validationFailure,
  authOrConfigFailure,
  remoteServerError,
  localGraphDrift,
}

class MirrorWriteFailure implements Exception {
  const MirrorWriteFailure({
    required this.type,
    required this.message,
    required this.retryable,
    this.details,
    this.tableName,
    this.recordUuid,
    this.recordUuids = const <String>[],
    this.issues = const <String>[],
  });

  final MirrorWriteFailureType type;
  final String message;
  final bool retryable;
  final Object? details;
  final String? tableName;
  final String? recordUuid;
  final List<String> recordUuids;
  final List<String> issues;

  @override
  String toString() {
    final String location = switch ((tableName, recordUuid, recordUuids)) {
      (final String table, final String uuid, _) =>
        ', table: $table, recordUuid: $uuid',
      (final String table, _, final List<String> uuids) when uuids.isNotEmpty =>
        ', table: $table, recordUuids: ${uuids.join(',')}',
      (final String table, _, _) => ', table: $table',
      _ => '',
    };
    final String validationIssues = issues.isEmpty
        ? ''
        : ', issues: ${issues.join(' | ')}';
    return 'MirrorWriteFailure(type: $type, retryable: $retryable, message: $message$location$validationIssues, details: $details)';
  }
}

enum TrustedMirrorTableWriteStatus { synced, skipped }

class TrustedMirrorTableWriteResult {
  const TrustedMirrorTableWriteResult({
    required this.tableName,
    required this.status,
    required this.recordCount,
    required this.recordUuids,
  });

  final String tableName;
  final TrustedMirrorTableWriteStatus status;
  final int recordCount;
  final List<String> recordUuids;

  static TrustedMirrorTableWriteResult fromJson(Map<String, Object?> json) {
    final Object? tableName = json['table'];
    final Object? rawStatus = json['status'];
    final Object? recordCount = json['record_count'];
    final Object? rawRecordUuids = json['record_uuids'];
    if (tableName is! String ||
        rawStatus is! String ||
        recordCount is! int ||
        rawRecordUuids is! List) {
      throw const MirrorWriteFailure(
        type: MirrorWriteFailureType.remoteServerError,
        message: 'Trusted boundary returned an invalid table result payload.',
        retryable: true,
      );
    }

    return TrustedMirrorTableWriteResult(
      tableName: tableName,
      status: switch (rawStatus) {
        'synced' => TrustedMirrorTableWriteStatus.synced,
        'skipped' => TrustedMirrorTableWriteStatus.skipped,
        _ => throw const MirrorWriteFailure(
          type: MirrorWriteFailureType.remoteServerError,
          message: 'Trusted boundary returned an unknown table result status.',
          retryable: true,
        ),
      },
      recordCount: recordCount,
      recordUuids: rawRecordUuids.whereType<String>().toList(growable: false),
    );
  }
}

class TrustedMirrorWriteRequest {
  const TrustedMirrorWriteRequest({
    required this.transactionUuid,
    required this.transactionIdempotencyKey,
    required this.transaction,
    required this.transactionLines,
    required this.orderModifiers,
    required this.payments,
    required this.generatedAt,
  });

  static const int payloadVersion = 1;
  static const String functionName = 'mirror-transaction-graph';

  final String transactionUuid;
  final String transactionIdempotencyKey;
  final Map<String, Object?> transaction;
  final List<Map<String, Object?>> transactionLines;
  final List<Map<String, Object?>> orderModifiers;
  final List<Map<String, Object?>> payments;
  final DateTime generatedAt;

  factory TrustedMirrorWriteRequest.fromGraph(SyncTransactionGraph graph) {
    if (!Phase1SyncContract.isCanonicalUuid(graph.transactionUuid)) {
      throw StateError(
        'Trusted mirror writes require canonical UUID transaction identifiers.',
      );
    }

    Map<String, Object?>? transaction;
    final List<Map<String, Object?>> transactionLines =
        <Map<String, Object?>>[];
    final List<Map<String, Object?>> orderModifiers = <Map<String, Object?>>[];
    final List<Map<String, Object?>> payments = <Map<String, Object?>>[];

    for (final SyncGraphRecord record in graph.records) {
      final Map<String, Object?> payload = Map<String, Object?>.from(
        record.payload,
      );
      switch (record.tableName) {
        case 'transactions':
          _requireUuidField(
            payload,
            key: 'uuid',
            errorMessage:
                'Trusted mirror transaction payloads must use canonical UUID values.',
          );
          transaction = payload;
          break;
        case 'transaction_lines':
          _requireUuidField(
            payload,
            key: 'uuid',
            errorMessage:
                'Trusted mirror line payloads must use canonical UUID values.',
          );
          _requireUuidField(
            payload,
            key: 'transaction_uuid',
            errorMessage:
                'Trusted mirror line payloads must reference the transaction with a canonical UUID.',
          );
          transactionLines.add(payload);
          break;
        case 'order_modifiers':
          _requireUuidField(
            payload,
            key: 'uuid',
            errorMessage:
                'Trusted mirror modifier payloads must use canonical UUID values.',
          );
          _requireUuidField(
            payload,
            key: 'transaction_line_uuid',
            errorMessage:
                'Trusted mirror modifier payloads must reference the line with a canonical UUID.',
          );
          orderModifiers.add(payload);
          break;
        case 'payments':
          _requireUuidField(
            payload,
            key: 'uuid',
            errorMessage:
                'Trusted mirror payment payloads must use canonical UUID values.',
          );
          _requireUuidField(
            payload,
            key: 'transaction_uuid',
            errorMessage:
                'Trusted mirror payment payloads must reference the transaction with a canonical UUID.',
          );
          payments.add(payload);
          break;
      }
    }

    if (transaction == null) {
      throw StateError(
        'Trusted mirror writes require a transaction payload at the graph root.',
      );
    }

    final Object? rawStatus = transaction['status'];
    if (rawStatus is! String ||
        !Phase1SyncContract.isRemoteTransactionStatus(rawStatus)) {
      throw StateError(
        'Trusted mirror writes require an aligned remote transaction status.',
      );
    }
    if (rawStatus == 'paid' && payments.isEmpty) {
      throw StateError(
        'Trusted mirror writes require at least one payment payload for paid transactions.',
      );
    }

    return TrustedMirrorWriteRequest(
      transactionUuid: graph.transactionUuid,
      transactionIdempotencyKey: graph.transactionIdempotencyKey,
      transaction: transaction,
      transactionLines: transactionLines,
      orderModifiers: orderModifiers,
      payments: payments,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  static void _requireUuidField(
    Map<String, Object?> payload, {
    required String key,
    required String errorMessage,
  }) {
    final Object? rawValue = payload[key];
    if (rawValue is! String || !Phase1SyncContract.isCanonicalUuid(rawValue)) {
      throw StateError(errorMessage);
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'payload_version': payloadVersion,
      'transaction_uuid': transactionUuid,
      'transaction_idempotency_key': transactionIdempotencyKey,
      'generated_at': generatedAt.toIso8601String(),
      // Local Drift is the source of truth. The trusted boundary only mirrors
      // the finalized snapshot and must not invent business state.
      'transaction': transaction,
      'transaction_lines': transactionLines,
      'order_modifiers': orderModifiers,
      'payments': payments,
    };
  }
}

class TrustedMirrorWriteSuccess {
  const TrustedMirrorWriteSuccess({
    required this.transactionUuid,
    required this.transactionStatus,
    required this.mirroredRecords,
    this.tableResults = const <TrustedMirrorTableWriteResult>[],
  });

  final String transactionUuid;
  final String transactionStatus;
  final int mirroredRecords;
  final List<TrustedMirrorTableWriteResult> tableResults;

  static TrustedMirrorWriteSuccess fromJson(Map<String, Object?> json) {
    final Object? transactionUuid = json['transaction_uuid'];
    final Object? transactionStatus = json['transaction_status'];
    final Object? mirroredRecords = json['mirrored_records'];
    final Object? rawTableResults = json['table_results'];
    if (transactionUuid is! String ||
        transactionStatus is! String ||
        mirroredRecords is! int) {
      throw const MirrorWriteFailure(
        type: MirrorWriteFailureType.remoteServerError,
        message: 'Trusted boundary returned an invalid success payload.',
        retryable: true,
      );
    }

    return TrustedMirrorWriteSuccess(
      transactionUuid: transactionUuid,
      transactionStatus: transactionStatus,
      mirroredRecords: mirroredRecords,
      tableResults: rawTableResults is! List
          ? const <TrustedMirrorTableWriteResult>[]
          : rawTableResults
                .whereType<Map>()
                .map(
                  (Map<dynamic, dynamic> item) =>
                      TrustedMirrorTableWriteResult.fromJson(
                        Map<String, Object?>.from(item),
                      ),
                )
                .toList(growable: false),
    );
  }
}
