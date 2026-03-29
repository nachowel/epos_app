import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/payment_adjustment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/shift_reconciliation_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/payment_adjustment.dart';
import '../models/payment.dart';
import '../models/authorization_policy.dart';
import '../models/business_identity_settings.dart';
import '../models/cashier_z_report_settings.dart';
import '../models/report_settings_policy.dart';
import '../models/shift_cash_summary.dart';
import '../models/shift.dart';
import '../models/shift_report.dart';
import '../models/shift_reconciliation.dart';
import '../models/stale_final_close_recovery_details.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/z_report_action_result.dart';
import 'audit_log_service.dart';
import 'report_visibility_service.dart';
import 'shift_session_service.dart';

class ReportService {
  ReportService({
    required ShiftRepository shiftRepository,
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    required PaymentRepository paymentRepository,
    PaymentAdjustmentRepository? paymentAdjustmentRepository,
    ShiftReconciliationRepository? shiftReconciliationRepository,
    required SettingsRepository settingsRepository,
    required ReportVisibilityService reportVisibilityService,
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _shiftRepository = shiftRepository,
       _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _paymentRepository = paymentRepository,
       _paymentAdjustmentRepository = paymentAdjustmentRepository,
       _shiftReconciliationRepository = shiftReconciliationRepository,
       _settingsRepository = settingsRepository,
       _reportVisibilityService = reportVisibilityService,
       _auditLogService = auditLogService,
       _logger = logger;

  final ShiftRepository _shiftRepository;
  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final PaymentRepository _paymentRepository;
  final PaymentAdjustmentRepository? _paymentAdjustmentRepository;
  final ShiftReconciliationRepository? _shiftReconciliationRepository;
  final SettingsRepository _settingsRepository;
  final ReportVisibilityService _reportVisibilityService;
  final AuditLogService _auditLogService;
  final AppLogger _logger;

  Future<List<Transaction>> getPaidTransactionsForOpenShift() async {
    final openShift = await _shiftSessionService.getBackendOpenShift();
    if (openShift == null) {
      return const <Transaction>[];
    }

    return _transactionRepository.getByShiftAndStatus(
      openShift.id,
      TransactionStatus.paid,
    );
  }

  Future<ShiftReport> getShiftReport(int shiftId) async {
    final List<Transaction> paidTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.paid);
    final List<Transaction> draftTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.draft);
    final List<Transaction> sentTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.sent);
    final List<Transaction> cancelledTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.cancelled);
    final List<Payment> payments = await _paymentRepository.getByShift(shiftId);
    final List<PaymentAdjustment> adjustments =
        await _paymentAdjustmentRepository?.getByShift(shiftId) ??
        const <PaymentAdjustment>[];
    final List<Transaction> activeTransactions = <Transaction>[
      ...draftTransactions,
      ...sentTransactions,
    ];

    int cashCount = 0;
    int cashGrossTotalMinor = 0;
    int cashTotalMinor = 0;
    int cardCount = 0;
    int cardGrossTotalMinor = 0;
    int cardTotalMinor = 0;

    for (final Payment payment in payments) {
      if (payment.method == PaymentMethod.cash) {
        cashCount += 1;
        cashGrossTotalMinor += payment.amountMinor;
        cashTotalMinor += payment.amountMinor;
      } else {
        cardCount += 1;
        cardGrossTotalMinor += payment.amountMinor;
        cardTotalMinor += payment.amountMinor;
      }
    }

    final Map<int, Payment> paymentById = <int, Payment>{
      for (final Payment payment in payments) payment.id: payment,
    };
    int refundTotalMinor = 0;
    int refundedOrderCount = 0;
    for (final PaymentAdjustment adjustment in adjustments) {
      final Payment? payment = paymentById[adjustment.paymentId];
      if (payment == null || !adjustment.isCompleted) {
        continue;
      }
      refundTotalMinor += adjustment.amountMinor;
      refundedOrderCount += 1;
      if (payment.method == PaymentMethod.cash) {
        cashTotalMinor -= adjustment.amountMinor;
      } else {
        cardTotalMinor -= adjustment.amountMinor;
      }
    }

    final int grossSalesMinor = cashGrossTotalMinor + cardGrossTotalMinor;
    final int netSalesMinor = grossSalesMinor - refundTotalMinor;
    final categoryBreakdown = await _transactionRepository
        .getPaidCategoryTotalsForShift(shiftId);

    return ShiftReport(
      shiftId: shiftId,
      paidCount: paidTransactions.length,
      paidTotalMinor: grossSalesMinor,
      refundCount: adjustments.length,
      refundTotalMinor: refundTotalMinor,
      netSalesMinor: netSalesMinor,
      openCount: activeTransactions.length,
      openTotalMinor: _sumTransactionTotals(activeTransactions),
      cancelledCount: cancelledTransactions.length,
      refundedOrderCount: refundedOrderCount,
      cashCount: cashCount,
      cashGrossTotalMinor: cashGrossTotalMinor,
      cashTotalMinor: cashTotalMinor,
      cardCount: cardCount,
      cardGrossTotalMinor: cardGrossTotalMinor,
      cardTotalMinor: cardTotalMinor,
      categoryBreakdown: categoryBreakdown,
    );
  }

  Future<ShiftReport> getVisibleShiftReport({
    required int shiftId,
    required User user,
  }) async {
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.viewMaskedReports,
    );
    final ShiftReport rawReport = await getShiftReport(shiftId);
    final double ratio = await getVisibilityRatio();
    return _reportVisibilityService.applyVisibilityToReport(
      rawReport,
      user,
      ratio,
    );
  }

  Future<int> getTodaySalesTotalMinor({
    required User user,
    DateTime? now,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.viewFullReports);

    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime startOfDay = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Transaction> paidTransactions = await _transactionRepository
        .getPaidTransactionsBetween(
          startInclusive: startOfDay,
          endExclusive: endOfDay,
        );

    return _sumTransactionTotals(paidTransactions);
  }

  Future<ZReportActionResult> takeCashierEndOfDayPreview({
    required User user,
  }) async {
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.lockShiftForPreviewClose,
    );

    final openShift = await _shiftSessionService.requireBackendOpenShift();
    final ShiftReport visibleReport = await getVisibleShiftReport(
      shiftId: openShift.id,
      user: user,
    );
    await _shiftSessionService.lockShiftForCashier(user);
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'day_end_preview_run',
      entityType: 'shift',
      entityId: '${openShift.id}',
      metadata: <String, Object?>{'shift_id': openShift.id},
    );
    _logger.audit(
      eventType: 'cashier_end_of_day_preview',
      entityId: '${openShift.id}',
      message: 'Cashier masked end-of-day preview recorded.',
      metadata: <String, Object?>{'user_id': user.id},
    );

    return ZReportActionResult(
      shiftId: openShift.id,
      report: visibleReport,
      finalCloseCompleted: false,
      cashierPreviewRecorded: true,
    );
  }

  Future<ZReportActionResult> runAdminFinalCloseWithCountedCash({
    required User user,
    required int countedCashMinor,
    DateTime? now,
  }) {
    return _runAdminFinalCloseInternal(
      user: user,
      countedCashMinor: countedCashMinor,
      countedCashSource: CountedCashSource.entered,
      now: now,
    );
  }

  /// Compatibility-only fallback for legacy/internal callers.
  ///
  /// Do not use this from active operator flows. It infers counted cash from
  /// expected cash and records the reconciliation as a compatibility fallback.
  @Deprecated(
    'Compatibility fallback only. Active operator flows must call '
    'runAdminFinalCloseWithCountedCash.',
  )
  Future<ZReportActionResult> runAdminFinalCloseCompatibilityFallback({
    required User user,
    DateTime? now,
  }) async {
    final Shift openShift = await _shiftSessionService
        .requireBackendOpenShift();
    final ShiftReport rawReport = await getShiftReport(openShift.id);
    return _runAdminFinalCloseInternal(
      user: user,
      countedCashMinor: rawReport.cashTotalMinor,
      countedCashSource: CountedCashSource.compatibilityFallback,
      now: now,
      openShift: openShift,
      rawReport: rawReport,
    );
  }

  Future<ZReportActionResult> _runAdminFinalCloseInternal({
    required User user,
    required int countedCashMinor,
    required CountedCashSource countedCashSource,
    DateTime? now,
    Shift? openShift,
    ShiftReport? rawReport,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.finalCloseShift);
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.performReconciliation,
    );
    if (countedCashMinor < 0) {
      throw ValidationException('Counted cash must be zero or greater.');
    }

    final DateTime effectiveNow = now ?? DateTime.now();
    final ({
      Shift openShift,
      ShiftReport rawReport,
      ShiftReconciliation? reconciliation,
      int varianceMinor,
    })
    finalized = await _transactionRepository.runInTransaction(() async {
      final Shift effectiveOpenShift =
          openShift ?? await _shiftSessionService.requireBackendOpenShift();
      final ShiftReport effectiveRawReport =
          rawReport ?? await getShiftReport(effectiveOpenShift.id);
      final readiness = await _shiftSessionService.getShiftCloseReadiness(
        shiftId: effectiveOpenShift.id,
        now: effectiveNow,
      );
      if (!readiness.canFinalClose) {
        throw ShiftCloseBlockedException(readiness);
      }

      final ShiftReconciliationRepository? reconciliationRepository =
          _shiftReconciliationRepository;
      ShiftReconciliation? reconciliation;
      if (reconciliationRepository != null) {
        final StaleFinalCloseRecoveryDetails? staleRecovery =
            await reconciliationRepository.getStaleFinalCloseRecoveryDetails(
              shiftId: effectiveOpenShift.id,
            );
        if (staleRecovery != null) {
          throw StaleFinalCloseReconciliationException(details: staleRecovery);
        }
      }

      final int varianceMinor =
          countedCashMinor - effectiveRawReport.cashTotalMinor;
      if (reconciliationRepository != null) {
        reconciliation = await reconciliationRepository.createReconciliation(
          uuid:
              'shift-reconciliation-${effectiveOpenShift.id}-${effectiveNow.microsecondsSinceEpoch}',
          shiftId: effectiveOpenShift.id,
          kind: ShiftReconciliationKind.finalClose,
          expectedCashMinor: effectiveRawReport.cashTotalMinor,
          countedCashMinor: countedCashMinor,
          varianceMinor: varianceMinor,
          countedCashSource: countedCashSource,
          countedBy: user.id,
          countedAt: effectiveNow,
        );
      }

      await _shiftRepository.closeShift(
        effectiveOpenShift.id,
        user.id,
        now: effectiveNow,
      );

      return (
        openShift: effectiveOpenShift,
        rawReport: effectiveRawReport,
        reconciliation: reconciliation,
        varianceMinor: varianceMinor,
      );
    });
    final double visibilityRatio = await getVisibilityRatio();
    final ShiftReport visibleReport = _reportVisibilityService
        .applyVisibilityToReport(finalized.rawReport, user, visibilityRatio);
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'shift_closed',
      entityType: 'shift',
      entityId: '${finalized.openShift.id}',
      metadata: <String, Object?>{'shift_id': finalized.openShift.id},
      createdAt: effectiveNow,
    );
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'day_end_finalized',
      entityType: 'shift',
      entityId: '${finalized.openShift.id}',
      metadata: <String, Object?>{
        'shift_id': finalized.openShift.id,
        'expected_cash_minor':
            finalized.reconciliation?.expectedCashMinor ??
            finalized.rawReport.cashTotalMinor,
        'counted_cash_minor':
            finalized.reconciliation?.countedCashMinor ?? countedCashMinor,
        'variance_minor':
            finalized.reconciliation?.varianceMinor ?? finalized.varianceMinor,
        'counted_cash_source':
            finalized.reconciliation?.countedCashSource.name ??
            countedCashSource.name,
      },
      createdAt: effectiveNow,
    );
    _logger.audit(
      eventType: 'shift_closed',
      entityId: '${finalized.openShift.id}',
      message: 'Shift closed by admin final close.',
      metadata: <String, Object?>{'closed_by': user.id},
    );

    return ZReportActionResult(
      shiftId: finalized.openShift.id,
      report: visibleReport,
      finalCloseCompleted: true,
      cashierPreviewRecorded: finalized.openShift.hasCashierPreview,
    );
  }

  Future<ZReportActionResult> resumeStaleAdminFinalClose({
    required User user,
    required StaleFinalCloseRecoveryDetails recovery,
    DateTime? now,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.finalCloseShift);
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.performReconciliation,
    );

    final DateTime effectiveNow = now ?? DateTime.now();
    final ({
      Shift openShift,
      ShiftReport rawReport,
      ShiftReconciliation reconciliation,
    })
    resumed = await _transactionRepository.runInTransaction(() async {
      final Shift openShift = await _requireOpenShiftForRecovery(
        recovery.shiftId,
      );
      final ShiftReconciliation reconciliation =
          await _requireRecoveryReconciliation(recovery);
      await _requireRecoveryDetails(recovery);

      final ShiftReport rawReport = await getShiftReport(openShift.id);
      final readiness = await _shiftSessionService.getShiftCloseReadiness(
        shiftId: openShift.id,
        now: effectiveNow,
      );
      if (!readiness.canFinalClose) {
        throw ShiftCloseBlockedException(readiness);
      }

      await _shiftRepository.closeShift(
        openShift.id,
        user.id,
        now: effectiveNow,
      );

      return (
        openShift: openShift,
        rawReport: rawReport,
        reconciliation: reconciliation,
      );
    });

    final double visibilityRatio = await getVisibilityRatio();
    final ShiftReport visibleReport = _reportVisibilityService
        .applyVisibilityToReport(resumed.rawReport, user, visibilityRatio);
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'stale_final_close_resumed',
      entityType: 'shift',
      entityId: '${resumed.openShift.id}',
      metadata: _recoveryAuditMetadata(recovery),
      createdAt: effectiveNow,
    );
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'shift_closed',
      entityType: 'shift',
      entityId: '${resumed.openShift.id}',
      metadata: <String, Object?>{'shift_id': resumed.openShift.id},
      createdAt: effectiveNow,
    );
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'day_end_finalized',
      entityType: 'shift',
      entityId: '${resumed.openShift.id}',
      metadata: <String, Object?>{
        'shift_id': resumed.openShift.id,
        'expected_cash_minor': resumed.reconciliation.expectedCashMinor,
        'counted_cash_minor': resumed.reconciliation.countedCashMinor,
        'variance_minor': resumed.reconciliation.varianceMinor,
        'counted_cash_source': resumed.reconciliation.countedCashSource.name,
      },
      createdAt: effectiveNow,
    );
    _logger.audit(
      eventType: 'stale_final_close_resumed',
      entityId: '${resumed.openShift.id}',
      message: 'Stale final close resumed and completed.',
      metadata: <String, Object?>{
        'user_id': user.id,
        'reconciliation_id': recovery.reconciliationId,
      },
    );

    return ZReportActionResult(
      shiftId: resumed.openShift.id,
      report: visibleReport,
      finalCloseCompleted: true,
      cashierPreviewRecorded: resumed.openShift.hasCashierPreview,
    );
  }

  Future<void> discardStaleAdminFinalClose({
    required User user,
    required StaleFinalCloseRecoveryDetails recovery,
    DateTime? now,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.finalCloseShift);
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.performReconciliation,
    );

    final ShiftReconciliationRepository reconciliationRepository =
        _shiftReconciliationRepository ??
        (throw StaleFinalCloseRecoveryUnavailableException());
    final DateTime effectiveNow = now ?? DateTime.now();
    final StaleFinalCloseRecoveryDetails discarded =
        await _transactionRepository.runInTransaction(() async {
          await _requireOpenShiftForRecovery(recovery.shiftId);
          final StaleFinalCloseRecoveryDetails existingRecovery =
              await _requireRecoveryDetails(recovery);
          final bool deleted = await reconciliationRepository
              .deleteReconciliation(
                reconciliationId: recovery.reconciliationId,
                shiftId: recovery.shiftId,
                kind: ShiftReconciliationKind.finalClose,
              );
          if (!deleted) {
            throw StaleFinalCloseRecoveryUnavailableException();
          }
          return existingRecovery;
        });

    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'stale_final_close_discarded',
      entityType: 'shift',
      entityId: '${discarded.shiftId}',
      metadata: _recoveryAuditMetadata(discarded),
      createdAt: effectiveNow,
    );
    _logger.audit(
      eventType: 'stale_final_close_discarded',
      entityId: '${discarded.shiftId}',
      message: 'Stale final close reconciliation discarded.',
      metadata: <String, Object?>{
        'user_id': user.id,
        'reconciliation_id': discarded.reconciliationId,
      },
    );
  }

  Future<ShiftCashSummary> getShiftCashSummary(int shiftId) async {
    final ShiftReport report = await getShiftReport(shiftId);
    final ShiftReconciliation? reconciliation =
        await _shiftReconciliationRepository?.getByShiftAndKind(
          shiftId: shiftId,
          kind: ShiftReconciliationKind.finalClose,
        );
    return ShiftCashSummary(
      shiftId: shiftId,
      expectedCashMinor: report.cashTotalMinor,
      latestFinalCloseReconciliation: reconciliation,
    );
  }

  Future<double> getVisibilityRatio() {
    return _settingsRepository.getVisibilityRatio();
  }

  Future<ReportSettingsPolicy> getReportSettingsPolicy() {
    return _settingsRepository.getReportSettingsPolicy();
  }

  Future<BusinessIdentitySettings> getBusinessIdentitySettings() {
    return _settingsRepository.getBusinessIdentitySettings();
  }

  Future<CashierZReportSettings> getCashierZReportSettings() {
    return _settingsRepository.getCashierZReportSettings();
  }

  Future<ShiftReport?> getOpenShiftReportForAdmin({required User user}) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.viewFullReports);
    final Shift? openShift = await _shiftSessionService.getBackendOpenShift();
    if (openShift == null) {
      return null;
    }
    return getShiftReport(openShift.id);
  }

  Future<void> updateVisibilityRatio({
    required User user,
    required double ratio,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.viewFullReports);
    await _settingsRepository.updateVisibilityRatio(ratio, userId: user.id);
  }

  Future<void> updateCashierZReportSettings({
    required User user,
    required CashierZReportSettings settings,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.viewFullReports);
    await _settingsRepository.updateCashierZReportSettings(
      settings,
      userId: user.id,
    );
  }

  int _sumTransactionTotals(List<Transaction> transactions) {
    return transactions.fold<int>(
      0,
      (int sum, Transaction transaction) => sum + transaction.totalAmountMinor,
    );
  }

  Future<Shift> _requireOpenShiftForRecovery(int shiftId) async {
    final Shift? shift = await _shiftRepository.getById(shiftId);
    if (shift == null) {
      throw NotFoundException('Shift not found: $shiftId');
    }
    if (shift.status != ShiftStatus.open) {
      throw ShiftClosedException();
    }
    return shift;
  }

  Future<StaleFinalCloseRecoveryDetails> _requireRecoveryDetails(
    StaleFinalCloseRecoveryDetails recovery,
  ) async {
    final ShiftReconciliationRepository reconciliationRepository =
        _shiftReconciliationRepository ??
        (throw StaleFinalCloseRecoveryUnavailableException());
    final StaleFinalCloseRecoveryDetails? existingRecovery =
        await reconciliationRepository.getStaleFinalCloseRecoveryDetails(
          shiftId: recovery.shiftId,
        );
    if (existingRecovery == null ||
        existingRecovery.reconciliationId != recovery.reconciliationId) {
      throw StaleFinalCloseRecoveryUnavailableException();
    }
    return existingRecovery;
  }

  Future<ShiftReconciliation> _requireRecoveryReconciliation(
    StaleFinalCloseRecoveryDetails recovery,
  ) async {
    final ShiftReconciliationRepository reconciliationRepository =
        _shiftReconciliationRepository ??
        (throw StaleFinalCloseRecoveryUnavailableException());
    final ShiftReconciliation? reconciliation = await reconciliationRepository
        .getByShiftAndKind(
          shiftId: recovery.shiftId,
          kind: ShiftReconciliationKind.finalClose,
        );
    if (reconciliation == null ||
        reconciliation.id != recovery.reconciliationId) {
      throw StaleFinalCloseRecoveryUnavailableException();
    }
    return reconciliation;
  }

  Map<String, Object?> _recoveryAuditMetadata(
    StaleFinalCloseRecoveryDetails recovery,
  ) {
    return <String, Object?>{
      'shift_id': recovery.shiftId,
      'reconciliation_id': recovery.reconciliationId,
      'expected_cash_minor': recovery.expectedCashMinor,
      'counted_cash_minor': recovery.countedCashMinor,
      'variance_minor': recovery.varianceMinor,
      'counted_at': recovery.countedAt.toIso8601String(),
      'counted_by_user_id': recovery.countedByUserId,
      'counted_by_name': recovery.countedByName,
    };
  }
}
