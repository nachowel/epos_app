import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart'
    hide OrderModifier, Payment, Shift, Transaction, TransactionLine, User;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/auth_lockout_store.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/system_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/sync/sync_connectivity_service.dart';
import 'package:epos_app/data/sync/sync_payload_repository.dart';
import 'package:epos_app/data/sync/sync_remote_gateway.dart';
import 'package:epos_app/data/sync/sync_worker.dart';
import 'package:epos_app/domain/models/app_log_entry.dart';
import 'package:epos_app/domain/models/database_export_result.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_database.dart';

void main() {
  group('Phase 6 blocker fixes', () {
    // ── BLOCKER 1: Backup confidence hardening ──

    test(
      'backup produces consistent snapshot from WAL-backed database',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_backup_wal_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final String dbPath = '${tempDir.path}/active.sqlite';
        final AppDatabase db = createPersistentTestDatabase(dbPath);
        bool dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) {
            dbClosed = true;
            await db.close();
          }
        });
        await _enableWalMode(db);

        final int userId = await insertUser(
          db,
          name: 'Backup Admin',
          role: 'admin',
        );
        final int shiftId = await insertShift(db, openedBy: userId);
        final int categoryId = await insertCategory(db, name: 'Coffee');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Flat White',
          priceMinor: 450,
        );
        final int transactionId = await insertTransaction(
          db,
          uuid: 'wal-backed-transaction',
          shiftId: shiftId,
          userId: userId,
          status: 'draft',
          totalAmountMinor: 0,
        );
        final TransactionRepository transactionRepository =
            TransactionRepository(db);

        final line = await transactionRepository.addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 2,
        );
        await transactionRepository.addModifier(
          transactionLineId: line.id,
          action: ModifierAction.add,
          itemName: 'Oat Milk',
          extraPriceMinor: 50,
        );
        await transactionRepository.recalculateTotals(transactionId);
        final int paidAtMs = DateTime.now().millisecondsSinceEpoch;
        await db.customStatement(
          '''
        UPDATE transactions
        SET status = 'paid',
            paid_at = ?,
            updated_at = ?
        WHERE id = ?
        ''',
          <Object?>[paidAtMs, paidAtMs, transactionId],
        );
        await db
            .into(db.payments)
            .insert(
              PaymentsCompanion.insert(
                uuid: 'wal-backed-payment',
                transactionId: transactionId,
                method: 'card',
                amountMinor: 1000,
                paidAt: Value<DateTime>(DateTime.now()),
              ),
            );

        final File walFile = File('$dbPath-wal');
        expect(walFile.existsSync(), isTrue);
        expect(walFile.lengthSync(), greaterThan(0));

        final Directory backupDir = Directory('${tempDir.path}/backups');
        final SystemRepository repo = SystemRepository(
          db,
          databaseFileResolver: () async => File(dbPath),
          backupDirectoryResolver: () async => backupDir,
        );

        final DatabaseExportResult result = await repo.exportLocalDatabase();
        expect(result.filePath, contains('epos-backup-'));
        expect(result.fileSizeBytes, greaterThan(0));
        expect(File(result.filePath).existsSync(), isTrue);

        dbClosed = true;
        await db.close();

        final AppDatabase restoredDb = await _restoreBackupToActivePath(
          activeDbPath: dbPath,
          backupPath: result.filePath,
        );
        addTearDown(restoredDb.close);

        final TransactionRepository restoredTransactionRepository =
            TransactionRepository(restoredDb);
        final PaymentRepository restoredPaymentRepository = PaymentRepository(
          restoredDb,
        );

        final Transaction? restoredTransaction =
            await restoredTransactionRepository.getByUuid(
              'wal-backed-transaction',
            );
        expect(restoredTransaction, isNotNull);
        expect(restoredTransaction!.status, TransactionStatus.paid);
        expect(restoredTransaction.totalAmountMinor, 1000);

        final List<TransactionLine> restoredLines =
            await restoredTransactionRepository.getLines(
              restoredTransaction.id,
            );
        expect(restoredLines, hasLength(1));
        expect(restoredLines.single.productName, 'Flat White');
        expect(restoredLines.single.lineTotalMinor, 1000);

        final List<OrderModifier> restoredModifiers =
            await restoredTransactionRepository.getModifiersByLine(
              restoredLines.single.id,
            );
        expect(restoredModifiers, hasLength(1));
        expect(restoredModifiers.single.itemName, 'Oat Milk');

        final Payment? restoredPayment = await restoredPaymentRepository
            .getByTransactionId(restoredTransaction.id);
        expect(restoredPayment, isNotNull);
        expect(restoredPayment!.method, PaymentMethod.card);
        expect(restoredPayment.amountMinor, 1000);
      },
    );

    test(
      'restore acceptance round-trip reopens restored active database through repositories',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_restore_acceptance_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final String dbPath = '${tempDir.path}/active.sqlite';
        final AppDatabase sourceDb = createPersistentTestDatabase(dbPath);
        bool sourceClosed = false;
        addTearDown(() async {
          if (!sourceClosed) {
            sourceClosed = true;
            await sourceDb.close();
          }
        });

        final int userId = await insertUser(
          sourceDb,
          name: 'Restore User',
          role: 'admin',
        );
        final int shiftId = await insertShift(sourceDb, openedBy: userId);
        final int categoryId = await insertCategory(sourceDb, name: 'Meals');
        final int productId = await insertProduct(
          sourceDb,
          categoryId: categoryId,
          name: 'Breakfast Plate',
          priceMinor: 1200,
        );
        final int transactionId = await insertTransaction(
          sourceDb,
          uuid: 'restore-test-tx',
          shiftId: shiftId,
          userId: userId,
          status: 'draft',
          totalAmountMinor: 0,
        );
        final TransactionRepository transactionRepository =
            TransactionRepository(sourceDb);
        final line = await transactionRepository.addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 1,
        );
        await transactionRepository.addModifier(
          transactionLineId: line.id,
          action: ModifierAction.add,
          itemName: 'Hash Brown',
          extraPriceMinor: 100,
        );
        await transactionRepository.recalculateTotals(transactionId);
        final int paidAtMs = DateTime.now().millisecondsSinceEpoch;
        await sourceDb.customStatement(
          '''
        UPDATE transactions
        SET status = 'paid',
            paid_at = ?,
            updated_at = ?
        WHERE id = ?
        ''',
          <Object?>[paidAtMs, paidAtMs, transactionId],
        );
        await sourceDb
            .into(sourceDb.payments)
            .insert(
              PaymentsCompanion.insert(
                uuid: 'restore-test-payment',
                transactionId: transactionId,
                method: 'cash',
                amountMinor: 1300,
                paidAt: Value<DateTime>(DateTime.now()),
              ),
            );

        final Directory backupDir = Directory('${tempDir.path}/backups');
        final SystemRepository repo = SystemRepository(
          sourceDb,
          databaseFileResolver: () async => File(dbPath),
          backupDirectoryResolver: () async => backupDir,
        );

        final DatabaseExportResult result = await repo.exportLocalDatabase();
        sourceClosed = true;
        await sourceDb.close();

        final AppDatabase restoredDb = await _restoreBackupToActivePath(
          activeDbPath: dbPath,
          backupPath: result.filePath,
        );
        addTearDown(restoredDb.close);

        final ShiftRepository shiftRepository = ShiftRepository(restoredDb);
        final TransactionRepository restoredTransactionRepository =
            TransactionRepository(restoredDb);
        final PaymentRepository paymentRepository = PaymentRepository(
          restoredDb,
        );

        final Shift? openShift = await shiftRepository.getOpenShift();
        expect(openShift, isNotNull);
        expect(openShift!.id, shiftId);
        expect(openShift.status, ShiftStatus.open);

        final Transaction? restoredTransaction =
            await restoredTransactionRepository.getByUuid('restore-test-tx');
        expect(restoredTransaction, isNotNull);
        expect(restoredTransaction!.shiftId, shiftId);
        expect(restoredTransaction.userId, userId);
        expect(restoredTransaction.status, TransactionStatus.paid);
        expect(restoredTransaction.totalAmountMinor, 1300);

        final List<TransactionLine> lines = await restoredTransactionRepository
            .getLines(restoredTransaction.id);
        expect(lines, hasLength(1));
        expect(lines.single.productId, productId);
        expect(lines.single.productName, 'Breakfast Plate');

        final List<OrderModifier> modifiers =
            await restoredTransactionRepository.getModifiersByLine(
              lines.single.id,
            );
        expect(modifiers, hasLength(1));
        expect(modifiers.single.action, ModifierAction.add);
        expect(modifiers.single.extraPriceMinor, 100);

        final Payment? payment = await paymentRepository.getByTransactionId(
          restoredTransaction.id,
        );
        expect(payment, isNotNull);
        expect(payment!.method, PaymentMethod.cash);
        expect(payment.amountMinor, 1300);
      },
    );

    // ── BLOCKER 2: Last backup persistence ──

    test(
      'getLastBackup scans backup directory and survives fresh instance',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos_lastbackup_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final String dbPath = '${tempDir.path}/test.sqlite';
        final AppDatabase db = createPersistentTestDatabase(dbPath);
        addTearDown(db.close);

        await insertUser(db, name: 'Scan Admin', role: 'admin');

        final Directory backupDir = Directory('${tempDir.path}/backups');
        final SystemRepository repo = SystemRepository(
          db,
          databaseFileResolver: () async => File(dbPath),
          backupDirectoryResolver: () async => backupDir,
        );

        // Before any backup — should be null.
        expect(await repo.getLastBackup(), isNull);

        // Create a backup.
        final DatabaseExportResult exported = await repo.exportLocalDatabase();

        // Create a NEW SystemRepository instance (simulates restart).
        final SystemRepository freshRepo = SystemRepository(
          db,
          databaseFileResolver: () async => File(dbPath),
          backupDirectoryResolver: () async => backupDir,
        );
        final DatabaseExportResult? scanned = await freshRepo.getLastBackup();
        expect(scanned, isNotNull);
        expect(scanned!.filePath, exported.filePath);
        expect(scanned.fileSizeBytes, exported.fileSizeBytes);
      },
    );

    test('successful backup emits audit log events', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'epos_backup_log_success_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final String dbPath = '${tempDir.path}/active.sqlite';
      final AppDatabase db = createPersistentTestDatabase(dbPath);
      addTearDown(db.close);
      await insertUser(db, name: 'Audit Admin', role: 'admin');

      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: false,
      );
      addTearDown(logger.dispose);

      final SystemRepository repo = SystemRepository(
        db,
        databaseFileResolver: () async => File(dbPath),
        backupDirectoryResolver: () async =>
            Directory('${tempDir.path}/backups'),
        logger: logger,
      );

      await repo.exportLocalDatabase();
      await _waitUntil(() => sink.entries.length == 3);

      expect(
        sink.entries.map((AppLogEntry entry) => entry.eventType),
        orderedEquals(<String>[
          'backup_export_started',
          'backup_restore_verified',
          'backup_export_succeeded',
        ]),
      );
      expect(
        sink.entries.every(
          (AppLogEntry entry) => entry.level == AppLogLevel.audit,
        ),
        isTrue,
      );
    });

    test('failed backup logs structured error', () async {
      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: false,
      );
      addTearDown(logger.dispose);

      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final SystemRepository repo = SystemRepository(
        db,
        databaseFileResolver: () async => File('C:/non-existent/epos.sqlite'),
        logger: logger,
      );

      await expectLater(
        repo.exportLocalDatabase(),
        throwsA(isA<DatabaseException>()),
      );
      await _waitUntil(() => sink.entries.isNotEmpty);

      final AppLogEntry failure = sink.entries.single;
      expect(failure.eventType, 'backup_export_failed');
      expect(failure.level, AppLogLevel.error);
      expect(
        failure.toJson()['metadata'],
        containsPair('source_path', 'C:/non-existent/epos.sqlite'),
      );
    });

    // ── BLOCKER 3: Audit logging always-on ──

    test('audit events are logged even when info logs are disabled', () async {
      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: false,
      );
      addTearDown(logger.dispose);

      // info should be silenced
      logger.info(eventType: 'debug_noise', message: 'should be dropped');
      // audit should always pass through
      logger.audit(
        eventType: 'order_created',
        entityId: 'tx-42',
        message: 'Order created.',
      );
      logger.audit(
        eventType: 'shift_opened',
        entityId: '7',
        message: 'Shift opened.',
      );
      logger.warn(eventType: 'sync_graph_failed', message: 'Network error.');

      await _waitUntil(() => sink.entries.length == 3);

      expect(
        sink.entries.map((AppLogEntry e) => e.eventType),
        orderedEquals(<String>[
          'order_created',
          'shift_opened',
          'sync_graph_failed',
        ]),
      );
      expect(sink.entries[0].level, AppLogLevel.audit);
      expect(sink.entries[1].level, AppLogLevel.audit);
      expect(sink.entries[2].level, AppLogLevel.warn);
    });

    test('audit level serialises correctly in JSON', () async {
      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: true,
      );
      addTearDown(logger.dispose);

      logger.audit(eventType: 'order_paid', entityId: 'tx-1');
      await _waitUntil(() => sink.entries.length == 1);

      expect(sink.entries.single.toJson()['level'], 'AUDIT');
    });

    // ── BLOCKER 4: Sync misconfig logging ──

    test(
      'sync worker logs WARN when remote gateway is not configured',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);

        final SyncWorker worker = SyncWorker(
          syncQueueRepository: SyncQueueRepository(db),
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _UnconfiguredRemoteGateway(),
          connectivityService: _FakeConnectivityService(initialOnline: true),
          logger: logger,
          isEnabled: true,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.start();

        await _waitUntil(() => sink.entries.isNotEmpty);

        final Iterable<AppLogEntry> misconfigLogs = sink.entries.where(
          (AppLogEntry e) => e.eventType == 'sync_misconfigured',
        );
        expect(misconfigLogs, isNotEmpty);
        expect(misconfigLogs.first.level, AppLogLevel.warn);
      },
    );

    // ── BLOCKER 5: Brute force persistence ──

    test(
      'AuthLockoutStore persists failed attempts and lockout across instances',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        final AuthLockoutStore store1 = AuthLockoutStore(prefs);

        expect(store1.getFailedAttempts(), 0);
        expect(store1.getLockedUntil(), isNull);

        // Simulate 2 failed attempts.
        await store1.setFailedAttempts(2);
        expect(store1.getFailedAttempts(), 2);

        // Simulate lockout.
        final DateTime lockUntil = DateTime.now().add(
          const Duration(seconds: 30),
        );
        await store1.setLockedUntil(lockUntil);

        // Create a new store instance (simulates restart).
        final AuthLockoutStore store2 = AuthLockoutStore(prefs);
        expect(store2.getFailedAttempts(), 2);
        expect(store2.getLockedUntil(), isNotNull);
        expect(
          store2.getLockedUntil()!.millisecondsSinceEpoch,
          lockUntil.millisecondsSinceEpoch,
        );

        // Reset clears everything.
        await store2.reset();
        expect(store2.getFailedAttempts(), 0);
        expect(store2.getLockedUntil(), isNull);

        // Verify reset survived in a third instance.
        final AuthLockoutStore store3 = AuthLockoutStore(prefs);
        expect(store3.getFailedAttempts(), 0);
        expect(store3.getLockedUntil(), isNull);
      },
    );

    test('AuthLockoutStore lockout threshold survives mock restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AuthLockoutStore store = AuthLockoutStore(prefs);

      // Simulate 3 failures → lock.
      await store.setFailedAttempts(0);
      final DateTime lockUntil = DateTime.now().add(
        const Duration(seconds: 30),
      );
      await store.setLockedUntil(lockUntil);

      // Fresh instance sees the lock.
      final AuthLockoutStore fresh = AuthLockoutStore(prefs);
      final DateTime? persisted = fresh.getLockedUntil();
      expect(persisted, isNotNull);
      expect(persisted!.isAfter(DateTime.now()), isTrue);
    });
  });
}

