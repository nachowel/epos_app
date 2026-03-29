enum Phase1SyncTable {
  transactions('transactions'),
  transactionLines('transaction_lines'),
  orderModifiers('order_modifiers'),
  payments('payments');

  const Phase1SyncTable(this.tableName);

  final String tableName;
}

class Phase1SyncContract {
  const Phase1SyncContract._();

  // Local Drift/SQLite is the operational authority.
  // Supabase stores synchronized mirror snapshots only.
  static const List<String> requiredRemoteTables = <String>[
    'transactions',
    'transaction_lines',
    'order_modifiers',
    'payments',
  ];

  static const Set<String> syncableTableNames = <String>{
    ...requiredRemoteTables,
  };

  static const Set<String> localOnlyTableNames = <String>{
    'users',
    'categories',
    'products',
    'product_modifiers',
    'shifts',
    'payment_adjustments',
    'shift_reconciliations',
    'cash_movements',
    'audit_logs',
    'print_jobs',
    'report_settings',
    'printer_settings',
    'sync_queue',
  };

  static const Set<String> remoteTransactionStatuses = <String>{
    'open',
    'paid',
    'cancelled',
  };

  static bool isSyncableTable(String tableName) {
    return syncableTableNames.contains(tableName);
  }

  // Mirror sync runs only after the local POS reaches a finalized outcome.
  static bool isTerminalTransactionStatus(String status) {
    return status == 'paid' || status == 'cancelled';
  }

  static bool isRemoteTransactionStatus(String status) {
    return remoteTransactionStatuses.contains(status);
  }

  static String mapLocalTransactionStatusToRemote(String localStatus) {
    switch (localStatus) {
      case 'open':
      case 'draft':
      case 'sent':
        return 'open';
      case 'paid':
        return 'paid';
      case 'cancelled':
        return 'cancelled';
      default:
        throw ArgumentError.value(
          localStatus,
          'localStatus',
          'Unsupported local transaction status for remote mirroring.',
        );
    }
  }
}
