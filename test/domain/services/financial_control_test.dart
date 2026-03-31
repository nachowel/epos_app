import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart'
    hide Payment, PaymentAdjustment, ShiftReconciliation, User;
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/payment_adjustment_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_reconciliation_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/authorization_policy.dart';
import 'package:epos_app/domain/models/audit_log_record.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/payment_adjustment.dart';
import 'package:epos_app/domain/models/shift_reconciliation.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/audit_log_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/payment_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Financial control phase 6', () {
    test(
      'refund keeps original payment immutable, writes separate adjustment, and blocks duplicates',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Food');
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Lunch',
          priceMinor: 1250,
        );
        final int transactionId = await insertTransaction(
          harness.db,
          uuid: 'refund-integrity',
          shiftId: harness.shiftId,
          userId: harness.admin.id,
          status: 'draft',
          totalAmountMinor: 1250,
        );
        await harness.transactionRepository.addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 1,
        );
        await harness.orderService.sendOrder(
          transactionId: transactionId,
          currentUser: harness.admin,
        );
        final Payment payment = await harness.paymentService.payOrder(
          transactionId: transactionId,
          method: PaymentMethod.cash,
          currentUser: harness.admin,
        );

        final PaymentAdjustment adjustment = await harness.paymentService
            .refundOrder(
              transactionId: transactionId,
              reason: 'Customer changed mind',
              currentUser: harness.admin,
            );

        final Payment? persistedPayment = await harness.paymentRepository
            .getByTransactionId(transactionId);
        final PaymentAdjustment? persistedAdjustment = await harness
            .paymentAdjustmentRepository
            .getByPaymentId(payment.id);

        expect(persistedPayment, isNotNull);
        expect(persistedPayment!.uuid, payment.uuid);
        expect(persistedPayment.amountMinor, 1250);
        expect(persistedAdjustment, isNotNull);
        expect(persistedAdjustment!.uuid, adjustment.uuid);
        expect(persistedAdjustment.amountMinor, 1250);
        expect(persistedAdjustment.reason, 'Customer changed mind');

        await expectLater(
          harness.paymentService.refundOrder(
            transactionId: transactionId,
            reason: 'Duplicate attempt',
            currentUser: harness.admin,
          ),
          throwsA(isA<PaymentRefundBlockedException>()),
        );

        final int unpaidTransactionId = await insertTransaction(
          harness.db,
          uuid: 'refund-unpaid',
          shiftId: harness.shiftId,
          userId: harness.admin.id,
          status: 'sent',
          totalAmountMinor: 500,
        );
        await expectLater(
          harness.paymentService.refundOrder(
            transactionId: unpaidTransactionId,
            reason: 'Should fail',
            currentUser: harness.admin,
          ),
          throwsA(isA<PaymentRefundBlockedException>()),
        );
      },
    );

    test(
      'reporting uses gross minus refunds and keeps cash and card totals correct',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Drinks');
        final int coffeeId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Coffee',
          priceMinor: 700,
        );
        final int cakeId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Cake',
          priceMinor: 900,
        );

        final int cashTxId = await _createPaidOrder(
          harness,
          transactionUuid: 'report-cash',
          productId: coffeeId,
          amountMinor: 700,
          method: PaymentMethod.cash,
        );
        await _createPaidOrder(
          harness,
          transactionUuid: 'report-card',
          productId: cakeId,
          amountMinor: 900,
          method: PaymentMethod.card,
        );
        await insertTransaction(
          harness.db,
          uuid: 'report-cancelled',
          shiftId: harness.shiftId,
          userId: harness.admin.id,
          status: 'cancelled',
          totalAmountMinor: 400,
          cancelledAt: DateTime.now(),
          cancelledBy: harness.admin.id,
        );

        await harness.paymentService.refundOrder(
          transactionId: cashTxId,
          reason: 'Customer returned cash order',
          currentUser: harness.admin,
        );

        final report = await harness.reportService.getShiftReport(
          harness.shiftId,
        );

        expect(report.paidTotalMinor, 1600);
        expect(report.refundTotalMinor, 700);
        expect(report.netSalesMinor, 900);
        expect(report.cashTotalMinor, 0);
        expect(report.cardTotalMinor, 900);
        expect(report.cancelledCount, 1);
        expect(report.refundCount, 1);
        expect(report.refundedOrderCount, 1);
      },
    );

    test(
      'rapid duplicate refund attempts create one adjustment and keep payment immutable',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Race');
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Race Item',
          priceMinor: 950,
        );
        final int transactionId = await _createPaidOrder(
          harness,
          transactionUuid: 'refund-race',
          productId: productId,
          amountMinor: 950,
          method: PaymentMethod.cash,
        );
        final Payment originalPayment = (await harness.paymentRepository
            .getByTransactionId(transactionId))!;

        final List<Object?> results =
            await Future.wait<Object?>(<Future<Object?>>[
              () async {
                try {
                  return await harness.paymentService.refundOrder(
                    transactionId: transactionId,
                    reason: 'Race refund A',
                    currentUser: harness.admin,
                  );
                } catch (error) {
                  return error;
                }
              }(),
              () async {
                try {
                  return await harness.paymentService.refundOrder(
                    transactionId: transactionId,
                    reason: 'Race refund B',
                    currentUser: harness.admin,
                  );
                } catch (error) {
                  return error;
                }
              }(),
            ]);
        final Payment persistedPayment = (await harness.paymentRepository
            .getByTransactionId(transactionId))!;
        final List<PaymentAdjustment> adjustments = await harness
            .paymentAdjustmentRepository
            .getByShift(harness.shiftId);

        expect(results.whereType<PaymentAdjustment>().length, 1);
        expect(
          results.where(
            (Object? result) =>
                result is DuplicatePaymentAdjustmentException ||
                result is PaymentRefundBlockedException,
          ),
          hasLength(1),
        );
        expect(
          adjustments.where((entry) => entry.transactionId == transactionId),
          hasLength(1),
        );
        expect(persistedPayment.uuid, originalPayment.uuid);
        expect(persistedPayment.amountMinor, originalPayment.amountMinor);
      },
    );

    test(
      'stale payment retry after refund is blocked and report truth stays intact',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(
          harness.db,
          name: 'Stale Retry',
        );
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Retry Item',
          priceMinor: 650,
        );
        final int transactionId = await _createPaidOrder(
          harness,
          transactionUuid: 'stale-pay-retry',
          productId: productId,
          amountMinor: 650,
          method: PaymentMethod.card,
        );

        await harness.paymentService.refundOrder(
          transactionId: transactionId,
          reason: 'Refund before stale pay retry',
          currentUser: harness.admin,
        );

        await expectLater(
          harness.paymentService.payOrder(
            transactionId: transactionId,
            method: PaymentMethod.card,
            currentUser: harness.admin,
          ),
          throwsA(isA<OrderPaymentBlockedException>()),
        );

        final report = await harness.reportService.getShiftReport(
          harness.shiftId,
        );
        expect(report.paidTotalMinor, 650);
        expect(report.refundTotalMinor, 650);
        expect(report.netSalesMinor, 0);
        expect(report.cardTotalMinor, 0);
      },
    );

    test(
      'final close persists reconciliation without altering transactional truth',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Meals');
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Combo',
          priceMinor: 1100,
        );
        final int transactionId = await _createPaidOrder(
          harness,
          transactionUuid: 'reconciliation-cash',
          productId: productId,
          amountMinor: 1100,
          method: PaymentMethod.cash,
        );

        final result = await harness.reportService
            .runAdminFinalCloseWithCountedCash(
              user: harness.admin,
              countedCashMinor: 1000,
            );
        final ShiftReconciliation? reconciliation = await harness
            .shiftReconciliationRepository
            .getByShiftAndKind(
              shiftId: harness.shiftId,
              kind: ShiftReconciliationKind.finalClose,
            );
        final Payment? payment = await harness.paymentRepository
            .getByTransactionId(transactionId);

        expect(result.finalCloseCompleted, isTrue);
        expect(reconciliation, isNotNull);
        expect(reconciliation!.expectedCashMinor, 1100);
        expect(reconciliation.countedCashMinor, 1000);
        expect(reconciliation.varianceMinor, -100);
        expect(reconciliation.countedCashSource, CountedCashSource.entered);
        expect(payment, isNotNull);
        expect(payment!.amountMinor, 1100);
      },
    );

    test(
      'cash refund final close keeps gross cash refund net cash and variance aligned',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Cash');
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Cash Meal',
          priceMinor: 1500,
        );
        final int transactionId = await _createPaidOrder(
          harness,
          transactionUuid: 'cash-refund-close',
          productId: productId,
          amountMinor: 1500,
          method: PaymentMethod.cash,
        );

        await harness.paymentService.refundOrder(
          transactionId: transactionId,
          reason: 'Cash refund before close',
          currentUser: harness.admin,
        );

        final reportBeforeClose = await harness.reportService.getShiftReport(
          harness.shiftId,
        );
        await harness.reportService.runAdminFinalCloseWithCountedCash(
          user: harness.admin,
          countedCashMinor: 200,
        );
        final ShiftReconciliation reconciliation = (await harness
            .shiftReconciliationRepository
            .getByShiftAndKind(
              shiftId: harness.shiftId,
              kind: ShiftReconciliationKind.finalClose,
            ))!;

        expect(reportBeforeClose.cashGrossTotalMinor, 1500);
        expect(reportBeforeClose.refundTotalMinor, 1500);
        expect(reportBeforeClose.cashTotalMinor, 0);
        expect(reconciliation.expectedCashMinor, 0);
        expect(reconciliation.countedCashMinor, 200);
        expect(reconciliation.varianceMinor, 200);
      },
    );

    test(
      'card refund final close keeps counted cash independent from card refund',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Card');
        final int cashProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Cash Side',
          priceMinor: 600,
        );
        final int cardProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Card Main',
          priceMinor: 1400,
        );

        await _createPaidOrder(
          harness,
          transactionUuid: 'card-refund-cash-order',
          productId: cashProductId,
          amountMinor: 600,
          method: PaymentMethod.cash,
        );
        final int cardTransactionId = await _createPaidOrder(
          harness,
          transactionUuid: 'card-refund-card-order',
          productId: cardProductId,
          amountMinor: 1400,
          method: PaymentMethod.card,
        );

        await harness.paymentService.refundOrder(
          transactionId: cardTransactionId,
          reason: 'Card refund before close',
          currentUser: harness.admin,
        );

        final reportBeforeClose = await harness.reportService.getShiftReport(
          harness.shiftId,
        );
        await harness.reportService.runAdminFinalCloseWithCountedCash(
          user: harness.admin,
          countedCashMinor: 550,
        );
        final ShiftReconciliation reconciliation = (await harness
            .shiftReconciliationRepository
            .getByShiftAndKind(
              shiftId: harness.shiftId,
              kind: ShiftReconciliationKind.finalClose,
            ))!;

        expect(reportBeforeClose.cardGrossTotalMinor, 1400);
        expect(reportBeforeClose.refundTotalMinor, 1400);
        expect(reportBeforeClose.cardTotalMinor, 0);
        expect(reportBeforeClose.cashTotalMinor, 600);
        expect(reconciliation.expectedCashMinor, 600);
        expect(reconciliation.countedCashMinor, 550);
        expect(reconciliation.varianceMinor, -50);
      },
    );

    test(
      'audit log records critical actions with actor and target metadata',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Audit');
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Audit Meal',
          priceMinor: 1000,
        );
        final int transactionId = await _createPaidOrder(
          harness,
          transactionUuid: 'audit-flow',
          productId: productId,
          amountMinor: 1000,
          method: PaymentMethod.cash,
        );
        await harness.paymentService.refundOrder(
          transactionId: transactionId,
          reason: 'Audit refund',
          currentUser: harness.admin,
        );

        final int staleDraftId = await insertTransaction(
          harness.db,
          uuid: 'audit-stale-draft',
          shiftId: harness.shiftId,
          userId: harness.admin.id,
          status: 'draft',
          totalAmountMinor: 300,
          updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        );
        await harness.orderService.discardDraft(
          transactionId: staleDraftId,
          currentUser: harness.admin,
        );

        await harness.reportService.takeCashierEndOfDayPreview(
          user: harness.cashier,
        );
        await harness.reportService.runAdminFinalCloseWithCountedCash(
          user: harness.admin,
          countedCashMinor: 0,
        );

        final entries = await harness.auditLogRepository.listRecent(limit: 50);
        final actions = entries.map((entry) => entry.actionType).toList();

        expect(
          actions,
          containsAll(<String>[
            'shift_opened',
            'day_end_preview_run',
            'shift_closed',
            'day_end_finalized',
          ]),
        );
        final AuditLogRecord finalizationEntry = entries.firstWhere(
          (AuditLogRecord entry) => entry.action == 'day_end_finalized',
        );
        expect(finalizationEntry.actorUserId, harness.admin.id);
        expect(finalizationEntry.entityType, 'shift');
        expect(finalizationEntry.entityId, '${harness.shiftId}');
        expect(
          finalizationEntry.metadata['counted_cash_source'],
          CountedCashSource.entered.name,
        );
      },
    );

    test(
      'authorization blocks cashier refund final close and audit access while admin is allowed',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Auth');
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Auth Item',
          priceMinor: 500,
        );
        final int transactionId = await _createPaidOrder(
          harness,
          transactionUuid: 'auth-flow',
          productId: productId,
          amountMinor: 500,
          method: PaymentMethod.card,
        );

        await expectLater(
          harness.paymentService.refundOrder(
            transactionId: transactionId,
            reason: 'Cashier blocked',
            currentUser: harness.cashier,
          ),
          throwsA(isA<UnauthorisedException>()),
        );
        await expectLater(
          harness.reportService.runAdminFinalCloseWithCountedCash(
            user: harness.cashier,
            countedCashMinor: 0,
          ),
          throwsA(isA<UnauthorisedException>()),
        );

        expect(
          AuthorizationPolicy.canPerform(
            harness.cashier,
            OperatorPermission.viewAuditLog,
          ),
          isFalse,
        );
        expect(
          AuthorizationPolicy.canPerform(
            harness.admin,
            OperatorPermission.refundPayment,
          ),
          isTrue,
        );
      },
    );

    test(
      'end to end finance flow keeps gross refund net cash and card truth aligned',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Flow');
        final int cashProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Cash Product',
          priceMinor: 800,
        );
        final int cardProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Card Product',
          priceMinor: 1200,
        );

        final int cashTxId = await _createPaidOrder(
          harness,
          transactionUuid: 'e2e-cash',
          productId: cashProductId,
          amountMinor: 800,
          method: PaymentMethod.cash,
          actor: harness.cashier,
        );
        await _createPaidOrder(
          harness,
          transactionUuid: 'e2e-card',
          productId: cardProductId,
          amountMinor: 1200,
          method: PaymentMethod.card,
          actor: harness.cashier,
        );
        await harness.paymentService.refundOrder(
          transactionId: cashTxId,
          reason: 'Customer returned item',
          currentUser: harness.admin,
        );
        await harness.reportService.takeCashierEndOfDayPreview(
          user: harness.cashier,
        );
        final result = await harness.reportService
            .runAdminFinalCloseWithCountedCash(
              user: harness.admin,
              countedCashMinor: 0,
            );
        final reconciliation = await harness.shiftReconciliationRepository
            .getByShiftAndKind(
              shiftId: harness.shiftId,
              kind: ShiftReconciliationKind.finalClose,
            );
        final entries = await harness.auditLogRepository.listRecent(limit: 50);

        expect(result.report.paidTotalMinor, 2000);
        expect(result.report.refundTotalMinor, 800);
        expect(result.report.netSalesMinor, 1200);
        expect(result.report.cashTotalMinor, 0);
        expect(result.report.cardTotalMinor, 1200);
        expect(reconciliation, isNotNull);
        expect(reconciliation!.expectedCashMinor, 0);
        expect(reconciliation.countedCashMinor, 0);
        expect(reconciliation.varianceMinor, 0);
        expect(
          entries.map((entry) => entry.actionType),
          containsAll(<String>[
            'shift_opened',
            'day_end_preview_run',
            'shift_closed',
            'day_end_finalized',
          ]),
        );
      },
    );

    test(
      'mixed day report keeps gross refund net cash card cancelled and refunded counts aligned',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(harness.db, name: 'Mixed');
        final int cashProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Cash Product',
          priceMinor: 700,
        );
        final int keptCardProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Kept Card Product',
          priceMinor: 900,
        );
        final int refundedCardProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Refunded Card Product',
          priceMinor: 400,
        );
        final int cancelledProductId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Cancelled Product',
          priceMinor: 300,
        );

        await _createPaidOrder(
          harness,
          transactionUuid: 'mixed-cash-paid',
          productId: cashProductId,
          amountMinor: 700,
          method: PaymentMethod.cash,
        );
        await _createPaidOrder(
          harness,
          transactionUuid: 'mixed-card-kept',
          productId: keptCardProductId,
          amountMinor: 900,
          method: PaymentMethod.card,
        );
        final int refundedCardTxId = await _createPaidOrder(
          harness,
          transactionUuid: 'mixed-card-refunded',
          productId: refundedCardProductId,
          amountMinor: 400,
          method: PaymentMethod.card,
        );
        final int cancelledTxId = await insertTransaction(
          harness.db,
          uuid: 'mixed-cancel-target',
          shiftId: harness.shiftId,
          userId: harness.admin.id,
          status: 'draft',
          totalAmountMinor: 300,
        );
        await harness.transactionRepository.addLine(
          transactionId: cancelledTxId,
          productId: cancelledProductId,
          quantity: 1,
        );
        await harness.orderService.sendOrder(
          transactionId: cancelledTxId,
          currentUser: harness.admin,
        );

        await harness.paymentService.refundOrder(
          transactionId: refundedCardTxId,
          reason: 'Mixed day refund',
          currentUser: harness.admin,
        );
        await harness.orderService.cancelOrder(
          transactionId: cancelledTxId,
          currentUser: harness.admin,
        );

        final report = await harness.reportService.getShiftReport(
          harness.shiftId,
        );

        expect(report.paidTotalMinor, 2000);
        expect(report.refundTotalMinor, 400);
        expect(report.netSalesMinor, 1600);
        expect(report.cashGrossTotalMinor, 700);
        expect(report.cashTotalMinor, 700);
        expect(report.cardGrossTotalMinor, 1300);
        expect(report.cardTotalMinor, 900);
        expect(report.cancelledCount, 1);
        expect(report.refundCount, 1);
        expect(report.refundedOrderCount, 1);
      },
    );

    test(
      'compatibility final close path is isolated and recorded as fallback',
      () async {
        final _FinanceHarness harness = await _FinanceHarness.create();
        addTearDown(harness.db.close);

        final int categoryId = await insertCategory(
          harness.db,
          name: 'Compatibility',
        );
        final int productId = await insertProduct(
          harness.db,
          categoryId: categoryId,
          name: 'Compatibility Cash',
          priceMinor: 500,
        );
        await _createPaidOrder(
          harness,
          transactionUuid: 'compatibility-close',
          productId: productId,
          amountMinor: 500,
          method: PaymentMethod.cash,
        );

        // ignore: deprecated_member_use_from_same_package
        await harness.reportService.runAdminFinalCloseCompatibilityFallback(
          user: harness.admin,
        );
        final ShiftReconciliation reconciliation = (await harness
            .shiftReconciliationRepository
            .getByShiftAndKind(
              shiftId: harness.shiftId,
              kind: ShiftReconciliationKind.finalClose,
            ))!;
        final AuditLogRecord finalizationEntry =
            (await harness.auditLogRepository.listRecent(limit: 20)).firstWhere(
              (AuditLogRecord entry) => entry.action == 'day_end_finalized',
            );

        expect(
          reconciliation.countedCashSource,
          CountedCashSource.compatibilityFallback,
        );
        expect(reconciliation.wasOperatorEntered, isFalse);
        expect(
          finalizationEntry.metadata['counted_cash_source'],
          CountedCashSource.compatibilityFallback.name,
        );
      },
    );
  });
}

