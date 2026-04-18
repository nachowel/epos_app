import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:flutter_test/flutter_test.dart';

/// A structural snapshot of a single SQLite table: columns + indexes.
///
/// Parity between a fresh current schema and a migrated schema
/// (v1 upgraded through all steps to the current version) is defined as
/// equality across
/// every field captured here.
class _TableShape {
  const _TableShape({required this.columns, required this.indexes});

  final List<_ColumnShape> columns;
  final List<_IndexShape> indexes;

  Map<String, Object?> toJson() => <String, Object?>{
    'columns': columns.map((_ColumnShape c) => c.toJson()).toList(),
    'indexes': indexes.map((_IndexShape i) => i.toJson()).toList(),
  };
}

class _ColumnShape {
  const _ColumnShape({
    required this.cid,
    required this.name,
    required this.type,
    required this.notNull,
    required this.defaultValue,
    required this.pkPosition,
  });

  final int cid;
  final String name;
  final String type;
  final bool notNull;
  final String? defaultValue;
  final int pkPosition;

  Map<String, Object?> toJson() => <String, Object?>{
    'cid': cid,
    'name': name,
    'type': type,
    'notNull': notNull,
    'dflt_value': defaultValue,
    'pk': pkPosition,
  };
}

class _IndexShape {
  const _IndexShape({
    required this.name,
    required this.unique,
    required this.origin,
    required this.partial,
    required this.columns,
  });

  final String name;
  final bool unique;
  final String origin;
  final bool partial;
  final List<_IndexColumn> columns;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'unique': unique,
    'origin': origin,
    'partial': partial,
    'columns': columns.map((_IndexColumn c) => c.toJson()).toList(),
  };
}

class _IndexColumn {
  const _IndexColumn({required this.seqno, required this.name});

  final int seqno;
  final String name;

  Map<String, Object?> toJson() => <String, Object?>{
    'seqno': seqno,
    'name': name,
  };
}

Future<_TableShape> _readTableShape(AppDatabase db, String tableName) async {
  final List<QueryRow> columnRows = await db
      .customSelect('PRAGMA table_info($tableName);')
      .get();
  final List<_ColumnShape> columns = columnRows
      .map(
        (QueryRow row) => _ColumnShape(
          cid: row.read<int>('cid'),
          name: row.read<String>('name'),
          type: row.read<String>('type'),
          notNull: row.read<int>('notnull') == 1,
          defaultValue: row.readNullable<String>('dflt_value'),
          pkPosition: row.read<int>('pk'),
        ),
      )
      .toList(growable: false);

  final List<QueryRow> indexRows = await db
      .customSelect('PRAGMA index_list($tableName);')
      .get();
  final List<_IndexShape> indexes = <_IndexShape>[];
  for (final QueryRow row in indexRows) {
    final String indexName = row.read<String>('name');
    final List<QueryRow> indexInfoRows = await db
        .customSelect('PRAGMA index_info($indexName);')
        .get();
    final List<_IndexColumn> indexColumns = indexInfoRows
        .map(
          (QueryRow r) => _IndexColumn(
            seqno: r.read<int>('seqno'),
            name: r.read<String>('name'),
          ),
        )
        .toList(growable: false);
    indexes.add(
      _IndexShape(
        name: indexName,
        unique: row.read<int>('unique') == 1,
        origin: row.read<String>('origin'),
        partial: row.read<int>('partial') == 1,
        columns: indexColumns,
      ),
    );
  }

  // Normalize index ordering so the comparison is deterministic regardless of
  // the order SQLite happens to report them in.
  indexes.sort((_IndexShape a, _IndexShape b) => a.name.compareTo(b.name));

  return _TableShape(columns: columns, indexes: indexes);
}

AppDatabase _createFreshDatabase() {
  // A freshly created AppDatabase goes through onCreate only; no migrations run.
  return AppDatabase(NativeDatabase.memory());
}

