import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Migration v32 -> v33 transaction discount columns', () {
    test('adds discount snapshot columns with safe defaults', () async {
      final File file = await _createV32DatabaseFile();
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      final AppDatabase db = AppDatabase.forFile(file);
      addTearDown(db.close);

      final List<dynamic> columns = await db
          .customSelect('PRAGMA table_info(transactions);')
          .get();
      final Set<String> columnNames = columns
          .map((dynamic row) => row.read<String>('name') as String)
          .toSet();
      expect(
        columnNames,
        containsAll(<String>{
          'discount_type',
          'discount_value_minor',
          'discount_amount_minor',
          'discount_reason',
          'discount_applied_by',
        }),
      );

      final dynamic row = (await db.customSelect('''
        SELECT
          discount_type,
          discount_value_minor,
          discount_amount_minor,
          discount_reason,
          discount_applied_by,
          total_amount_minor
        FROM transactions
        WHERE id = 1
      ''').getSingle());
      expect(row.read<String?>('discount_type'), isNull);
      expect(row.read<int>('discount_value_minor'), 0);
      expect(row.read<int>('discount_amount_minor'), 0);
      expect(row.read<String?>('discount_reason'), isNull);
      expect(row.read<int?>('discount_applied_by'), isNull);
      expect(row.read<int>('total_amount_minor'), 1200);
    });

    test(
      'rewrites migrated transaction child schema references and supports full child inserts',
      () async {
        final File file = await _createV32DatabaseFile();
        addTearDown(() async {
          if (await file.exists()) {
            await file.delete();
          }
        });

        final AppDatabase db = AppDatabase.forFile(file);
        addTearDown(db.close);

        await _expectNoLegacyV33References(db);
        await _expectTransactionChildSchema(db);
        await _runTransactionChildSmoke(
          db,
          draftTransactionId: 2,
          draftUuid: 'tx-v33-draft',
          sentTransactionId: 3,
          sentUuid: 'tx-v33-sent',
          lineId: 2,
          lineUuid: 'line-v33',
          modifierId: 1,
          modifierUuid: 'modifier-v33',
          paymentId: 1,
          paymentUuid: 'payment-v33',
        );
      },
    );
  });

  group('Current schema open repairs broken v33 legacy references', () {
    test(
      'removes lingering transactions_legacy_v33 references on open and restores child insert paths',
      () async {
        final File file = await _createBrokenV33DatabaseFile();
        addTearDown(() async {
          if (await file.exists()) {
            await file.delete();
          }
        });

        final AppDatabase db = AppDatabase.forFile(file);
        addTearDown(db.close);

        await _expectNoLegacyV33References(db);
        await _expectTransactionChildSchema(db);
        await _runTransactionChildSmoke(
          db,
          draftTransactionId: 2,
          draftUuid: 'tx-v33-repaired-draft',
          sentTransactionId: 3,
          sentUuid: 'tx-v33-repaired-sent',
          lineId: 1,
          lineUuid: 'line-v33-repaired',
          modifierId: 1,
          modifierUuid: 'modifier-v33-repaired',
          paymentId: 1,
          paymentUuid: 'payment-v33-repaired',
        );
      },
    );
  });
}

