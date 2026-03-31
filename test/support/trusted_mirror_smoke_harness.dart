import 'package:epos_app/data/sync/phase1_sync_contract.dart';
import 'package:epos_app/data/sync/trusted_mirror_boundary_contract.dart';
import 'package:epos_app/data/sync/trusted_supabase_mirror_writer.dart';

class TrustedMirrorSmokeHarness implements TrustedMirrorBoundaryInvoker {
  TrustedMirrorSmokeHarness({
    this.forcedFailures = const <String, String>{},
    Map<String, int> transientFailuresBeforeSuccess = const <String, int>{},
  }) : _transientFailuresBeforeSuccess = Map<String, int>.from(
         transientFailuresBeforeSuccess,
       );

  final Map<String, String> forcedFailures;
  final Map<String, int> _transientFailuresBeforeSuccess;

  final Map<String, Map<String, Object?>> _transactions =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> _transactionLines =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> _orderModifiers =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> _payments =
      <String, Map<String, Object?>>{};

  final List<String> writeOrder = <String>[];
  final List<List<String>> invocationOrders = <List<String>>[];
  TrustedMirrorWriteRequest? lastRequest;
  TrustedMirrorWriteSuccess? lastSuccess;

  Map<String, Object?>? transaction(String uuid) =>
      _snapshot(_transactions, uuid);

  Map<String, Object?>? transactionLine(String uuid) =>
      _snapshot(_transactionLines, uuid);

  Map<String, Object?>? orderModifier(String uuid) =>
      _snapshot(_orderModifiers, uuid);

  Map<String, Object?>? payment(String uuid) => _snapshot(_payments, uuid);

  int get transactionCount => _transactions.length;

  int get transactionLineCount => _transactionLines.length;

  int get orderModifierCount => _orderModifiers.length;

  int get paymentCount => _payments.length;

  @override
  Future<TrustedMirrorWriteSuccess> invoke(
    TrustedMirrorWriteRequest request,
  ) async {
    lastRequest = request;
    _validateRequest(request);
    final List<String> invocationOrder = <String>[];
    invocationOrders.add(invocationOrder);

    final List<TrustedMirrorTableWriteResult> tableResults =
        <TrustedMirrorTableWriteResult>[
          _upsertTransactions(request.transaction, invocationOrder),
          _upsertTransactionLines(request.transactionLines, invocationOrder),
          _upsertOrderModifiers(request.orderModifiers, invocationOrder),
          _upsertPayments(request.payments, invocationOrder),
        ];

    final TrustedMirrorWriteSuccess success = TrustedMirrorWriteSuccess(
      transactionUuid: request.transactionUuid,
      transactionStatus: request.transaction['status']! as String,
      mirroredRecords: tableResults.fold<int>(
        0,
        (int total, TrustedMirrorTableWriteResult result) =>
            total + result.recordCount,
      ),
      tableResults: tableResults,
    );
    lastSuccess = success;
    return success;
  }

  void _validateRequest(TrustedMirrorWriteRequest request) {
    if (!Phase1SyncContract.isCanonicalUuid(request.transactionUuid)) {
      throw const MirrorWriteFailure(
        type: MirrorWriteFailureType.validationFailure,
        message: 'Transaction UUID must be canonical.',
        retryable: false,
        tableName: 'transactions',
      );
    }

    final String status = request.transaction['status']! as String;
    if (!Phase1SyncContract.isRemoteTransactionStatus(status)) {
      throw const MirrorWriteFailure(
        type: MirrorWriteFailureType.validationFailure,
        message: 'Remote transactions accept paid/cancelled only.',
        retryable: false,
        tableName: 'transactions',
      );
    }
  }

