import 'phase1_sync_contract.dart';

/// Release rule:
/// If a mirror payload or this contract changes, deploy the matching Supabase
/// migration before releasing the app build that emits the new payload.
class MirrorSchemaContract {
  const MirrorSchemaContract._();

  static const String releaseRule =
      'If mirrored payload changes, deploy the matching Supabase migration before releasing the app build.';

  static MirrorTableContract tableSpec(Phase1SyncTable table) {
    return switch (table) {
      Phase1SyncTable.transactions => _transactions,
      Phase1SyncTable.transactionLines => _transactionLines,
      Phase1SyncTable.orderModifiers => _orderModifiers,
      Phase1SyncTable.payments => _payments,
    };
  }

  static MirrorTableContract tableSpecForName(String tableName) {
    return switch (tableName) {
      'transactions' => _transactions,
      'transaction_lines' => _transactionLines,
      'order_modifiers' => _orderModifiers,
      'payments' => _payments,
      _ => throw ArgumentError.value(
        tableName,
        'tableName',
        'Unsupported mirror table.',
      ),
    };
  }

  static void validatePayload({
    required Phase1SyncTable table,
    required Map<String, Object?> payload,
    String? recordUuid,
  }) {
    final MirrorTableContract contract = tableSpec(table);
    final List<String> issues = <String>[];

    final List<String> unexpectedColumns =
        payload.keys
            .where((String key) => !contract.payloadColumnNames.contains(key))
            .toList(growable: false)
          ..sort();
    for (final String columnName in unexpectedColumns) {
      issues.add('unexpected payload column: $columnName');
    }

    final List<String> missingColumns =
        contract.payloadColumns
            .where(
              (MirrorColumnContract column) =>
                  !payload.containsKey(column.name),
            )
            .map((MirrorColumnContract column) => column.name)
            .toList(growable: false)
          ..sort();
    for (final String columnName in missingColumns) {
      issues.add('missing payload column: $columnName');
    }

    for (final MirrorColumnContract column in contract.payloadColumns) {
      if (!payload.containsKey(column.name)) {
        continue;
      }
      final Object? value = payload[column.name];
      if (value == null) {
        if (!column.nullable) {
          issues.add('column ${column.name} may not be null');
        }
        continue;
      }
      if (!column.remoteType.acceptsRuntimeValue(value)) {
        issues.add(
          'column ${column.name} expected ${column.remoteType.sqlType} but received ${value.runtimeType}',
        );
      }
    }

    if (issues.isEmpty) {
      return;
    }

    throw MirrorSchemaContractViolation(
      tableName: contract.tableName,
      recordUuid: recordUuid,
      message:
          'Mirror payload drift detected. ${MirrorSchemaContract.releaseRule}',
      issues: issues,
    );
  }

  static const MirrorTableContract _transactions = MirrorTableContract(
    tableName: 'transactions',
    columns: <MirrorColumnContract>[
      MirrorColumnContract(
        name: 'uuid',
        remoteType: MirrorRemoteType.uuid,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'shift_local_id',
        remoteType: MirrorRemoteType.bigint,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'user_local_id',
        remoteType: MirrorRemoteType.bigint,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'table_number',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'status',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'subtotal_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'modifier_total_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'discount_type',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'discount_value_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'discount_amount_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'discount_reason',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'discount_applied_by_local_id',
        remoteType: MirrorRemoteType.bigint,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'total_amount_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'created_at',
        remoteType: MirrorRemoteType.timestamptz,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'paid_at',
        remoteType: MirrorRemoteType.timestamptz,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'updated_at',
        remoteType: MirrorRemoteType.timestamptz,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'cancelled_at',
        remoteType: MirrorRemoteType.timestamptz,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'cancelled_by_local_id',
        remoteType: MirrorRemoteType.bigint,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'kitchen_printed',
        remoteType: MirrorRemoteType.boolean,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'receipt_printed',
        remoteType: MirrorRemoteType.boolean,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'synced_at',
        remoteType: MirrorRemoteType.timestamptz,
        includedInPayload: false,
        nullable: false,
        hasRemoteDefault: true,
      ),
    ],
  );