class _FinanceHarness {
  _FinanceHarness({
    required this.db,
    required this.admin,
    required this.cashier,
    required this.shiftId,
    required this.transactionRepository,
    required this.paymentRepository,
    required this.paymentAdjustmentRepository,
    required this.shiftReconciliationRepository,
    required this.auditLogRepository,
    required this.shiftSessionService,
    required this.orderService,
    required this.paymentService,
    required this.reportService,
  });

  final AppDatabase db;
  final User admin;
  final User cashier;
  final int shiftId;
  final TransactionRepository transactionRepository;
  final PaymentRepository paymentRepository;
  final PaymentAdjustmentRepository paymentAdjustmentRepository;
  final ShiftReconciliationRepository shiftReconciliationRepository;
  final AuditLogRepository auditLogRepository;
  final ShiftSessionService shiftSessionService;
  final OrderService orderService;
  final PaymentService paymentService;
  final ReportService reportService;

  static Future<_FinanceHarness> create() async {
    final AppDatabase db = createTestDatabase();
    final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
    final int cashierId = await insertUser(
      db,
      name: 'Cashier',
      role: 'cashier',
    );
    final AuditLogRepository auditLogRepository = AuditLogRepository(db);
    final AuditLogService auditLogService = PersistedAuditLogService(
      auditLogRepository: auditLogRepository,
      logger: const NoopAppLogger(),
    );
    final ShiftRepository shiftRepository = ShiftRepository(db);
    final ShiftSessionService shiftSessionService = ShiftSessionService(
      shiftRepository,
      auditLogService: auditLogService,
    );

    final User admin = _user(adminId, UserRole.admin, 'Admin');
    final User cashier = _user(cashierId, UserRole.cashier, 'Cashier');
    final shift = await shiftSessionService.openShiftManually(admin);
    final TransactionRepository transactionRepository = TransactionRepository(
      db,
    );
    final PaymentRepository paymentRepository = PaymentRepository(db);
    final PaymentAdjustmentRepository paymentAdjustmentRepository =
        PaymentAdjustmentRepository(db);
    final ShiftReconciliationRepository shiftReconciliationRepository =
        ShiftReconciliationRepository(db);
    final OrderService orderService = OrderService(
      shiftSessionService: shiftSessionService,
      transactionRepository: transactionRepository,
      transactionStateRepository: TransactionStateRepository(db),
      paymentRepository: paymentRepository,
      auditLogService: auditLogService,
    );
    final PrinterService printerService = PrinterService(
      transactionRepository,
      paymentRepository: paymentRepository,
      auditLogService: auditLogService,
    );
    final PaymentService paymentService = PaymentService(
      orderService: orderService,
      paymentRepository: paymentRepository,
      paymentAdjustmentRepository: paymentAdjustmentRepository,
      transactionRepository: transactionRepository,
      auditLogService: auditLogService,
      printerService: printerService,
    );
    final ReportService reportService = ReportService(
      shiftRepository: shiftRepository,
      shiftSessionService: shiftSessionService,
      transactionRepository: transactionRepository,
      paymentRepository: paymentRepository,
      paymentAdjustmentRepository: paymentAdjustmentRepository,
      shiftReconciliationRepository: shiftReconciliationRepository,
      settingsRepository: SettingsRepository(db),
      reportVisibilityService: const ReportVisibilityService(),
      auditLogService: auditLogService,
    );

    return _FinanceHarness(
      db: db,
      admin: admin,
      cashier: cashier,
      shiftId: shift.id,
      transactionRepository: transactionRepository,
      paymentRepository: paymentRepository,
      paymentAdjustmentRepository: paymentAdjustmentRepository,
      shiftReconciliationRepository: shiftReconciliationRepository,
      auditLogRepository: auditLogRepository,
      shiftSessionService: shiftSessionService,
      orderService: orderService,
      paymentService: paymentService,
      reportService: reportService,
    );
  }
}

Future<int> _createPaidOrder(
  _FinanceHarness harness, {
  required String transactionUuid,
  required int productId,
  required int amountMinor,
  required PaymentMethod method,
  User? actor,
}) async {
  final User effectiveActor = actor ?? harness.admin;
  final int transactionId = await insertTransaction(
    harness.db,
    uuid: transactionUuid,
    shiftId: harness.shiftId,
    userId: effectiveActor.id,
    status: 'draft',
    totalAmountMinor: amountMinor,
  );
  await harness.transactionRepository.addLine(
    transactionId: transactionId,
    productId: productId,
    quantity: 1,
  );
  await harness.orderService.sendOrder(
    transactionId: transactionId,
    currentUser: effectiveActor,
  );
  await harness.paymentService.payOrder(
    transactionId: transactionId,
    method: method,
    currentUser: effectiveActor,
  );
  return transactionId;
}

User _user(int id, UserRole role, String name) => User(
  id: id,
  name: name,
  pin: null,
  password: null,
  role: role,
  isActive: true,
  createdAt: DateTime.now(),
);
