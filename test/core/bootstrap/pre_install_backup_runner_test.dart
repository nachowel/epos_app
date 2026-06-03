import 'dart:io';

import 'package:epos_app/core/bootstrap/pre_install_backup_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreInstallBackupRunner', () {
    test(
      'copies the resolved production database to a timestamped backup',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_pre_install_backup_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final File databaseFile = File('${tempDir.path}/epos.sqlite');
        await databaseFile.writeAsBytes(<int>[1, 2, 3, 4], flush: true);

        final PreInstallBackupRunner runner = PreInstallBackupRunner(
          databaseFileResolver: () async => databaseFile,
          clock: () => DateTime(2026, 6, 3, 19, 15, 9),
        );

        final PreInstallBackupResult result = await runner.run();

        expect(result.exitCode, 0);
        expect(result.skipped, isFalse);
        expect(
          result.backupFile?.path.replaceAll('\\', '/'),
          endsWith('/backups/pre-install-20260603-191509-epos.sqlite'),
        );
        final File backupFile = result.backupFile!;
        expect(await backupFile.exists(), isTrue);
        expect(await backupFile.length(), greaterThan(0));
        expect(await backupFile.length(), await databaseFile.length());
        expect(await _sha256(backupFile), await _sha256(databaseFile));
      },
    );

    test('copies sqlite sidecar files when they are present', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'epos_pre_install_sidecar_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final File databaseFile = File('${tempDir.path}/epos.sqlite');
      await databaseFile.writeAsBytes(<int>[10], flush: true);
      await File(
        '${databaseFile.path}-wal',
      ).writeAsBytes(<int>[20], flush: true);
      await File(
        '${databaseFile.path}-shm',
      ).writeAsBytes(<int>[30], flush: true);

      final PreInstallBackupRunner runner = PreInstallBackupRunner(
        databaseFileResolver: () async => databaseFile,
        clock: () => DateTime(2026, 6, 3, 19, 15, 9),
      );

      final PreInstallBackupResult result = await runner.run();
      final String backupPath = result.backupFile!.path;
      final File sourceWal = File('${databaseFile.path}-wal');
      final File sourceShm = File('${databaseFile.path}-shm');
      final File backupWal = File('$backupPath-wal');
      final File backupShm = File('$backupPath-shm');

      expect(await backupWal.exists(), isTrue);
      expect(await backupShm.exists(), isTrue);
      expect(await backupWal.length(), await sourceWal.length());
      expect(await backupShm.length(), await sourceShm.length());
      expect(await _sha256(backupWal), await _sha256(sourceWal));
      expect(await _sha256(backupShm), await _sha256(sourceShm));
    });

    test(
      'succeeds without creating a backup when no database exists',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_pre_install_missing_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final File databaseFile = File('${tempDir.path}/epos.sqlite');
        final PreInstallBackupRunner runner = PreInstallBackupRunner(
          databaseFileResolver: () async => databaseFile,
          clock: () => DateTime(2026, 6, 3, 19, 15, 9),
        );

        final PreInstallBackupResult result = await runner.run();

        expect(result.exitCode, 0);
        expect(result.skipped, isTrue);
        expect(result.backupFile, isNull);
        expect(await Directory('${tempDir.path}/backups').exists(), isFalse);
      },
    );
  });
}

Future<String> _sha256(File file) async {
  return sha256.convert(await file.readAsBytes()).toString();
}
