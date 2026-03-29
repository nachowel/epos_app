import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart'
    hide CashMovement, Payment, Shift, Transaction, User;
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/cash_movement_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/cash_movement.dart';
import 'package:epos_app/domain/services/audit_log_service.dart';
import 'package:epos_app/domain/services/cash_movement_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('CashMovementService', () {
    test('create valid income movement', () async {
      final _CashMovementHarness harness = await _CashMovementHarness.create();
      addTearDown(harness.db.close);

      final CashMovement movement = await harness.service
          .createManualCashMovement(
            type: CashMovementType.income,
            category: 'Float top-up',
            amountMinor: 2500,
            paymentMethod: CashMovementPaymentMethod.cash,
            note: 'Start of shift',
            actorUserId: harness.adminId,
          );

      expect(movement.type, CashMovementType.income);
      expect(movement.category, 'Float top-up');
      expect(movement.amountMinor, 2500);
      expect(movement.paymentMethod, CashMovementPaymentMethod.cash);
      expect(movement.shiftId, harness.shiftId);
      expect(movement.createdByUserId, harness.adminId);
    });

    test('create valid expense movement', () async {
      final _CashMovementHarness harness = await _CashMovementHarness.create();
      addTearDown(harness.db.close);

      final CashMovement movement = await harness.service
          .createManualCashMovement(
            type: CashMovementType.expense,
            category: 'Supplier cash purchase',
            amountMinor: 1800,
            paymentMethod: CashMovementPaymentMethod.other,
            note: null,
            actorUserId: harness.adminId,
          );

      expect(movement.type, CashMovementType.expense);
      expect(movement.paymentMethod, CashMovementPaymentMethod.other);
      expect(movement.note, isNull);
    });

    test('reject amount <= 0', () async {
      final _CashMovementHarness harness = await _CashMovementHarness.create();
      addTearDown(harness.db.close);

      await expectLater(
        harness.service.createManualCashMovement(
          type: CashMovementType.income,
          category: 'Invalid',
          amountMinor: 0,
          paymentMethod: CashMovementPaymentMethod.cash,
          actorUserId: harness.adminId,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Cash movement amount must be greater than zero.',
          ),
        ),
      );
    });

    test('reject empty category', () async {
      final _CashMovementHarness harness = await _CashMovementHarness.create();
      addTearDown(harness.db.close);

      await expectLater(
        harness.service.createManualCashMovement(
          type: CashMovementType.expense,
          category: '   ',
          amountMinor: 100,
          paymentMethod: CashMovementPaymentMethod.card,
          actorUserId: harness.adminId,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Cash movement category is required.',
          ),
        ),
      );
    });

    test('reject when no active shift exists', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final CashMovementService service = CashMovementService(
        cashMovementRepository: CashMovementRepository(db),
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
      );

      await expectLater(
        service.createManualCashMovement(
          type: CashMovementType.income,
          category: 'No shift',
          amountMinor: 500,
          paymentMethod: CashMovementPaymentMethod.cash,
          actorUserId: adminId,
        ),
        throwsA(isA<ShiftNotActiveException>()),
      );
    });

    test('movement is linked to active shift', () async {
      final _CashMovementHarness harness = await _CashMovementHarness.create();
      addTearDown(harness.db.close);

      await harness.service.createManualCashMovement(
        type: CashMovementType.expense,
        category: 'Petty cash',
        amountMinor: 450,
        paymentMethod: CashMovementPaymentMethod.cash,
        actorUserId: harness.adminId,
      );

      final List<CashMovement> movements = await harness.repository
          .listCashMovementsForShift(harness.shiftId);

      expect(movements, hasLength(1));
      expect(movements.single.shiftId, harness.shiftId);
    });

    test('cash_movement_created audit log is written', () async {
      final _CashMovementHarness harness = await _CashMovementHarness.create();
      addTearDown(harness.db.close);

      final CashMovement movement = await harness.service.createManualCashMovement(
        type: CashMovementType.expense,
        category: 'Bank drop',
        amountMinor: 500,
        paymentMethod: CashMovementPaymentMethod.cash,
        actorUserId: harness.adminId,
      );

      final logs = await harness.auditLogRepository.listAuditLogsByEntity(
        entityType: 'cash_movement',
        entityId: '${movement.id}',
      );

      expect(logs, hasLength(1));
      expect(logs.single.action, 'cash_movement_created');
      expect(logs.single.actorUserId, harness.adminId);
      expect(logs.single.metadata['shift_id'], harness.shiftId);
      expect(logs.single.metadata['category'], 'Bank drop');
      expect(logs.single.metadata['amount_minor'], 500);
    });

    test(
      'sales and payment flows remain unaffected by cash movements',
      () async {
        final _CashMovementHarness harness =
            await _CashMovementHarness.create();
        addTearDown(harness.db.close);

        final int paidTransactionId = await insertTransaction(
          harness.db,
          uuid: 'cash-movement-boundary',
          shiftId: harness.shiftId,
          userId: harness.adminId,
          status: 'paid',
          totalAmountMinor: 1200,
          paidAt: DateTime.now(),
        );
        await insertPayment(
          harness.db,
          uuid: 'cash-movement-payment',
          transactionId: paidTransactionId,
          method: 'cash',
          amountMinor: 1200,
        );

        final before = await harness.reportService.getShiftReport(
          harness.shiftId,
        );
        expect(before.paidTotalMinor, 1200);
        expect(before.cashTotalMinor, 1200);
        expect(before.cardTotalMinor, 0);
        expect(before.netSalesMinor, 1200);

        await harness.service.createManualCashMovement(
          type: CashMovementType.expense,
          category: 'Bank drop',
          amountMinor: 500,
          paymentMethod: CashMovementPaymentMethod.cash,
          actorUserId: harness.adminId,
        );

        final after = await harness.reportService.getShiftReport(
          harness.shiftId,
        );

        expect(after.paidTotalMinor, 1200);
        expect(after.cashTotalMinor, 1200);
        expect(after.cardTotalMinor, 0);
        expect(after.netSalesMinor, 1200);
        expect(after.paidTotalMinor, before.paidTotalMinor);
        expect(after.cashTotalMinor, before.cashTotalMinor);
        expect(after.cardTotalMinor, before.cardTotalMinor);
        expect(after.netSalesMinor, before.netSalesMinor);
      },
    );
  });
}

