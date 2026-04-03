import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/cash_movement_repository.dart';
import 'package:epos_app/domain/models/cash_movement.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration integrity hardening', () {
    test(
      'fresh schema protects cash_movements and audit_logs with explicit FK or trigger-backed enforcement',
      () async {
        final AppDatabase db = _createFreshDatabase();
        addTearDown(db.close);

        final List<_ForeignKeyRow> cashMovementFks = await _readForeignKeys(
          db,
          'cash_movements',
        );
        final Set<String> cashMovementTriggers = await _readTriggers(
          db,
          'cash_movements',
        );
        final List<_ForeignKeyRow> auditLogFks = await _readForeignKeys(
          db,
          'audit_logs',
        );
        final Set<String> auditLogTriggers = await _readTriggers(
          db,
          'audit_logs',
        );

        expect(
          cashMovementFks.isNotEmpty ||
              cashMovementTriggers.contains(
                'fk_cash_movements_shift_id_insert',
              ),
          isTrue,
        );
        expect(
          cashMovementFks.isNotEmpty ||
              cashMovementTriggers.contains(
                'fk_cash_movements_created_by_user_id_insert',
              ),
          isTrue,
        );
        expect(
          auditLogFks.isNotEmpty ||
              auditLogTriggers.contains('fk_audit_logs_actor_user_id_insert'),
          isTrue,
        );

        await expectLater(
          db.customStatement('''
          INSERT INTO cash_movements (
            shift_id,
            type,
            category,
            amount_minor,
            payment_method,
            created_by_user_id,
            created_at
          ) VALUES (999, 'expense', 'Invalid shift', 100, 'cash', 999, 1710000000);
        '''),
          throwsException,
        );
        await expectLater(
          db.customStatement('''
          INSERT INTO audit_logs (
            actor_user_id,
            action,
            entity_type,
            entity_id,
            metadata_json,
            created_at
          ) VALUES (999, 'shift_closed', 'shift', '1', '{}', 1710000001);
        '''),
          throwsException,
        );
      },
    );

    test(
      'migrated schema protects cash_movements with trigger-backed FK enforcement and preserves rows',
      () async {
        final AppDatabase db = _createV11ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<_ForeignKeyRow> cashMovementFks = await _readForeignKeys(
          db,
          'cash_movements',
        );
        final Set<String> cashMovementTriggers = await _readTriggers(
          db,
          'cash_movements',
        );

        expect(cashMovementFks, isEmpty);
        expect(
          cashMovementTriggers,
          contains('fk_cash_movements_shift_id_insert'),
        );
        expect(
          cashMovementTriggers,
          contains('fk_cash_movements_shift_id_update'),
        );
        expect(
          cashMovementTriggers,
          contains('fk_cash_movements_created_by_user_id_insert'),
        );
        expect(
          cashMovementTriggers,
          contains('fk_cash_movements_created_by_user_id_update'),
        );

        final CashMovementRepository repository = CashMovementRepository(db);
        final List<domain.CashMovement> movements = await repository
            .listCashMovementsForShift(1);
        expect(movements, hasLength(1));
        expect(movements.single.category, 'Bank drop');
        expect(movements.single.amountMinor, 500);

        await expectLater(
          db.customStatement('''
            INSERT INTO cash_movements (
              shift_id,
              type,
              category,
              amount_minor,
              payment_method,
              created_by_user_id,
              created_at
            ) VALUES (999, 'expense', 'Invalid shift', 100, 'cash', 999, 1710000000);
          '''),
          throwsException,
        );
      },
    );

    test(
      'migrated schema keeps audit_logs protected with explicit trigger enforcement and preserves rows',
      () async {
        final AppDatabase db = _createV11ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<_ForeignKeyRow> auditLogFks = await _readForeignKeys(
          db,
          'audit_logs',
        );
        final Set<String> auditTriggers = await _readTriggers(db, 'audit_logs');

        expect(auditLogFks, isEmpty);
        expect(auditTriggers, contains('fk_audit_logs_actor_user_id_insert'));
        expect(auditTriggers, contains('fk_audit_logs_actor_user_id_update'));

        final AuditLogRepository repository = AuditLogRepository(db);
        final logs = await repository.listAuditLogs(limit: 10);
        expect(logs, hasLength(1));
        expect(logs.single.action, 'shift_opened');
        expect(logs.single.actorUserId, 1);

        await expectLater(
          db.customStatement('''
            INSERT INTO audit_logs (
              actor_user_id,
              action,
              entity_type,
              entity_id,
              metadata_json,
              created_at
            ) VALUES (999, 'shift_closed', 'shift', '1', '{}', 1710000001);
          '''),
          throwsException,
        );
      },
    );
  });
}

