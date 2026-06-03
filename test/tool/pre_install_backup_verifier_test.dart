import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../tool/pre_install_backup_verifier.dart';

void main() {
  group('verifyPreInstallBackup', () {
    test(
      'accepts non-empty source and backup files with matching hashes',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_backup_verifier_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final File source = File('${tempDir.path}/epos.sqlite');
        final File backup = File(
          '${tempDir.path}/backups/pre-install-20260603-191509-epos.sqlite',
        );
        await backup.parent.create(recursive: true);
        await source.writeAsBytes(<int>[1, 2, 3, 4, 5], flush: true);
        await backup.writeAsBytes(<int>[1, 2, 3, 4, 5], flush: true);

        final PreInstallBackupVerificationResult result =
            await verifyPreInstallBackup(source: source, backup: backup);

        expect(result.isValid, isTrue);
        expect(result.sourceLength, 5);
        expect(result.backupLength, 5);
        expect(result.sourceSha256, result.backupSha256);
        expect(result.problems, isEmpty);
      },
    );

    test('rejects empty backup files', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'epos_backup_verifier_empty_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final File source = File('${tempDir.path}/epos.sqlite');
      final File backup = File('${tempDir.path}/backups/pre-install.sqlite');
      await backup.parent.create(recursive: true);
      await source.writeAsBytes(<int>[1], flush: true);
      await backup.writeAsBytes(<int>[], flush: true);

      final PreInstallBackupVerificationResult result =
          await verifyPreInstallBackup(source: source, backup: backup);

      expect(result.isValid, isFalse);
      expect(result.problems, contains('Backup database is empty.'));
    });

    test('rejects mismatched source and backup hashes', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'epos_backup_verifier_hash_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final File source = File('${tempDir.path}/epos.sqlite');
      final File backup = File('${tempDir.path}/backups/pre-install.sqlite');
      await backup.parent.create(recursive: true);
      await source.writeAsBytes(<int>[1, 2, 3], flush: true);
      await backup.writeAsBytes(<int>[9, 8, 7], flush: true);

      final PreInstallBackupVerificationResult result =
          await verifyPreInstallBackup(source: source, backup: backup);

      expect(result.isValid, isFalse);
      expect(result.problems, contains('Database SHA-256 hash mismatch.'));
    });

    test('verifies WAL and SHM sidecars when present', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'epos_backup_verifier_sidecar_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final File source = File('${tempDir.path}/epos.sqlite');
      final File backup = File('${tempDir.path}/backups/pre-install.sqlite');
      await backup.parent.create(recursive: true);
      await source.writeAsBytes(<int>[1], flush: true);
      await backup.writeAsBytes(<int>[1], flush: true);
      await File('${source.path}-wal').writeAsBytes(<int>[2, 3], flush: true);
      await File('${backup.path}-wal').writeAsBytes(<int>[2, 3], flush: true);
      await File('${source.path}-shm').writeAsBytes(<int>[4, 5], flush: true);
      await File('${backup.path}-shm').writeAsBytes(<int>[4, 5], flush: true);

      final PreInstallBackupVerificationResult result =
          await verifyPreInstallBackup(source: source, backup: backup);

      expect(result.isValid, isTrue);
      expect(result.sidecars, hasLength(2));
      expect(
        result.sidecars.map((SidecarVerification sidecar) => sidecar.suffix),
        <String>['-wal', '-shm'],
      );
      expect(
        result.sidecars.every((SidecarVerification sidecar) => sidecar.matches),
        isTrue,
      );
    });
  });

  group('findLatestPreInstallBackup', () {
    test('chooses the newest backup by filename timestamp', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'epos_latest_backup_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File(
        '${tempDir.path}/pre-install-20260603-190000-epos.sqlite',
      ).writeAsBytes(<int>[1], flush: true);
      final File newest = File(
        '${tempDir.path}/pre-install-20260603-220000-epos.sqlite',
      );
      await newest.writeAsBytes(<int>[2], flush: true);
      await File(
        '${tempDir.path}/pre-install-20260603-210000-epos.sqlite',
      ).writeAsBytes(<int>[3], flush: true);

      expect(
        (await findLatestPreInstallBackup(tempDir)).replaceAll('\\', '/'),
        newest.path.replaceAll('\\', '/'),
      );
    });
  });

  group('performRollbackDryRun', () {
    test(
      'restores backup to a temporary path and verifies integrity_check ok',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_rollback_dry_run_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final File backup = File(
          '${tempDir.path}/backups/pre-install-20260603-220000-epos.sqlite',
        );
        await backup.parent.create(recursive: true);
        _createValidSqliteDatabase(backup.path);

        final RollbackDryRunResult result = await performRollbackDryRun(
          backup: backup,
          tempRoot: tempDir,
        );

        expect(result.isValid, isTrue);
        expect(result.integrityCheckResult, 'ok');
        expect(result.restoredDatabase.path, isNot(backup.path));
        expect(await result.restoredDatabase.exists(), isTrue);
      },
    );

    test(
      'restores WAL and SHM sidecars to the temporary path when present',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_rollback_dry_run_sidecar_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final File backup = File(
          '${tempDir.path}/backups/pre-install-20260603-220000-epos.sqlite',
        );
        await backup.parent.create(recursive: true);
        _createValidSqliteDatabase(backup.path);
        await File('${backup.path}-wal').writeAsBytes(<int>[], flush: true);
        await File('${backup.path}-shm').writeAsBytes(<int>[], flush: true);

        final RollbackDryRunResult result = await performRollbackDryRun(
          backup: backup,
          tempRoot: tempDir,
        );

        expect(result.isValid, isTrue);
        expect(result.restoredSidecars.map((File file) => file.path), <String>[
          '${result.restoredDatabase.path}-wal',
          '${result.restoredDatabase.path}-shm',
        ]);
        expect(
          await File('${result.restoredDatabase.path}-wal').exists(),
          isTrue,
        );
        expect(
          await File('${result.restoredDatabase.path}-shm').exists(),
          isTrue,
        );
      },
    );
  });
}

void _createValidSqliteDatabase(String path) {
  final Database database = sqlite3.open(path);
  try {
    database.execute('CREATE TABLE test_data (id INTEGER PRIMARY KEY);');
    database.execute('INSERT INTO test_data (id) VALUES (1);');
  } finally {
    database.dispose();
  }
}