class _CashMovementHarness {
  _CashMovementHarness({
    required this.db,
    required this.adminId,
    required this.shiftId,
    required this.repository,
    required this.service,
    required this.reportService,
    required this.auditLogRepository,
  });

  final AppDatabase db;
  final int adminId;
  final int shiftId;
  final CashMovementRepository repository;
  final CashMovementService service;
  final ReportService reportService;
  final AuditLogRepository auditLogRepository;

  static Future<_CashMovementHarness> create() async {
    final AppDatabase db = createTestDatabase();
    final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
    final int shiftId = await insertShift(db, openedBy: adminId);

    final ShiftRepository shiftRepository = ShiftRepository(db);
    final ShiftSessionService shiftSessionService = ShiftSessionService(
      shiftRepository,
    );
    final CashMovementRepository repository = CashMovementRepository(db);
    final AuditLogRepository auditLogRepository = AuditLogRepository(db);
    final AuditLogService auditLogService = PersistedAuditLogService(
      auditLogRepository: auditLogRepository,
      logger: const NoopAppLogger(),
    );

    return _CashMovementHarness(
      db: db,
      adminId: adminId,
      shiftId: shiftId,
      repository: repository,
      service: CashMovementService(
        cashMovementRepository: repository,
        shiftSessionService: shiftSessionService,
        auditLogService: auditLogService,
      ),
      reportService: ReportService(
        shiftRepository: shiftRepository,
        shiftSessionService: shiftSessionService,
        transactionRepository: TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        settingsRepository: SettingsRepository(db),
        reportVisibilityService: const ReportVisibilityService(),
      ),
      auditLogRepository: auditLogRepository,
    );
  }
}