Future<File> _createV32DatabaseFile() async {
  final Directory dir = await Directory.systemTemp.createTemp(
    'epos-migration-v32-v33-',
  );
  final File file = File('${dir.path}/migration.sqlite');
  final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA foreign_keys = OFF;');
    raw.execute('''
      CREATE TABLE users (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NULL,
        password TEXT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    raw.execute('''
      CREATE TABLE shifts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        opened_by INTEGER NOT NULL,
        opened_at INTEGER NOT NULL DEFAULT (unixepoch()),
        closed_by INTEGER NULL,
        closed_at INTEGER NULL,
        cashier_previewed_by INTEGER NULL,
        cashier_previewed_at INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
      );
    ''');
    raw.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        table_number INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
        subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
        modifier_total_minor INTEGER NOT NULL DEFAULT 0,
        total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        paid_at INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        cancelled_at INTEGER NULL,
        cancelled_by INTEGER NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
        receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
      );
    ''');
    raw.execute('''
      CREATE TABLE transaction_lines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL REFERENCES "transactions" ("id"),
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
        pricing_mode TEXT NOT NULL DEFAULT 'standard' CHECK (pricing_mode IN ('standard','set')),
        removal_discount_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_total_minor >= 0)
      );
    ''');
    raw.execute('''
      CREATE TABLE order_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL REFERENCES "transaction_lines" ("id"),
        action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        item_product_id INTEGER NULL,
        source_group_id INTEGER NULL,
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount','combo_discount')),
        unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
        price_effect_minor INTEGER NOT NULL DEFAULT 0,
        sort_key INTEGER NOT NULL DEFAULT 0,
        price_behavior TEXT NULL CHECK (price_behavior IS NULL OR price_behavior IN ('free','paid')),
        ui_section TEXT NULL CHECK (ui_section IS NULL OR ui_section IN ('toppings','sauces','add_ins')),
        CHECK (action != 'choice' OR charge_reason = 'included_choice')
      );
    ''');
    raw.execute('''
      CREATE TABLE payments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL UNIQUE REFERENCES "transactions" ("id"),
        method TEXT NOT NULL CHECK (method IN ('cash','card')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        paid_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    raw.execute(
      "INSERT INTO users (id, name, role, is_active, created_at) VALUES (1, 'Admin', 'admin', 1, unixepoch());",
    );
    raw.execute(
      "INSERT INTO shifts (id, opened_by, status, opened_at) VALUES (1, 1, 'open', unixepoch());",
    );
    raw.execute('''
      INSERT INTO transactions (
        id,
        uuid,
        shift_id,
        user_id,
        status,
        subtotal_minor,
        modifier_total_minor,
        total_amount_minor,
        updated_at,
        idempotency_key,
        kitchen_printed,
        receipt_printed
      ) VALUES (1, 'tx-v32', 1, 1, 'draft', 1000, 200, 1200, unixepoch(), 'idem-v32', 0, 0);
      ''');
    raw.execute('''
      INSERT INTO transaction_lines (
        id,
        uuid,
        transaction_id,
        product_id,
        product_name,
        unit_price_minor,
        quantity,
        line_total_minor,
        pricing_mode,
        removal_discount_total_minor
      ) VALUES (
        1,
        'line-v32',
        1,
        10,
        'Burger Meal',
        1200,
        1,
        1200,
        'standard',
        0
      );
    ''');
    raw.execute('PRAGMA user_version = 32;');
  } finally {
    raw.dispose();
  }
  return file;
}

Future<File> _createBrokenV33DatabaseFile() async {
  final Directory dir = await Directory.systemTemp.createTemp(
    'epos-broken-v33-',
  );
  final File file = File('${dir.path}/broken-v33.sqlite');
  final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA foreign_keys = OFF;');
    raw.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        table_number INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
        subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
        modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
        discount_type TEXT NULL CHECK (discount_type IS NULL OR discount_type IN ('amount','percent')),
        discount_value_minor INTEGER NOT NULL DEFAULT 0 CHECK (discount_value_minor >= 0),
        discount_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (discount_amount_minor >= 0 AND discount_amount_minor <= subtotal_minor + modifier_total_minor),
        discount_reason TEXT NULL,
        discount_applied_by INTEGER NULL,
        total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        paid_at INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        cancelled_at INTEGER NULL,
        cancelled_by INTEGER NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
        receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1)),
        CHECK (discount_type IS NOT NULL OR (discount_value_minor = 0 AND discount_amount_minor = 0 AND discount_reason IS NULL AND discount_applied_by IS NULL)),
        CHECK (discount_type != 'percent' OR discount_value_minor <= 100)
      );
    ''');
    raw.execute('''
      CREATE TABLE transaction_lines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL REFERENCES "transactions_legacy_v33" ("id"),
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
        pricing_mode TEXT NOT NULL DEFAULT 'standard' CHECK (pricing_mode IN ('standard','set')),
        removal_discount_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_total_minor >= 0)
      );
    ''');
    raw.execute('''
      CREATE TABLE order_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL REFERENCES "transaction_lines" ("id"),
        action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        item_product_id INTEGER NULL,
        source_group_id INTEGER NULL,
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount','combo_discount')),
        unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
        price_effect_minor INTEGER NOT NULL DEFAULT 0,
        sort_key INTEGER NOT NULL DEFAULT 0,
        price_behavior TEXT NULL CHECK (price_behavior IS NULL OR price_behavior IN ('free','paid')),
        ui_section TEXT NULL CHECK (ui_section IS NULL OR ui_section IN ('toppings','sauces','add_ins')),
        CHECK (action != 'choice' OR charge_reason = 'included_choice')
      );
    ''');
    raw.execute('''
      CREATE TABLE payments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL UNIQUE REFERENCES "transactions_legacy_v33" ("id"),
        method TEXT NOT NULL CHECK (method IN ('cash','card')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        paid_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    raw.execute('''
      INSERT INTO transactions (
        id,
        uuid,
        shift_id,
        user_id,
        status,
        subtotal_minor,
        modifier_total_minor,
        discount_type,
        discount_value_minor,
        discount_amount_minor,
        discount_reason,
        discount_applied_by,
        total_amount_minor,
        updated_at,
        idempotency_key,
        kitchen_printed,
        receipt_printed
      ) VALUES (
        1,
        'tx-v33',
        1,
        1,
        'draft',
        1000,
        200,
        NULL,
        0,
        0,
        NULL,
        NULL,
        1200,
        unixepoch(),
        'idem-v33',
        0,
        0
      );
    ''');
    raw.execute('PRAGMA user_version = 33;');
  } finally {
    raw.dispose();
  }
  return file;
}

Future<void> _expectNoLegacyV33References(AppDatabase db) async {
  final List<dynamic> legacyReferences = await db.customSelect('''
    SELECT type, name, tbl_name, sql
    FROM sqlite_master
    WHERE type IN ('table','trigger','view','index')
      AND sql LIKE '%transactions_legacy_v33%'
  ''').get();
  expect(legacyReferences, isEmpty);
}

Future<void> _expectTransactionChildSchema(AppDatabase db) async {
  final dynamic transactionLineSchema = await db.customSelect('''
    SELECT sql
    FROM sqlite_master
    WHERE type = 'table' AND name = 'transaction_lines'
  ''').getSingle();
  expect(
    transactionLineSchema.read<String>('sql'),
    contains('REFERENCES "transactions"'),
  );

  final dynamic paymentsSchema = await db.customSelect('''
    SELECT sql
    FROM sqlite_master
    WHERE type = 'table' AND name = 'payments'
  ''').getSingle();
  expect(
    paymentsSchema.read<String>('sql'),
    contains('REFERENCES "transactions"'),
  );
}

Future<void> _runTransactionChildSmoke(
  AppDatabase db, {
  required int draftTransactionId,
  required String draftUuid,
  required int sentTransactionId,
  required String sentUuid,
  required int lineId,
  required String lineUuid,
  required int modifierId,
  required String modifierUuid,
  required int paymentId,
  required String paymentUuid,
}) async {
  await db.customStatement('''
    INSERT INTO transactions (
      id,
      uuid,
      shift_id,
      user_id,
      status,
      subtotal_minor,
      modifier_total_minor,
      discount_type,
      discount_value_minor,
      discount_amount_minor,
      discount_reason,
      discount_applied_by,
      total_amount_minor,
      updated_at,
      idempotency_key,
      kitchen_printed,
      receipt_printed
    ) VALUES (
      $draftTransactionId,
      '$draftUuid',
      1,
      1,
      'draft',
      0,
      0,
      NULL,
      0,
      0,
      NULL,
      NULL,
      0,
      unixepoch(),
      'idem-$draftUuid',
      0,
      0
    )
  ''');

  await db.customStatement('''
    INSERT INTO transactions (
      id,
      uuid,
      shift_id,
      user_id,
      status,
      subtotal_minor,
      modifier_total_minor,
      discount_type,
      discount_value_minor,
      discount_amount_minor,
      discount_reason,
      discount_applied_by,
      total_amount_minor,
      updated_at,
      idempotency_key,
      kitchen_printed,
      receipt_printed
    ) VALUES (
      $sentTransactionId,
      '$sentUuid',
      1,
      1,
      'sent',
      1200,
      100,
      NULL,
      0,
      0,
      NULL,
      NULL,
      1300,
      unixepoch(),
      'idem-$sentUuid',
      0,
      0
    )
  ''');

  await db.customStatement('''
    INSERT INTO transaction_lines (
      id,
      uuid,
      transaction_id,
      product_id,
      product_name,
      unit_price_minor,
      quantity,
      line_total_minor,
      pricing_mode,
      removal_discount_total_minor
    ) VALUES (
      $lineId,
      '$lineUuid',
      $sentTransactionId,
      10,
      'Burger Meal',
      1200,
      1,
      1200,
      'standard',
      0
    )
  ''');

  await db.customStatement('''
    INSERT INTO order_modifiers (
      id,
      uuid,
      transaction_line_id,
      action,
      item_name,
      quantity,
      item_product_id,
      source_group_id,
      extra_price_minor,
      charge_reason,
      unit_price_minor,
      price_effect_minor,
      sort_key,
      price_behavior,
      ui_section
    ) VALUES (
      $modifierId,
      '$modifierUuid',
      $lineId,
      'add',
      'Cheese',
      1,
      NULL,
      NULL,
      100,
      'extra_add',
      100,
      100,
      0,
      'paid',
      'toppings'
    )
  ''');

  await db.customStatement('''
    INSERT INTO payments (
      id,
      uuid,
      transaction_id,
      method,
      amount_minor,
      paid_at
    ) VALUES (
      $paymentId,
      '$paymentUuid',
      $sentTransactionId,
      'cash',
      1300,
      unixepoch()
    )
  ''');

  final dynamic draftTransaction = await db.customSelect('''
    SELECT status
    FROM transactions
    WHERE id = $draftTransactionId
  ''').getSingle();
  expect(draftTransaction.read<String>('status'), 'draft');

  final dynamic sentTransaction = await db.customSelect('''
    SELECT status, total_amount_minor
    FROM transactions
    WHERE id = $sentTransactionId
  ''').getSingle();
  expect(sentTransaction.read<String>('status'), 'sent');
  expect(sentTransaction.read<int>('total_amount_minor'), 1300);

  final dynamic line = await db.customSelect('''
    SELECT transaction_id
    FROM transaction_lines
    WHERE id = $lineId
  ''').getSingle();
  expect(line.read<int>('transaction_id'), sentTransactionId);

  final dynamic modifier = await db.customSelect('''
    SELECT transaction_line_id
    FROM order_modifiers
    WHERE id = $modifierId
  ''').getSingle();
  expect(modifier.read<int>('transaction_line_id'), lineId);

  final dynamic payment = await db.customSelect('''
    SELECT transaction_id, amount_minor
    FROM payments
    WHERE id = $paymentId
  ''').getSingle();
  expect(payment.read<int>('transaction_id'), sentTransactionId);
  expect(payment.read<int>('amount_minor'), 1300);
}