  TrustedMirrorTableWriteResult _upsertTransactions(
    Map<String, Object?> transaction,
    List<String> invocationOrder,
  ) {
    _recordTableWrite('transactions', invocationOrder);
    final String uuid = _requireUuid(
      transaction,
      tableName: 'transactions',
      relationKey: 'uuid',
    );
    _failIfConfigured(tableName: 'transactions', recordUuid: uuid);
    _transactions[uuid] = Map<String, Object?>.from(transaction);
    return TrustedMirrorTableWriteResult(
      tableName: 'transactions',
      status: TrustedMirrorTableWriteStatus.synced,
      recordCount: 1,
      recordUuids: <String>[uuid],
    );
  }

  TrustedMirrorTableWriteResult _upsertTransactionLines(
    List<Map<String, Object?>> lines,
    List<String> invocationOrder,
  ) {
    _recordTableWrite('transaction_lines', invocationOrder);
    final List<String> uuids = <String>[];
    for (final Map<String, Object?> line in lines) {
      final String uuid = _requireUuid(
        line,
        tableName: 'transaction_lines',
        relationKey: 'uuid',
      );
      final String transactionUuid = _requireUuid(
        line,
        tableName: 'transaction_lines',
        relationKey: 'transaction_uuid',
      );
      if (!_transactions.containsKey(transactionUuid)) {
        throw MirrorWriteFailure(
          type: MirrorWriteFailureType.remoteServerError,
          message: 'Missing parent transaction for mirrored line.',
          retryable: false,
          tableName: 'transaction_lines',
          recordUuid: uuid,
        );
      }
      _failIfConfigured(tableName: 'transaction_lines', recordUuid: uuid);
      _transactionLines[uuid] = Map<String, Object?>.from(line);
      uuids.add(uuid);
    }
    return TrustedMirrorTableWriteResult(
      tableName: 'transaction_lines',
      status: uuids.isEmpty
          ? TrustedMirrorTableWriteStatus.skipped
          : TrustedMirrorTableWriteStatus.synced,
      recordCount: uuids.length,
      recordUuids: uuids,
    );
  }

  TrustedMirrorTableWriteResult _upsertOrderModifiers(
    List<Map<String, Object?>> modifiers,
    List<String> invocationOrder,
  ) {
    _recordTableWrite('order_modifiers', invocationOrder);
    final List<String> uuids = <String>[];
    for (final Map<String, Object?> modifier in modifiers) {
      final String uuid = _requireUuid(
        modifier,
        tableName: 'order_modifiers',
        relationKey: 'uuid',
      );
      final String transactionLineUuid = _requireUuid(
        modifier,
        tableName: 'order_modifiers',
        relationKey: 'transaction_line_uuid',
      );
      if (!_transactionLines.containsKey(transactionLineUuid)) {
        throw MirrorWriteFailure(
          type: MirrorWriteFailureType.remoteServerError,
          message: 'Missing parent transaction line for mirrored modifier.',
          retryable: false,
          tableName: 'order_modifiers',
          recordUuid: uuid,
        );
      }
      _failIfConfigured(tableName: 'order_modifiers', recordUuid: uuid);
      _orderModifiers[uuid] = Map<String, Object?>.from(modifier);
      uuids.add(uuid);
    }
    return TrustedMirrorTableWriteResult(
      tableName: 'order_modifiers',
      status: uuids.isEmpty
          ? TrustedMirrorTableWriteStatus.skipped
          : TrustedMirrorTableWriteStatus.synced,
      recordCount: uuids.length,
      recordUuids: uuids,
    );
  }

