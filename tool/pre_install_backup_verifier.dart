import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

class SidecarVerification {
  const SidecarVerification({
    required this.suffix,
    required this.sourceExists,
    required this.backupExists,
    required this.sourceLength,
    required this.backupLength,
    required this.sourceSha256,
    required this.backupSha256,
  });

  final String suffix;
  final bool sourceExists;
  final bool backupExists;
  final int sourceLength;
  final int backupLength;
  final String? sourceSha256;
  final String? backupSha256;

  bool get matches =>
      sourceExists &&
      backupExists &&
      sourceLength > 0 &&
      sourceLength == backupLength &&
      sourceSha256 == backupSha256;
}

class PreInstallBackupVerificationResult {
  const PreInstallBackupVerificationResult({
    required this.sourcePath,
    required this.backupPath,
    required this.sourceLength,
    required this.backupLength,
    required this.sourceSha256,
    required this.backupSha256,
    required this.sidecars,
    required this.problems,
  });

  final String sourcePath;
  final String backupPath;
  final int sourceLength;
  final int backupLength;
  final String? sourceSha256;
  final String? backupSha256;
  final List<SidecarVerification> sidecars;
  final List<String> problems;

  bool get isValid => problems.isEmpty;
}

class RollbackDryRunResult {
  const RollbackDryRunResult({
    required this.restoredDatabase,
    required this.restoredSidecars,
    required this.integrityCheckResult,
    required this.problems,
  });

  final File restoredDatabase;
  final List<File> restoredSidecars;
  final String? integrityCheckResult;
  final List<String> problems;

  bool get isValid => problems.isEmpty && integrityCheckResult == 'ok';
}

Future<PreInstallBackupVerificationResult> verifyPreInstallBackup({
  required File source,
  required File backup,
}) async {
  final List<String> problems = <String>[];
  final int sourceLength = await _lengthIfExists(source);
  final int backupLength = await _lengthIfExists(backup);
  final String? sourceSha256 = await _sha256IfExists(source);
  final String? backupSha256 = await _sha256IfExists(backup);

  if (!await source.exists()) {
    problems.add('Source database does not exist.');
  } else if (sourceLength == 0) {
    problems.add('Source database is empty.');
  }

  if (!await backup.exists()) {
    problems.add('Backup database does not exist.');
  } else if (backupLength == 0) {
    problems.add('Backup database is empty.');
  }

  if (sourceLength > 0 && backupLength > 0 && sourceLength != backupLength) {
    problems.add('Database byte size mismatch.');
  }
  if (sourceSha256 != null &&
      backupSha256 != null &&
      sourceSha256 != backupSha256) {
    problems.add('Database SHA-256 hash mismatch.');
  }

  final List<SidecarVerification> sidecars = <SidecarVerification>[];
  for (final String suffix in <String>['-wal', '-shm']) {
    final File sourceSidecar = File('${source.path}$suffix');
    if (!await sourceSidecar.exists()) {
      continue;
    }
    final File backupSidecar = File('${backup.path}$suffix');
    final SidecarVerification sidecar = SidecarVerification(
      suffix: suffix,
      sourceExists: true,
      backupExists: await backupSidecar.exists(),
      sourceLength: await _lengthIfExists(sourceSidecar),
      backupLength: await _lengthIfExists(backupSidecar),
      sourceSha256: await _sha256IfExists(sourceSidecar),
      backupSha256: await _sha256IfExists(backupSidecar),
    );
    sidecars.add(sidecar);
    if (!sidecar.backupExists) {
      problems.add('Backup sidecar ${backupSidecar.path} does not exist.');
    } else if (!sidecar.matches) {
      problems.add('Sidecar $suffix byte size or SHA-256 hash mismatch.');
    }
  }

  return PreInstallBackupVerificationResult(
    sourcePath: source.path,
    backupPath: backup.path,
    sourceLength: sourceLength,
    backupLength: backupLength,
    sourceSha256: sourceSha256,
    backupSha256: backupSha256,
    sidecars: sidecars,
    problems: problems,
  );
}

