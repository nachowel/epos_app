import 'dart:io';

import 'package:epos_app/data/sync/mirror_schema_contract.dart';
import 'package:epos_app/data/sync/phase1_sync_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MirrorSchemaContract', () {
    test(
      'rejects unexpected payload columns so mapper changes require a contract update',
      () {
        expect(
          () => MirrorSchemaContract.validatePayload(
            table: Phase1SyncTable.payments,
            payload: <String, Object?>{
              'uuid': '11111111-1111-1111-1111-111111111111',
              'transaction_uuid': '22222222-2222-2222-2222-222222222222',
              'method': 'card',
              'amount_minor': 1000,
              'paid_at': '2026-04-18T10:00:00.000Z',
              'unexpected_flag': true,
            },
            recordUuid: '11111111-1111-1111-1111-111111111111',
          ),
          throwsA(
            isA<MirrorSchemaContractViolation>()
                .having(
                  (MirrorSchemaContractViolation error) => error.tableName,
                  'tableName',
                  'payments',
                )
                .having(
                  (MirrorSchemaContractViolation error) => error.issues,
                  'issues',
                  contains('unexpected payload column: unexpected_flag'),
                ),
          ),
        );
      },
    );

    test('repo Supabase baseline stays aligned with the mirror schema contract', () {
      final String sql = File(
        'supabase/phase1_sales_sync_foundation.sql',
      ).readAsStringSync();

      expect(
        Phase1SyncContract.requiredRemoteTables,
        Phase1SyncTable.values
            .map((Phase1SyncTable table) => table.tableName)
            .toList(growable: false),
      );

      for (final Phase1SyncTable table in Phase1SyncTable.values) {
        final MirrorTableContract contract = MirrorSchemaContract.tableSpec(
          table,
        );
        final Map<String, _SqlColumnDefinition> sqlColumns =
            _parseSqlColumnsForTable(sql, contract.tableName);

        expect(
          sqlColumns.keys.toSet(),
          contract.remoteColumnNames,
          reason:
              'Supabase baseline column set drifted for ${contract.tableName}. '
              '${MirrorSchemaContract.releaseRule}',
        );

        for (final MirrorColumnContract column in contract.columns) {
          final _SqlColumnDefinition sqlColumn =
              sqlColumns[column.name] ??
              (throw StateError(
                'Missing parsed SQL column ${column.name} for ${contract.tableName}.',
              ));

          expect(
            sqlColumn.type,
            column.remoteType.sqlType,
            reason:
                'Supabase baseline type drifted for ${contract.tableName}.${column.name}.',
          );
          expect(
            sqlColumn.nullable,
            column.nullable,
            reason:
                'Supabase baseline nullability drifted for ${contract.tableName}.${column.name}.',
          );
          expect(
            sqlColumn.hasDefault,
            column.hasRemoteDefault,
            reason:
                'Supabase baseline default drifted for ${contract.tableName}.${column.name}.',
          );
        }
      }
    });
  });
}

Map<String, _SqlColumnDefinition> _parseSqlColumnsForTable(
  String sql,
  String tableName,
) {
  final RegExp tablePattern = RegExp(
    'create table if not exists public\\.$tableName \\((.*?)\\);',
    caseSensitive: false,
    dotAll: true,
  );
  final RegExpMatch? match = tablePattern.firstMatch(sql);
  if (match == null) {
    throw StateError('Could not find SQL table definition for $tableName.');
  }

  final String tableBody = match.group(1) ?? '';
  final Map<String, _SqlColumnDefinition> columns =
      <String, _SqlColumnDefinition>{};

  for (final String definition in _splitSqlDefinitions(tableBody)) {
    final String trimmed = definition.trim();
    if (trimmed.isEmpty || !_looksLikeColumnDefinition(trimmed)) {
      continue;
    }

    final int firstSpace = trimmed.indexOf(' ');
    final String columnName = trimmed.substring(0, firstSpace).trim();
    final String remainder = trimmed.substring(firstSpace + 1).trim();
    final int typeEnd = remainder.indexOf(' ');
    final String type =
        (typeEnd == -1 ? remainder : remainder.substring(0, typeEnd))
            .trim()
            .toLowerCase();
    final String lowered = trimmed.toLowerCase();

    columns[columnName] = _SqlColumnDefinition(
      type: type,
      nullable:
          !lowered.contains(' not null') && !lowered.contains(' primary key'),
      hasDefault: lowered.contains(' default '),
    );
  }

  return columns;
}

List<String> _splitSqlDefinitions(String body) {
  final List<String> definitions = <String>[];
  StringBuffer current = StringBuffer();
  int nestedParens = 0;

  for (final int rune in body.runes) {
    final String char = String.fromCharCode(rune);
    if (char == '(') {
      nestedParens += 1;
    } else if (char == ')') {
      nestedParens -= 1;
    }

    if (char == ',' && nestedParens == 0) {
      definitions.add(current.toString());
      current = StringBuffer();
      continue;
    }

    current.write(char);
  }

  if (current.length > 0) {
    definitions.add(current.toString());
  }

  return definitions;
}

bool _looksLikeColumnDefinition(String definition) {
  final String lowered = definition.toLowerCase();
  if (lowered.startsWith('check ') ||
      lowered.startsWith('constraint ') ||
      lowered.startsWith('primary key ') ||
      lowered.startsWith('foreign key ') ||
      lowered.startsWith('unique ')) {
    return false;
  }
  return RegExp(r'^[a-z_][a-z0-9_]*\s').hasMatch(lowered);
}

class _SqlColumnDefinition {
  const _SqlColumnDefinition({
    required this.type,
    required this.nullable,
    required this.hasDefault,
  });

  final String type;
  final bool nullable;
  final bool hasDefault;
}