  TrustedMirrorTableWriteResult _upsertPayments(
    List<Map<String, Object?>> payments,
    List<String> invocationOrder,
  ) {
    _recordTableWrite('payments', invocationOrder);
    if (payments.isEmpty) {
      return const TrustedMirrorTableWriteResult(
        tableName: 'payments',
        status: TrustedMirrorTableWriteStatus.skipped,
        recordCount: 0,
        recordUuids: <String>[],
      );
    }

    final List<String> uuids = <String>[];
    for (final Map<String, Object?> payment in payments) {
      final String uuid = _requireUuid(
        payment,
        tableName: 'payments',
        relationKey: 'uuid',
      );
      final String transactionUuid = _requireUuid(
        payment,
        tableName: 'payments',
        relationKey: 'transaction_uuid',
      );
      if (!_transactions.containsKey(transactionUuid)) {
        throw MirrorWriteFailure(
          type: MirrorWriteFailureType.remoteServerError,
          message: 'Missing parent transaction for mirrored payment.',
          retryable: false,
          tableName: 'payments',
          recordUuid: uuid,
        );
      }

      String? existingPaymentUuid;
      for (final MapEntry<String, Map<String, Object?>> entry
          in _payments.entries) {
        if (entry.value['transaction_uuid'] == transactionUuid) {
          existingPaymentUuid = entry.key;
          break;
        }
      }
      if (existingPaymentUuid != null && existingPaymentUuid != uuid) {
        throw MirrorWriteFailure(
          type: MirrorWriteFailureType.remoteServerError,
          message: 'Payments.transaction_uuid must remain unique remotely.',
          retryable: false,
          tableName: 'payments',
          recordUuid: uuid,
          recordUuids: <String>[uuid, existingPaymentUuid],
        );
      }

      _failIfConfigured(tableName: 'payments', recordUuid: uuid);
      _payments[uuid] = Map<String, Object?>.from(payment);
      uuids.add(uuid);
    }
    return TrustedMirrorTableWriteResult(
      tableName: 'payments',
      status: TrustedMirrorTableWriteStatus.synced,
      recordCount: uuids.length,
      recordUuids: uuids,
    );
  }

  String _requireUuid(
    Map<String, Object?> payload, {
    required String tableName,
    required String relationKey,
  }) {
    final Object? rawValue = payload[relationKey];
    if (rawValue is! String || !Phase1SyncContract.isCanonicalUuid(rawValue)) {
      throw MirrorWriteFailure(
        type: MirrorWriteFailureType.validationFailure,
        message: '$relationKey must be a canonical UUID.',
        retryable: false,
        tableName: tableName,
        issues: <String>['$tableName.$relationKey must be a canonical UUID'],
      );
    }
    return rawValue;
  }

  void _failIfConfigured({
    required String tableName,
    required String recordUuid,
  }) {
    final String scopedKey = '$tableName:$recordUuid';
    final int remainingTransientFailures =
        _transientFailuresBeforeSuccess[scopedKey] ??
        _transientFailuresBeforeSuccess[tableName] ??
        0;
    if (remainingTransientFailures > 0) {
      if (_transientFailuresBeforeSuccess.containsKey(scopedKey)) {
        _transientFailuresBeforeSuccess[scopedKey] =
            remainingTransientFailures - 1;
      } else {
        _transientFailuresBeforeSuccess[tableName] =
            remainingTransientFailures - 1;
      }
      throw MirrorWriteFailure(
        type: MirrorWriteFailureType.remoteServerError,
        message: 'Transient remote failure before mirroring $scopedKey.',
        retryable: true,
        tableName: tableName,
        recordUuid: recordUuid,
      );
    }

    final String? failureMessage =
        forcedFailures[scopedKey] ?? forcedFailures[tableName];
    if (failureMessage == null) {
      return;
    }
    throw MirrorWriteFailure(
      type: MirrorWriteFailureType.remoteServerError,
      message: failureMessage,
      retryable: true,
      tableName: tableName,
      recordUuid: recordUuid,
    );
  }

  void _recordTableWrite(String tableName, List<String> invocationOrder) {
    writeOrder.add(tableName);
    invocationOrder.add(tableName);
  }

  Map<String, Object?>? _snapshot(
    Map<String, Map<String, Object?>> table,
    String uuid,
  ) {
    final Map<String, Object?>? row = table[uuid];
    if (row == null) {
      return null;
    }
    return Map<String, Object?>.from(row);
  }
}
