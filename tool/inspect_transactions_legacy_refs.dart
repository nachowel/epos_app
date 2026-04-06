import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final String dbPath = args.isNotEmpty
      ? args.first
      : r'C:\Users\nacho\Documents\epos.sqlite';

  final File dbFile = File(dbPath);
  if (!dbFile.existsSync()) {
    stderr.writeln('Database not found: $dbPath');
    exitCode = 1;
    return;
  }

  final Database db = sqlite3.open(dbPath);
  try {
    stdout.writeln('DB: $dbPath');
    stdout.writeln('');
    stdout.writeln('REFERENCES TO transactions_legacy_v24');
    final ResultSet references = db.select('''
      SELECT type, name, tbl_name, sql
      FROM sqlite_master
      WHERE sql LIKE '%transactions_legacy_v24%'
      ORDER BY type, name
    ''');
    if (references.isEmpty) {
      stdout.writeln('(empty)');
    } else {
      for (final Row row in references) {
        stdout.writeln('${row['type']} | ${row['name']} | ${row['tbl_name']}');
        stdout.writeln('${row['sql']}');
        stdout.writeln('');
      }
    }

    stdout.writeln('TABLES / TRIGGERS / VIEWS');
    final ResultSet objects = db.select('''
      SELECT name, type
      FROM sqlite_master
      WHERE type IN ('table','trigger','view')
      ORDER BY type, name
    ''');
    for (final Row row in objects) {
      stdout.writeln('${row['type']} | ${row['name']}');
    }
  } finally {
    db.dispose();
  }
}
