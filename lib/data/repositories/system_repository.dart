import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/models/database_export_result.dart';
import '../../domain/models/migration_log_entry.dart';
import '../database/app_database.dart';

class SystemRepository {
  SystemRepository(
    this._database, {
    Future<File> Function()? databaseFileResolver,
    Future<Directory> Function()? backupDirectoryResolver,
    AppLogger logger = const NoopAppLogger(),
  }) : _databaseFileResolver =
           databaseFileResolver ?? AppDatabase.resolveDefaultDatabaseFile,
       _backupDirectoryResolver = backupDirectoryResolver,
       _logger = logger;

  final AppDatabase _database;
  final Future<File> Function() _databaseFileResolver;
  final Future<Directory> Function()? _backupDirectoryResolver;
  final AppLogger _logger;

  int get schemaVersion => _database.schemaVersion;

  List<MigrationLogEntry> getMigrationHistory() => _database.migrationHistory;

  MigrationLogEntry? getLastMigrationFailure() =>
      _database.lastMigrationFailure;

  /// Returns the most recent backup by scanning the backup directory.
  /// Survives app restarts — not memory-dependent.
  Future<DatabaseExportResult?> getLastBackup() async {
    final Directory backupDir = await _resolveBackupDirectory();
    if (!await backupDir.exists()) {
      return null;
    }
    final List<FileSystemEntity> entries = await backupDir
        .list()
        .where(
          (FileSystemEntity e) =>
              e is File &&
              p.basename(e.path).startsWith('epos-backup-') &&
              e.path.endsWith('.sqlite'),
        )
        .toList();
    if (entries.isEmpty) {
      return null;
    }
    entries.sort(
      (FileSystemEntity a, FileSystemEntity b) =>
          p.basename(b.path).compareTo(p.basename(a.path)),
    );
    final File newest = entries.first as File;
    final FileStat stat = await newest.stat();
    return DatabaseExportResult(
      filePath: newest.path,
      createdAt: stat.modified.toUtc(),
      fileSizeBytes: stat.size,
    );
  }

  /// Creates a consistent backup using SQLite's `VACUUM INTO`.
  ///
  /// `VACUUM INTO` asks SQLite to materialize a brand new database file from
  /// the currently committed state. This is stronger than copying the live
  /// `.sqlite` file because it does not rely on the caller racing the WAL or
  /// the filesystem while writes are happening.
  ///
  /// The produced backup is then verified by opening it in a separate database
  /// instance and running `PRAGMA integrity_check`.
  Future<DatabaseExportResult> exportLocalDatabase() async {
    final File sourceFile = await _databaseFileResolver();
    if (!await sourceFile.exists()) {
      final DatabaseException exception = DatabaseException(
        'Local database file was not found at ${sourceFile.path}.',
      );
      _logger.error(
        eventType: 'backup_export_failed',
        message: exception.message,
        metadata: <String, Object?>{'source_path': sourceFile.path},
        error: exception,
      );
      throw exception;
    }

    final Directory backupDirectory = await _resolveBackupDirectory();
    await backupDirectory.create(recursive: true);

    final DateTime now = DateTime.now().toUtc();
    final String safeTimestamp = now.toIso8601String().replaceAll(':', '-');
    final File targetFile = File(
      p.join(backupDirectory.path, 'epos-backup-$safeTimestamp.sqlite'),
    );
    _logger.audit(
      eventType: 'backup_export_started',
      message: 'Backup export started.',
      metadata: <String, Object?>{
        'source_path': sourceFile.path,
        'target_path': targetFile.path,
      },
    );

    try {
      await _createSnapshotWithVacuumInto(targetFile);

      await verifyBackupIntegrity(targetFile);
      _logger.audit(
        eventType: 'backup_restore_verified',
        message: 'Backup snapshot passed integrity verification.',
        metadata: <String, Object?>{'target_path': targetFile.path},
      );

      final int fileSize = await targetFile.length();
      final DatabaseExportResult result = DatabaseExportResult(
        filePath: targetFile.path,
        createdAt: now,
        fileSizeBytes: fileSize,
      );
      _logger.audit(
        eventType: 'backup_export_succeeded',
        message: 'Backup export completed successfully.',
        metadata: <String, Object?>{
          'target_path': result.filePath,
          'file_size_bytes': result.fileSizeBytes,
        },
      );
      return result;
    } catch (error, stackTrace) {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      _logger.error(
        eventType: 'backup_export_failed',
        message: 'Backup export failed.',
        metadata: <String, Object?>{
          'source_path': sourceFile.path,
          'target_path': targetFile.path,
        },
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Opens the backup file in an isolated database instance and runs
  /// `PRAGMA integrity_check`.
  /// Throws [DatabaseException] if the backup is corrupt.
  Future<void> verifyBackupIntegrity(File backupFile) async {
    final AppDatabase verifyDb = AppDatabase.forFile(backupFile);
    try {
      final List<Map<String, Object?>> rows = await verifyDb
          .customSelect('PRAGMA integrity_check;')
          .map((row) => row.data)
          .get();
      final bool ok =
          rows.isNotEmpty &&
          rows.first.values.first?.toString().toLowerCase() == 'ok';
      if (!ok) {
        throw DatabaseException(
          'Backup integrity check failed: ${rows.firstOrNull}',
        );
      }
    } finally {
      await verifyDb.close();
    }
  }

  Future<void> _createSnapshotWithVacuumInto(File targetFile) async {
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    final String escapedPath = targetFile.path.replaceAll("'", "''");
    await _database.customStatement("VACUUM INTO '$escapedPath';");
  }

  Future<Directory> _resolveBackupDirectory() async {
    if (_backupDirectoryResolver != null) {
      return _backupDirectoryResolver();
    }
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return Directory(p.join(documentsDirectory.path, 'backups'));
  }
}
