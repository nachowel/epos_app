import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/print_job_repository.dart';
import 'package:epos_app/domain/models/print_job.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('PrintJobRepository', () {
    test('only one claimant can move a pending job into printing', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final int transactionId = await _seedSentTransaction(db);
      final PrintJobRepository repository = PrintJobRepository(db);

      await repository.ensureQueued(
        transactionId: transactionId,
        target: PrintJobTarget.kitchen,
      );

      final List<Object?> results =
          await Future.wait<Object?>(<Future<Object?>>[
            () async {
              try {
                return await repository.markInProgress(
                  transactionId: transactionId,
                  target: PrintJobTarget.kitchen,
                  allowReprint: false,
                );
              } catch (error) {
                return error;
              }
            }(),
            () async {
              try {
                return await repository.markInProgress(
                  transactionId: transactionId,
                  target: PrintJobTarget.kitchen,
                  allowReprint: false,
                );
              } catch (error) {
                return error;
              }
            }(),
          ]);

      final PrintJob persisted = (await repository.getByTransactionIdAndTarget(
        transactionId: transactionId,
        target: PrintJobTarget.kitchen,
      ))!;

      expect(results.whereType<PrintJob>().length, 1);
      expect(results.whereType<PrintJobInProgressException>().length, 1);
      expect(persisted.status, PrintJobStatus.printing);
      expect(persisted.attemptCount, 1);
    });

    test(
      'failed job retry is deterministic and increments attempt count',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        final int transactionId = await _seedSentTransaction(db);
        final PrintJobRepository repository = PrintJobRepository(db);
        final DateTime startedAt = DateTime(2026, 1, 1, 10, 0, 0);

        await repository.ensureQueued(
          transactionId: transactionId,
          target: PrintJobTarget.kitchen,
          now: startedAt,
        );
        await repository.markInProgress(
          transactionId: transactionId,
          target: PrintJobTarget.kitchen,
          allowReprint: false,
          now: startedAt,
        );
        await repository.markFailed(
          transactionId: transactionId,
          target: PrintJobTarget.kitchen,
          error: 'Printer offline',
          now: startedAt.add(const Duration(seconds: 3)),
        );

        final PrintJob retried = await repository.markInProgress(
          transactionId: transactionId,
          target: PrintJobTarget.kitchen,
          allowReprint: true,
          now: startedAt.add(const Duration(seconds: 5)),
        );

        expect(retried.status, PrintJobStatus.printing);
        expect(retried.attemptCount, 2);
        expect(retried.lastError, isNull);
      },
    );

    test('printed job remains a no-op without explicit reprint', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final int transactionId = await _seedSentTransaction(db);
      final PrintJobRepository repository = PrintJobRepository(db);
      final DateTime completedAt = DateTime(2026, 1, 1, 11, 0, 0);

      await repository.ensureQueued(
        transactionId: transactionId,
        target: PrintJobTarget.kitchen,
        now: completedAt,
      );
      await repository.markPrinted(
        transactionId: transactionId,
        target: PrintJobTarget.kitchen,
        now: completedAt,
      );

      final PrintJob noOp = await repository.markInProgress(
        transactionId: transactionId,
        target: PrintJobTarget.kitchen,
        allowReprint: false,
        now: completedAt.add(const Duration(minutes: 1)),
      );

      expect(noOp.status, PrintJobStatus.printed);
      expect(noOp.attemptCount, 0);
    });

    test('stale printing job can be recovered by explicit retry', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final int transactionId = await _seedSentTransaction(db);
      final PrintJobRepository repository = PrintJobRepository(db);
      final DateTime firstAttemptAt = DateTime(2026, 1, 1, 12, 0, 0);

      await repository.ensureQueued(
        transactionId: transactionId,
        target: PrintJobTarget.receipt,
        now: firstAttemptAt,
      );
      await repository.markInProgress(
        transactionId: transactionId,
        target: PrintJobTarget.receipt,
        allowReprint: true,
        now: firstAttemptAt,
      );

      final PrintJob recovered = await repository.markInProgress(
        transactionId: transactionId,
        target: PrintJobTarget.receipt,
        allowReprint: true,
        now: firstAttemptAt.add(
          defaultPrintJobClaimStaleAfter + const Duration(seconds: 1),
        ),
      );

      expect(recovered.status, PrintJobStatus.printing);
      expect(recovered.attemptCount, 2);
      expect(
        recovered.lastAttemptAt,
        firstAttemptAt.add(
          defaultPrintJobClaimStaleAfter + const Duration(seconds: 1),
        ),
      );
    });
  });
}

Future<int> _seedSentTransaction(AppDatabase db) async {
  final int userId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: userId);
  return insertTransaction(
    db,
    uuid: 'print-job-${DateTime.now().microsecondsSinceEpoch}',
    shiftId: shiftId,
    userId: userId,
    status: 'sent',
    totalAmountMinor: 450,
  );
}
