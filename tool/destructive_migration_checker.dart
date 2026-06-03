enum DestructiveMigrationKind { dropTable, deleteFrom, legacyTableRename }

class DestructiveMigrationWarning {
  const DestructiveMigrationWarning({
    required this.lineNumber,
    required this.kind,
    required this.line,
  });

  final int lineNumber;
  final DestructiveMigrationKind kind;
  final String line;
}

List<DestructiveMigrationWarning> findDestructiveMigrationWarnings(
  String source,
) {
  final List<DestructiveMigrationWarning> warnings =
      <DestructiveMigrationWarning>[];
  final List<String> lines = source.split('\n');

  for (int index = 0; index < lines.length; index += 1) {
    final String line = lines[index].trim();
    final int lineNumber = index + 1;
    if (RegExp(r'\bDROP\s+TABLE\b', caseSensitive: false).hasMatch(line)) {
      warnings.add(
        DestructiveMigrationWarning(
          lineNumber: lineNumber,
          kind: DestructiveMigrationKind.dropTable,
          line: line,
        ),
      );
      continue;
    }
    if (RegExp(r'\bDELETE\s+FROM\b', caseSensitive: false).hasMatch(line)) {
      warnings.add(
        DestructiveMigrationWarning(
          lineNumber: lineNumber,
          kind: DestructiveMigrationKind.deleteFrom,
          line: line,
        ),
      );
      continue;
    }
    if (RegExp(
      r'\bALTER\s+TABLE\b.*\bRENAME\s+TO\b.*_legacy',
      caseSensitive: false,
    ).hasMatch(line)) {
      warnings.add(
        DestructiveMigrationWarning(
          lineNumber: lineNumber,
          kind: DestructiveMigrationKind.legacyTableRename,
          line: line,
        ),
      );
    }
  }

  return warnings;
}
