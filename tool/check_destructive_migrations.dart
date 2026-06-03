import 'dart:io';

import 'destructive_migration_checker.dart';

Future<void> main(List<String> args) async {
  final String sourcePath =
      args.where((String arg) => !arg.startsWith('--')).firstOrNull ??
      'lib/data/database/app_database.dart';
  final bool failOnWarning = args.contains('--fail-on-warning');
  final File sourceFile = File(sourcePath);

  if (!await sourceFile.exists()) {
    stderr.writeln('Migration source not found: $sourcePath');
    exitCode = 2;
    return;
  }

  final List<DestructiveMigrationWarning> warnings =
      findDestructiveMigrationWarnings(await sourceFile.readAsString());
  if (warnings.isEmpty) {
    stdout.writeln('No destructive migration patterns found in $sourcePath.');
    return;
  }

  stdout.writeln(
    'WARNING: destructive migration patterns found in $sourcePath. '
    'Review these before increasing schemaVersion:',
  );
  for (final DestructiveMigrationWarning warning in warnings) {
    stdout.writeln(
      '  line ${warning.lineNumber} [${warning.kind.name}]: ${warning.line}',
    );
  }

  if (failOnWarning) {
    exitCode = 1;
  }
}
