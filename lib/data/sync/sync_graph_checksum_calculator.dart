import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'sync_transaction_graph.dart';

class SyncGraphChecksumCalculator {
  const SyncGraphChecksumCalculator();

  String calculate(SyncTransactionGraph graph) {
    final List<SyncGraphRecord> sortedRecords = graph.records.toList(
      growable: false,
    )..sort(_compareRecords);
    final Object? canonicalGraph = _canonicalize(<String, Object?>{
      'transaction_uuid': graph.transactionUuid,
      'transaction_idempotency_key': graph.transactionIdempotencyKey,
      'records': sortedRecords
          .map(
            (SyncGraphRecord record) => <String, Object?>{
              'table': record.tableName,
              'record_uuid': record.recordUuid,
              'payload': record.payload,
            },
          )
          .toList(growable: false),
    });
    final String canonicalJson = jsonEncode(canonicalGraph);
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final List<String> sortedKeys =
          value.keys
              .map((Object? key) => key.toString())
              .toList(growable: false)
            ..sort();
      return <String, Object?>{
        for (final String key in sortedKeys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    return value;
  }

  int _compareRecords(SyncGraphRecord left, SyncGraphRecord right) {
    final int tableOrder = _tableSortRank(
      left.tableName,
    ).compareTo(_tableSortRank(right.tableName));
    if (tableOrder != 0) {
      return tableOrder;
    }
    return left.recordUuid.compareTo(right.recordUuid);
  }

  int _tableSortRank(String tableName) {
    switch (tableName) {
      case 'transactions':
        return 0;
      case 'transaction_lines':
        return 1;
      case 'order_modifiers':
        return 2;
      case 'payments':
        return 3;
      default:
        return 99;
    }
  }
}