AppDatabase _createV1ThenMigrateToCurrent() {
  final QueryExecutor rawDb = NativeDatabase.memory(
    setup: (db) {
      db.execute('PRAGMA foreign_keys = ON;');
      // v1 users (legacy 'staff' role).
      db.execute('''
        CREATE TABLE users (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','staff')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      db.execute('''
        CREATE TABLE categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          image_url TEXT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      db.execute('''
        CREATE TABLE products (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
          image_url TEXT NULL,
          has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''');
      db.execute('''
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      db.execute('''
        CREATE TABLE shifts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          opened_by INTEGER NOT NULL,
          opened_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          closed_by INTEGER NULL,
          closed_at INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
        );
      ''');
      db.execute('''
        CREATE TABLE transactions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          shift_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          table_number INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','paid','cancelled')),
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
      db.execute('''
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
      db.execute('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add')),
          item_name TEXT NOT NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0)
        );
      ''');
      db.execute('''
        CREATE TABLE payments (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_id INTEGER NOT NULL UNIQUE,
          method TEXT NOT NULL CHECK (method IN ('cash','card')),
          amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
          paid_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      db.execute('''
        CREATE TABLE report_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          visibility_ratio REAL NOT NULL DEFAULT 1.0 CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
          updated_by INTEGER NULL,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      db.execute('''
        CREATE TABLE printer_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          device_name TEXT NOT NULL,
          device_address TEXT NOT NULL,
          paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments')),
          record_uuid TEXT NOT NULL,
          operation TEXT NOT NULL DEFAULT 'upsert' CHECK (operation IN ('upsert')),
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','synced','failed')),
          attempt_count INTEGER NOT NULL DEFAULT 0,
          last_attempt_at INTEGER NULL,
          synced_at INTEGER NULL,
          error_message TEXT NULL
        );
      ''');
      db.execute(
        "CREATE UNIQUE INDEX ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
      );

      // Seed the minimum rows required so migrations that touch real data
      // (e.g. legacy role normalization) have something to transform.
      db.execute(
        "INSERT INTO users (name, pin, role) VALUES ('Legacy Staff', '1234', 'staff');",
      );
      db.execute(
        "INSERT INTO users (name, password, role) VALUES ('Admin', 'secret', 'admin');",
      );
      db.execute("INSERT INTO shifts (opened_by) VALUES (1);");

      db.execute('PRAGMA user_version = 1;');
    },
  );

  return AppDatabase(rawDb);
}

/// Normalizes parts of the `PRAGMA table_info` output that SQLite reports
/// with equivalent but textually different encodings.
///
/// * Default value literals for non-TEXT columns come back as either `'0'` or
///   `0`, wrapped in parentheses when synthesized via `DEFAULT (...)`.
///   We unify these so `DEFAULT 0` and `DEFAULT (0)` compare equal.
/// * Whitespace and surrounding parentheses around integer/boolean defaults
///   are stripped.
/// * Case differences in type names (`INTEGER` vs `integer`) are collapsed.
/// Default expressions SQLite reports in `PRAGMA table_info` that are known
/// to be semantically equivalent. SQLite treats these as the same function
/// at INSERT time — both return the current Unix epoch as an integer — but
/// the text captured by `dflt_value` differs depending on whether the
/// column was created by Drift's generator (`CAST(strftime('%s', ...))`) or
/// by hand-written migration SQL (`unixepoch()`).
///
/// Collapsing these to a single canonical form avoids producing false
/// "default drift" failures for what is a purely textual difference.
const Set<String> _currentTimestampEquivalents = <String>{
  "cast(strftime('%s', current_timestamp) as integer)",
  'unixepoch()',
};

const String _canonicalCurrentTimestamp = '<<current_timestamp_epoch>>';

String? _normalizeDefault(String? raw) {
  if (raw == null) {
    return null;
  }
  String value = raw.trim();
  while (value.startsWith('(') && value.endsWith(')')) {
    final String inner = value.substring(1, value.length - 1).trim();
    if (inner.isEmpty) {
      break;
    }
    value = inner;
  }
  final String lower = value.toLowerCase();
  if (_currentTimestampEquivalents.contains(lower)) {
    return _canonicalCurrentTimestamp;
  }
  return lower;
}

String _normalizeType(String raw) => raw.toUpperCase();

/// Produces a JSON-like map that two _TableShape instances can be compared by,
/// collapsing harmless textual differences.
Map<String, Object?> _canonicalize(_TableShape shape) {
  return <String, Object?>{
    'columns': shape.columns
        .map(
          (_ColumnShape c) => <String, Object?>{
            'cid': c.cid,
            'name': c.name,
            'type': _normalizeType(c.type),
            'notNull': c.notNull,
            'dflt_value': _normalizeDefault(c.defaultValue),
            'pk': c.pkPosition,
          },
        )
        .toList(),
    'indexes': shape.indexes
        .map(
          (_IndexShape i) => <String, Object?>{
            'name': i.name,
            'unique': i.unique,
            // `origin` may be `c` (user CREATE INDEX), `u` (UNIQUE constraint),
            // or `pk` (primary key). Both schemas should agree.
            'origin': i.origin,
            'partial': i.partial,
            'columns': i.columns
                .map(
                  (_IndexColumn col) => <String, Object?>{
                    'seqno': col.seqno,
                    'name': col.name,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Migration schema parity (fresh vs v1→current)', () {
    late AppDatabase freshDb;
    late AppDatabase migratedDb;

    setUp(() async {
      freshDb = _createFreshDatabase();
      migratedDb = _createV1ThenMigrateToCurrent();
      // Touch each database so that the onCreate/onUpgrade callbacks run.
      // We query a cheap sqlite_master row to force the opening callback.
      await freshDb.customSelect('SELECT 1;').get();
      await migratedDb.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await freshDb.close();
      await migratedDb.close();
    });

    // Tables explicitly required by the parity request, plus a few adjacent
    // tables that the recently hardened migrations also touch structurally.
    // `payments` and `transaction_lines` are included because the v36
    // products rebuild drops and recreates the FK triggers that reference
    // products from these child tables; parity here is the ground-truth
    // that the rebuild did not drift their shape.
    const List<String> tablesUnderParity = <String>[
      'transactions',
      'transaction_lines',
      'products',
      'product_modifiers',
      'payments',
      'menu_settings',
      'meal_adjustment_profiles',
      'order_modifiers',
    ];

    for (final String tableName in tablesUnderParity) {
      test('$tableName has identical shape after fresh vs migrated', () async {
        final _TableShape freshShape = await _readTableShape(
          freshDb,
          tableName,
        );
        final _TableShape migratedShape = await _readTableShape(
          migratedDb,
          tableName,
        );

        // Column-level assertions, reported one by one for actionable diffs.
        expect(
          migratedShape.columns.map((_ColumnShape c) => c.name).toList(),
          equals(freshShape.columns.map((_ColumnShape c) => c.name).toList()),
          reason: '$tableName column ORDER / NAMES differ',
        );
        for (int i = 0; i < freshShape.columns.length; i++) {
          final _ColumnShape fresh = freshShape.columns[i];
          final _ColumnShape migrated = migratedShape.columns[i];
          expect(
            migrated.cid,
            fresh.cid,
            reason: '$tableName.${fresh.name} column position differs',
          );
          expect(
            _normalizeType(migrated.type),
            _normalizeType(fresh.type),
            reason: '$tableName.${fresh.name} column TYPE differs',
          );
          expect(
            migrated.notNull,
            fresh.notNull,
            reason: '$tableName.${fresh.name} NOT NULL flag differs',
          );
          expect(
            _normalizeDefault(migrated.defaultValue),
            _normalizeDefault(fresh.defaultValue),
            reason: '$tableName.${fresh.name} DEFAULT value differs',
          );
          expect(
            migrated.pkPosition,
            fresh.pkPosition,
            reason: '$tableName.${fresh.name} PRIMARY KEY position differs',
          );
        }

        // Index-level assertions: same named indexes, same uniqueness,
        // same covered columns in the same order.
        final List<String> freshIndexNames = freshShape.indexes
            .map((_IndexShape i) => i.name)
            .toList();
        final List<String> migratedIndexNames = migratedShape.indexes
            .map((_IndexShape i) => i.name)
            .toList();
        expect(
          migratedIndexNames,
          equals(freshIndexNames),
          reason: '$tableName index SET differs',
        );
        for (int i = 0; i < freshShape.indexes.length; i++) {
          final _IndexShape fresh = freshShape.indexes[i];
          final _IndexShape migrated = migratedShape.indexes[i];
          expect(
            migrated.unique,
            fresh.unique,
            reason: '$tableName index ${fresh.name} UNIQUE flag differs',
          );
          expect(
            migrated.partial,
            fresh.partial,
            reason: '$tableName index ${fresh.name} PARTIAL flag differs',
          );
          expect(
            migrated.columns.map((_IndexColumn c) => c.name).toList(),
            equals(fresh.columns.map((_IndexColumn c) => c.name).toList()),
            reason:
                '$tableName index ${fresh.name} covered COLUMNS / ORDER differ',
          );
        }

        // Final belt-and-braces: the full canonical JSON must match.
        expect(
          _canonicalize(migratedShape),
          equals(_canonicalize(freshShape)),
          reason: '$tableName canonical shape differs',
        );
      });
    }
  });
}
