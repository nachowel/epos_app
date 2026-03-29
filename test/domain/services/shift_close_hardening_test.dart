import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/draft_order_policy.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/shift_close_readiness.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Shift close hardening', () {
    test('fresh draft blocks final close with a fresh-draft reason', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await insertTransaction(
        db,
        uuid: 'fresh-draft-close-block',
        shiftId: shiftId,
        userId: adminId,
        status: 'draft',
        totalAmountMinor: 0,
        updatedAt: DateTime(2026, 1, 1, 12, 0, 0),
      );

      final reportService = _makeReportService(db);

      await expectLater(
        reportService.runAdminFinalCloseWithCountedCash(
          user: _admin(adminId),
          countedCashMinor: 0,
          now: DateTime(2026, 1, 1, 12, 30, 0),
        ),
        throwsA(
            isA<ShiftCloseBlockedException>().having(
              (ShiftCloseBlockedException error) =>
                  error.readiness.blockingReason,
              'blockingReason',
              ShiftCloseBlockReason.freshDraftsPending,
            ).having(
              (ShiftCloseBlockedException error) => error.suggestedAction,
              'suggestedAction',
              ShiftCloseSuggestedAction.sendOrDiscardFreshDrafts,
            ),
          ),
        );
    });

    test(
      'stale draft blocks final close with cleanup-specific reason',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final DateTime now = DateTime(2026, 1, 1, 12, 0, 0);
        await insertTransaction(
          db,
          uuid: 'stale-draft-close-block',
          shiftId: shiftId,
          userId: adminId,
          status: 'draft',
          totalAmountMinor: 0,
          updatedAt: now.subtract(
            DraftOrderPolicy.staleThreshold + const Duration(minutes: 1),
          ),
        );

        final ShiftSessionService shiftSessionService = ShiftSessionService(
          ShiftRepository(db),
        );
        final ShiftCloseReadiness readiness = await shiftSessionService
            .getShiftCloseReadiness(shiftId: shiftId, now: now);

        expect(readiness.sentOrderCount, 0);
        expect(readiness.freshDraftCount, 0);
        expect(readiness.staleDraftCount, 1);
        expect(
          readiness.blockingReason,
          ShiftCloseBlockReason.staleDraftsPendingCleanup,
        );
        expect(
          readiness.suggestedAction,
          ShiftCloseSuggestedAction.discardStaleDrafts,
        );

        await expectLater(
          _makeReportService(
            db,
          ).runAdminFinalCloseWithCountedCash(
            user: _admin(adminId),
            countedCashMinor: 0,
            now: now,
          ),
          throwsA(
            isA<ShiftCloseBlockedException>().having(
              (ShiftCloseBlockedException error) =>
                  error.readiness.blockingReason,
              'blockingReason',
              ShiftCloseBlockReason.staleDraftsPendingCleanup,
            ).having(
              (ShiftCloseBlockedException error) => error.suggestedAction,
              'suggestedAction',
              ShiftCloseSuggestedAction.discardStaleDrafts,
            ),
          ),
        );
      },
    );

    test('cashier cannot final close while admin can', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: adminId);

      final ReportService reportService = _makeReportService(db);

      await expectLater(
        reportService.runAdminFinalCloseWithCountedCash(
          user: _cashier(cashierId),
          countedCashMinor: 0,
        ),
        throwsA(isA<UnauthorisedException>()),
      );

      await reportService.runAdminFinalCloseWithCountedCash(
        user: _admin(adminId),
        countedCashMinor: 0,
      );
      expect(await ShiftRepository(db).getOpenShift(), isNull);
    });

    test('discarded drafts stay out of paid and cancelled reporting', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int categoryId = await insertCategory(db, name: 'Meals');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Plate',
        priceMinor: 1000,
      );
      final OrderService orderService = _makeOrderService(db);

      final paidDraft = await orderService.createOrder(
        currentUser: _admin(adminId),
      );
      await orderService.addProductToOrder(
        transactionId: paidDraft.id,
        productId: productId,
      );
      await orderService.sendOrder(
        transactionId: paidDraft.id,
        currentUser: _admin(adminId),
      );
      await orderService.markOrderPaid(
        transactionId: paidDraft.id,
        method: PaymentMethod.cash,
        currentUser: _admin(adminId),
      );

      final discardedDraft = await orderService.createOrder(
        currentUser: _admin(adminId),
      );
      await orderService.addProductToOrder(
        transactionId: discardedDraft.id,
        productId: productId,
      );
      await orderService.discardDraft(
        transactionId: discardedDraft.id,
        currentUser: _admin(adminId),
      );

      final cancelledDraft = await orderService.createOrder(
        currentUser: _admin(adminId),
      );
      await orderService.addProductToOrder(
        transactionId: cancelledDraft.id,
        productId: productId,
      );
      await orderService.sendOrder(
        transactionId: cancelledDraft.id,
        currentUser: _admin(adminId),
      );
      await orderService.cancelOrder(
        transactionId: cancelledDraft.id,
        currentUser: _admin(adminId),
      );

      final report = await _makeReportService(db).getShiftReport(shiftId);

      expect(report.paidCount, 1);
      expect(report.paidTotalMinor, 1000);
      expect(report.cancelledCount, 1);
      expect(report.openCount, 0);
    });

    test(
      'end-to-end close flow requires stale draft cleanup and preserves paid totals',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        await insertShift(db, openedBy: adminId);
        final int categoryId = await insertCategory(db, name: 'Coffee');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Latte',
          priceMinor: 700,
        );
        final OrderService orderService = _makeOrderService(db);
        final User admin = _admin(adminId);

        final TransactionRepository transactionRepository =
            TransactionRepository(db);

        final saleDraft = await orderService.createOrder(currentUser: admin);
        await orderService.addProductToOrder(
          transactionId: saleDraft.id,
          productId: productId,
        );
        await orderService.sendOrder(
          transactionId: saleDraft.id,
          currentUser: admin,
        );
        await orderService.markOrderPaid(
          transactionId: saleDraft.id,
          method: PaymentMethod.card,
          currentUser: admin,
        );

        final abandonedDraft = await orderService.createOrder(
          currentUser: admin,
        );
        await orderService.addProductToOrder(
          transactionId: abandonedDraft.id,
          productId: productId,
        );
        final DateTime closeAttemptAt = DateTime(2026, 1, 1, 18, 0, 0);
        await db.customStatement(
          'UPDATE transactions SET updated_at = ? WHERE id = ?',
          <Object>[
            closeAttemptAt
                    .subtract(
                      DraftOrderPolicy.staleThreshold +
                          const Duration(minutes: 5),
                    )
                    .millisecondsSinceEpoch ~/
                1000,
            abandonedDraft.id,
          ],
        );

        final ReportService reportService = _makeReportService(db);

        await expectLater(
          reportService.runAdminFinalCloseWithCountedCash(
            user: admin,
            countedCashMinor: 0,
            now: closeAttemptAt,
          ),
          throwsA(isA<ShiftCloseBlockedException>()),
        );

        await orderService.discardDraft(
          transactionId: abandonedDraft.id,
          currentUser: admin,
        );

        final result = await reportService.runAdminFinalCloseWithCountedCash(
          user: admin,
          countedCashMinor: 0,
          now: closeAttemptAt,
        );

        expect(result.finalCloseCompleted, isTrue);
        expect(result.report.paidCount, 1);
        expect(result.report.paidTotalMinor, 700);
        expect(result.report.cancelledCount, 0);
        expect(await transactionRepository.getById(abandonedDraft.id), isNull);
        expect(await ShiftRepository(db).getOpenShift(), isNull);
      },
    );
  });
}

OrderService _makeOrderService(AppDatabase db) {
  return OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: TransactionRepository(db),
    transactionStateRepository: TransactionStateRepository(db),
    paymentRepository: PaymentRepository(db),
  );
}

ReportService _makeReportService(AppDatabase db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  return ReportService(
    shiftRepository: shiftRepository,
    shiftSessionService: ShiftSessionService(shiftRepository),
    transactionRepository: TransactionRepository(db),
    paymentRepository: PaymentRepository(db),
    settingsRepository: SettingsRepository(db),
    reportVisibilityService: const ReportVisibilityService(),
  );
}

User _admin(int id) {
  return User(
    id: id,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.now(),
  );
}

User _cashier(int id) {
  return User(
    id: id,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
}
