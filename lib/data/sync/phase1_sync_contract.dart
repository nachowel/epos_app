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

  static const Set<String> syncableTableNames = <String>{
    'transactions',
    'transaction_lines',
    'order_modifiers',
    'payments',
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

  static bool isSyncableTable(String tableName) {
    return syncableTableNames.contains(tableName);
  }

  static bool isTerminalTransactionStatus(String status) {
    return status == 'paid' || status == 'cancelled';
  }
}