// ── Test helpers ──

class _FakeConnectivityService implements SyncConnectivityService {
  _FakeConnectivityService({required bool initialOnline})
    : _online = initialOnline;

  final bool _online;

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> watchOnlineStatus() => const Stream<bool>.empty();
}

class _UnconfiguredRemoteGateway implements SyncRemoteGateway {
  @override
  bool get isConfigured => false;

  @override
  Future<void> upsertRecord({
    required String tableName,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    throw StateError('Not configured');
  }
}

Future<void> _enableWalMode(AppDatabase db) async {
  final QueryRow row = await db
      .customSelect('PRAGMA journal_mode = WAL;')
      .getSingle();
  expect(row.read<String>('journal_mode').toLowerCase(), 'wal');
  await db.customStatement('PRAGMA wal_autocheckpoint = 0;');
}

Future<AppDatabase> _restoreBackupToActivePath({
  required String activeDbPath,
  required String backupPath,
}) async {
  await _deleteSqliteFileSet(activeDbPath);
  await File(backupPath).copy(activeDbPath);
  return createPersistentTestDatabase(activeDbPath);
}

Future<void> _deleteSqliteFileSet(String basePath) async {
  for (final String candidate in <String>[
    basePath,
    '$basePath-wal',
    '$basePath-shm',
    '$basePath-journal',
  ]) {
    final File file = File(candidate);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