  static const MirrorTableContract _transactionLines = MirrorTableContract(
    tableName: 'transaction_lines',
    columns: <MirrorColumnContract>[
      MirrorColumnContract(
        name: 'uuid',
        remoteType: MirrorRemoteType.uuid,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'transaction_uuid',
        remoteType: MirrorRemoteType.uuid,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'product_local_id',
        remoteType: MirrorRemoteType.bigint,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'product_name',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'unit_price_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'quantity',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'pricing_mode',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'removal_discount_total_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'line_total_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
      ),
    ],
  );

  static const MirrorTableContract _orderModifiers = MirrorTableContract(
    tableName: 'order_modifiers',
    columns: <MirrorColumnContract>[
      MirrorColumnContract(
        name: 'uuid',
        remoteType: MirrorRemoteType.uuid,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'transaction_line_uuid',
        remoteType: MirrorRemoteType.uuid,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'action',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'item_name',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'extra_price_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'quantity',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'item_product_id',
        remoteType: MirrorRemoteType.bigint,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'charge_reason',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'unit_price_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'price_effect_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'sort_key',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
        hasRemoteDefault: true,
      ),
      MirrorColumnContract(
        name: 'price_behavior',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: true,
      ),
      MirrorColumnContract(
        name: 'ui_section',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: true,
      ),
    ],
  );

  static const MirrorTableContract _payments = MirrorTableContract(
    tableName: 'payments',
    columns: <MirrorColumnContract>[
      MirrorColumnContract(
        name: 'uuid',
        remoteType: MirrorRemoteType.uuid,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'transaction_uuid',
        remoteType: MirrorRemoteType.uuid,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'method',
        remoteType: MirrorRemoteType.text,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'amount_minor',
        remoteType: MirrorRemoteType.integer,
        includedInPayload: true,
        nullable: false,
      ),
      MirrorColumnContract(
        name: 'paid_at',
        remoteType: MirrorRemoteType.timestamptz,
        includedInPayload: true,
        nullable: false,
      ),
    ],
  );
}

class MirrorTableContract {
  const MirrorTableContract({required this.tableName, required this.columns});

  final String tableName;
  final List<MirrorColumnContract> columns;

  List<MirrorColumnContract> get payloadColumns => columns
      .where((MirrorColumnContract column) => column.includedInPayload)
      .toList(growable: false);

  Set<String> get remoteColumnNames =>
      columns.map((MirrorColumnContract column) => column.name).toSet();

  Set<String> get payloadColumnNames =>
      payloadColumns.map((MirrorColumnContract column) => column.name).toSet();
}

class MirrorColumnContract {
  const MirrorColumnContract({
    required this.name,
    required this.remoteType,
    required this.includedInPayload,
    required this.nullable,
    this.hasRemoteDefault = false,
  });

  final String name;
  final MirrorRemoteType remoteType;
  final bool includedInPayload;
  final bool nullable;
  final bool hasRemoteDefault;
}

enum MirrorRemoteType {
  uuid('uuid'),
  bigint('bigint'),
  integer('integer'),
  text('text'),
  timestamptz('timestamptz'),
  boolean('boolean');

  const MirrorRemoteType(this.sqlType);

  final String sqlType;

  bool acceptsRuntimeValue(Object value) {
    return switch (this) {
      MirrorRemoteType.uuid ||
      MirrorRemoteType.text ||
      MirrorRemoteType.timestamptz => value is String,
      MirrorRemoteType.bigint || MirrorRemoteType.integer => value is int,
      MirrorRemoteType.boolean => value is bool,
    };
  }
}

class MirrorSchemaContractViolation implements Exception {
  const MirrorSchemaContractViolation({
    required this.tableName,
    required this.message,
    required this.issues,
    this.recordUuid,
  });

  final String tableName;
  final String message;
  final List<String> issues;
  final String? recordUuid;

  @override
  String toString() {
    final String recordContext = recordUuid == null
        ? ''
        : ', recordUuid: $recordUuid';
    final String issueContext = issues.isEmpty
        ? ''
        : ', issues: ${issues.join(' | ')}';
    return 'MirrorSchemaContractViolation(table: $tableName$recordContext, message: $message$issueContext)';
  }
}
