import 'phase1_sync_contract.dart';
import 'sync_transaction_graph.dart';

enum MirrorWriteFailureType {
  networkUnreachable,
  validationFailure,
  authOrConfigFailure,
  remoteServerError,
}

class MirrorWriteFailure implements Exception {
  const MirrorWriteFailure({
    required this.type,
    required this.message,
    required this.retryable,
    this.details,
  });

  final MirrorWriteFailureType type;
  final String message;
  final bool retryable;
  final Object? details;

  @override
  String toString() =>
      'MirrorWriteFailure(type: $type, retryable: $retryable, message: $message, details: $details)';
}

class TrustedMirrorWriteRequest {
  const TrustedMirrorWriteRequest({
    required this.transactionUuid,
    required this.transactionIdempotencyKey,
    required this.transaction,
    required this.transactionLines,
    required this.orderModifiers,
    required this.payment,
    required this.generatedAt,
  });

  static const int payloadVersion = 1;
  static const String functionName = 'mirror-transaction-graph';

  final String transactionUuid;
  final String transactionIdempotencyKey;
  final Map<String, Object?> transaction;
  final List<Map<String, Object?>> transactionLines;
  final List<Map<String, Object?>> orderModifiers;
  final Map<String, Object?>? payment;
  final DateTime generatedAt;

  factory TrustedMirrorWriteRequest.fromGraph(SyncTransactionGraph graph) {
    Map<String, Object?>? transaction;
    final List<Map<String, Object?>> transactionLines = <Map<String, Object?>>[];
    final List<Map<String, Object?>> orderModifiers = <Map<String, Object?>>[];
    Map<String, Object?>? payment;

    for (final SyncGraphRecord record in graph.records) {
      final Map<String, Object?> payload = Map<String, Object?>.from(
        record.payload,
      );
      switch (record.tableName) {
        case 'transactions':
          transaction = payload;
          break;
        case 'transaction_lines':
          transactionLines.add(payload);
          break;
        case 'order_modifiers':
          orderModifiers.add(payload);
          break;
        case 'payments':
          payment = payload;
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

    return TrustedMirrorWriteRequest(
      transactionUuid: graph.transactionUuid,
      transactionIdempotencyKey: graph.transactionIdempotencyKey,
      transaction: transaction,
      transactionLines: transactionLines,
      orderModifiers: orderModifiers,
      payment: payment,
      generatedAt: DateTime.now().toUtc(),
    );
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
      'payment': payment,
    };
  }
}

class TrustedMirrorWriteSuccess {
  const TrustedMirrorWriteSuccess({
    required this.transactionUuid,
    required this.transactionStatus,
    required this.mirroredRecords,
  });

  final String transactionUuid;
  final String transactionStatus;
  final int mirroredRecords;

  static TrustedMirrorWriteSuccess fromJson(Map<String, Object?> json) {
    final Object? transactionUuid = json['transaction_uuid'];
    final Object? transactionStatus = json['transaction_status'];
    final Object? mirroredRecords = json['mirrored_records'];
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
    );
  }
}
