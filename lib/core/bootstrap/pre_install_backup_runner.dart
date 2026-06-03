import 'dart:io';

typedef DatabaseFileResolver = Future<File> Function();
typedef Clock = DateTime Function();

class PreInstallBackupResult {
  const PreInstallBackupResult._({
    required this.exitCode,
    required this.message,
    required this.skipped,
    this.backupFile,
    this.error,
  });

  factory PreInstallBackupResult.success({
    required File backupFile,
    required String message,
  }) {
    return PreInstallBackupResult._(
      exitCode: 0,
      message: message,
      skipped: false,
      backupFile: backupFile,
    );
  }

  factory PreInstallBackupResult.skipped({required String message}) {
    return PreInstallBackupResult._(
      exitCode: 0,
      message: message,
      skipped: true,
    );
  }

  factory PreInstallBackupResult.failure({
    required String message,
    required Object error,
  }) {
    return PreInstallBackupResult._(
      exitCode: 1,
      message: message,
      skipped: false,
      error: error,
    );
  }

  final int exitCode;
  final String message;
  final bool skipped;
  final File? backupFile;
  final Object? error;
}

class PreInstallBackupRunner {
  const PreInstallBackupRunner({
    required this.databaseFileResolver,
    this.clock = DateTime.now,
  });

  final DatabaseFileResolver databaseFileResolver;
  final Clock clock;

  Future<PreInstallBackupResult> run() async {
    try {
      final File databaseFile = await databaseFileResolver();
      if (!await databaseFile.exists()) {
        return PreInstallBackupResult.skipped(
          message:
              'No existing EPOS database was found at ${databaseFile.path}; pre-install backup skipped.',
        );
      }

      final Directory backupDirectory = Directory(
        '${databaseFile.parent.path}${Platform.pathSeparator}backups',
      );
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      final File backupFile = File(
        '${backupDirectory.path}${Platform.pathSeparator}${_backupFileName(clock())}',
      );
      await databaseFile.copy(backupFile.path);
      await _copySidecarIfPresent(
        sourcePath: '${databaseFile.path}-wal',
        destinationPath: '${backupFile.path}-wal',
      );
      await _copySidecarIfPresent(
        sourcePath: '${databaseFile.path}-shm',
        destinationPath: '${backupFile.path}-shm',
      );

      return PreInstallBackupResult.success(
        backupFile: backupFile,
        message: 'Pre-install database backup created at ${backupFile.path}.',
      );
    } catch (error) {
      return PreInstallBackupResult.failure(
        message: 'Pre-install database backup failed: $error',
        error: error,
      );
    }
  }

  static String _backupFileName(DateTime timestamp) {
    final String year = timestamp.year.toString().padLeft(4, '0');
    final String month = timestamp.month.toString().padLeft(2, '0');
    final String day = timestamp.day.toString().padLeft(2, '0');
    final String hour = timestamp.hour.toString().padLeft(2, '0');
    final String minute = timestamp.minute.toString().padLeft(2, '0');
    final String second = timestamp.second.toString().padLeft(2, '0');
    return 'pre-install-$year$month$day-$hour$minute$second-epos.sqlite';
  }

  static Future<void> _copySidecarIfPresent({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final File sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(destinationPath);
    }
  }
}