AppDatabase _createFreshDatabase() => AppDatabase(NativeDatabase.memory());

AppDatabase _createV11ThenMigrateToCurrent() {
  final QueryExecutor rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('''
        CREATE TABLE users (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      database.execute('''
        CREATE TABLE shifts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          opened_by INTEGER NOT NULL,
          opened_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          closed_by INTEGER NULL,
          closed_at INTEGER NULL,
          cashier_previewed_at INTEGER NULL,
          cashier_previewed_by INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
        );
      ''');
      database.execute('''
        CREATE TABLE categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          image_url TEXT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      database.execute('''
        CREATE TABLE products (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
          image_url TEXT NULL,
          has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          is_visible_on_pos INTEGER NOT NULL DEFAULT 1 CHECK (is_visible_on_pos IN (0, 1)),
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''');
      database.execute('''
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      database.execute('''
        CREATE TABLE transactions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          shift_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          table_number INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
          subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
          modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
          total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          paid_at INTEGER NULL,
          updated_at INTEGER NOT NULL,
          cancelled_at INTEGER NULL,
          cancelled_by INTEGER NULL,
          idempotency_key TEXT NOT NULL UNIQUE,
          kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
          receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
        );
      ''');
      database.execute('''
        CREATE TABLE transaction_lines (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0)
        );
      ''');
      database.execute('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add')),
          item_name TEXT NOT NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0)
        );
      ''');
      database.execute('''
        CREATE TABLE cash_movements (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          shift_id INTEGER NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('income','expense')),
          category TEXT NOT NULL CHECK (length(trim(category)) > 0),
          amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
          payment_method TEXT NOT NULL CHECK (payment_method IN ('cash','card','other')),
          note TEXT NULL,
          created_by_user_id INTEGER NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      database.execute('''
        CREATE TABLE audit_logs (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          actor_user_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (length(trim(action)) > 0),
          entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0),
          entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
          metadata_json TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      database.execute('''
        CREATE TABLE report_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          visibility_ratio REAL NOT NULL DEFAULT 1.0 CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
          updated_by INTEGER NULL,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      database.execute(
        "CREATE INDEX idx_cash_movements_shift ON cash_movements(shift_id, created_at);",
      );
      database.execute(
        "CREATE INDEX idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);",
      );
      database.execute(
        "CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);",
      );
      database.execute(
        "CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);",
      );
      database.execute(
        "INSERT INTO report_settings (id, visibility_ratio, updated_by, updated_at) VALUES (1, 1.0, 1, 1710000000);",
      );

      database.execute(
        "INSERT INTO users (id, name, role, is_active, created_at) VALUES (1, 'Admin', 'admin', 1, 1710000000);",
      );
      database.execute(
        "INSERT INTO shifts (id, opened_by, opened_at, status) VALUES (1, 1, 1710000000, 'open');",
      );
      database.execute('''
        INSERT INTO cash_movements (
          id,
          shift_id,
          type,
          category,
          amount_minor,
          payment_method,
          note,
          created_by_user_id,
          created_at
        ) VALUES (1, 1, 'expense', 'Bank drop', 500, 'cash', 'legacy row', 1, 1710000001);
      ''');
      database.execute('''
        INSERT INTO audit_logs (
          id,
          actor_user_id,
          action,
          entity_type,
          entity_id,
          metadata_json,
          created_at
        ) VALUES (1, 1, 'shift_opened', 'shift', '1', '{}', 1710000002);
      ''');
      database.execute('PRAGMA user_version = 11;');
    },
  );

  return AppDatabase(rawDb);
}

Future<List<_ForeignKeyRow>> _readForeignKeys(
  AppDatabase db,
  String tableName,
) async {
  final List<QueryRow> rows = await db
      .customSelect('PRAGMA foreign_key_list($tableName)')
      .get();
  return rows
      .map(
        (row) => _ForeignKeyRow(
          table: row.read<String>('table'),
          fromColumn: row.read<String>('from'),
          toColumn: row.read<String>('to'),
        ),
      )
      .toList(growable: false);
}

Future<Set<String>> _readTriggers(AppDatabase db, String tableName) async {
  final List<QueryRow> rows = await db
      .customSelect(
        '''
          SELECT name
          FROM sqlite_master
          WHERE type = 'trigger' AND tbl_name = ?
        ''',
        variables: [Variable<String>(tableName)],
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

class _ForeignKeyRow {
  const _ForeignKeyRow({
    required this.table,
    required this.fromColumn,
    required this.toColumn,
  });

  final String table;
  final String fromColumn;
  final String toColumn;
}