Future<RollbackDryRunResult> performRollbackDryRun({
  required File backup,
  Directory? tempRoot,
}) async {
  final List<String> problems = <String>[];
  final Directory restoreDirectory = tempRoot == null
      ? await Directory.systemTemp.createTemp('epos_rollback_dry_run_')
      : await Directory(
          '${tempRoot.path}${Platform.pathSeparator}rollback-dry-run-${DateTime.now().microsecondsSinceEpoch}',
        ).create(recursive: true);
  final File restoredDatabase = File(
    '${restoreDirectory.path}${Platform.pathSeparator}epos.sqlite',
  );
  final List<File> restoredSidecars = <File>[];

  try {
    if (!await backup.exists()) {
      problems.add('Backup database does not exist.');
      return RollbackDryRunResult(
        restoredDatabase: restoredDatabase,
        restoredSidecars: restoredSidecars,
        integrityCheckResult: null,
        problems: problems,
      );
    }

    await backup.copy(restoredDatabase.path);
    for (final String suffix in <String>['-wal', '-shm']) {
      final File backupSidecar = File('${backup.path}$suffix');
      if (!await backupSidecar.exists()) {
        continue;
      }
      final File restoredSidecar = File('${restoredDatabase.path}$suffix');
      await backupSidecar.copy(restoredSidecar.path);
      restoredSidecars.add(restoredSidecar);
    }

    final Database database = sqlite3.open(restoredDatabase.path);
    String? integrityCheckResult;
    try {
      final ResultSet rows = database.select('PRAGMA integrity_check;');
      integrityCheckResult = rows.isEmpty
          ? null
          : rows.first.values.first as String?;
    } finally {
      database.dispose();
    }

    if (integrityCheckResult != 'ok') {
      problems.add(
        'Restored database integrity_check returned ${integrityCheckResult ?? 'no result'}.',
      );
    }

    return RollbackDryRunResult(
      restoredDatabase: restoredDatabase,
      restoredSidecars: restoredSidecars,
      integrityCheckResult: integrityCheckResult,
      problems: problems,
    );
  } catch (error) {
    problems.add('Rollback dry-run failed: $error');
    return RollbackDryRunResult(
      restoredDatabase: restoredDatabase,
      restoredSidecars: restoredSidecars,
      integrityCheckResult: null,
      problems: problems,
    );
  }
}

Future<void> main(List<String> args) async {
  final File source = File(
    _argumentValue(args, '--source') ?? _defaultDatabasePath(),
  );
  final File backup = File(
    _argumentValue(args, '--backup') ??
        await findLatestPreInstallBackup(
          Directory('${source.parent.path}${Platform.pathSeparator}backups'),
        ),
  );

  final PreInstallBackupVerificationResult result =
      await verifyPreInstallBackup(source: source, backup: backup);
  stdout.writeln('Source: ${result.sourcePath}');
  stdout.writeln('Backup: ${result.backupPath}');
  stdout.writeln(
    'Database bytes: source=${result.sourceLength}, backup=${result.backupLength}',
  );
  stdout.writeln(
    'Database sha256: source=${result.sourceSha256}, backup=${result.backupSha256}',
  );
  for (final SidecarVerification sidecar in result.sidecars) {
    stdout.writeln(
      'Sidecar ${sidecar.suffix}: source=${sidecar.sourceLength} bytes, '
      'backup=${sidecar.backupLength} bytes, matches=${sidecar.matches}',
    );
  }

  if (result.isValid) {
    stdout.writeln('Pre-install backup verification passed.');
    final RollbackDryRunResult rollbackDryRun = await performRollbackDryRun(
      backup: backup,
    );
    stdout.writeln(
      'Rollback dry-run restored temp database: ${rollbackDryRun.restoredDatabase.path}',
    );
    for (final File sidecar in rollbackDryRun.restoredSidecars) {
      stdout.writeln('Rollback dry-run restored sidecar: ${sidecar.path}');
    }
    stdout.writeln(
      'Rollback dry-run integrity_check: ${rollbackDryRun.integrityCheckResult}',
    );
    if (rollbackDryRun.isValid) {
      stdout.writeln('Rollback dry-run verification passed.');
      return;
    }

    stderr.writeln('Rollback dry-run verification failed:');
    for (final String problem in rollbackDryRun.problems) {
      stderr.writeln('  - $problem');
    }
    exitCode = 1;
    return;
  }

  stderr.writeln('Pre-install backup verification failed:');
  for (final String problem in result.problems) {
    stderr.writeln('  - $problem');
  }
  exitCode = 1;
}

Future<int> _lengthIfExists(File file) async {
  if (!await file.exists()) {
    return 0;
  }
  return file.length();
}

Future<String?> _sha256IfExists(File file) async {
  if (!await file.exists()) {
    return null;
  }
  return sha256.convert(await file.readAsBytes()).toString();
}

String? _argumentValue(List<String> args, String name) {
  final int index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

String _defaultDatabasePath() {
  final String userProfile = Platform.environment['USERPROFILE'] ?? '';
  return '$userProfile${Platform.pathSeparator}Documents${Platform.pathSeparator}epos.sqlite';
}

Future<String> findLatestPreInstallBackup(Directory backupDirectory) async {
  if (!await backupDirectory.exists()) {
    return '${backupDirectory.path}${Platform.pathSeparator}pre-install-missing-epos.sqlite';
  }

  final List<FileSystemEntity> backups = await backupDirectory
      .list()
      .where(
        (FileSystemEntity entity) =>
            entity is File &&
            entity.path.contains('pre-install-') &&
            entity.path.endsWith('-epos.sqlite'),
      )
      .toList();
  backups.sort((FileSystemEntity left, FileSystemEntity right) {
    return _fileName(right.path).compareTo(_fileName(left.path));
  });
  if (backups.isEmpty) {
    return '${backupDirectory.path}${Platform.pathSeparator}pre-install-missing-epos.sqlite';
  }
  return backups.first.path;
}

String _fileName(String path) {
  return path.split(RegExp(r'[\\/]')).last;
}
