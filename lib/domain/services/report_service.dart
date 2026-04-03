import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/breakfast_configuration_repository.dart';
import '../../data/repositories/payment_adjustment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/shift_reconciliation_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/breakfast_rebuild.dart';
import '../models/order_modifier.dart';
import '../models/payment_adjustment.dart';
import '../models/payment.dart';
import '../models/authorization_policy.dart';
import '../models/business_identity_settings.dart';
import '../models/cashier_z_report_settings.dart';
import '../models/report_settings_policy.dart';
import '../models/semantic_sales_analytics.dart';
import '../models/shift_cash_summary.dart';
import '../models/shift.dart';
import '../models/shift_report.dart';
import '../models/shift_reconciliation.dart';
import '../models/stale_final_close_recovery_details.dart';
import '../models/transaction.dart';
import '../models/transaction_line.dart';
import '../models/user.dart';
import '../models/z_report_action_result.dart';
import '../models/analytics/analytics_period.dart';
import 'audit_log_service.dart';
import 'breakfast_analytics_extractor.dart';
import 'breakfast_requested_state_mapper.dart';
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
    BreakfastConfigurationRepository? breakfastConfigurationRepository,
    required SettingsRepository settingsRepository,
    required ReportVisibilityService reportVisibilityService,
    BreakfastAnalyticsExtractor breakfastAnalyticsExtractor =
        const BreakfastAnalyticsExtractor(),
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _shiftRepository = shiftRepository,
       _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _paymentRepository = paymentRepository,
       _paymentAdjustmentRepository = paymentAdjustmentRepository,
       _shiftReconciliationRepository = shiftReconciliationRepository,
       _breakfastConfigurationRepository = breakfastConfigurationRepository,
       _settingsRepository = settingsRepository,
       _reportVisibilityService = reportVisibilityService,
       _breakfastAnalyticsExtractor = breakfastAnalyticsExtractor,
       _auditLogService = auditLogService,
       _logger = logger;

  final ShiftRepository _shiftRepository;
  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final PaymentRepository _paymentRepository;
  final PaymentAdjustmentRepository? _paymentAdjustmentRepository;
  final ShiftReconciliationRepository? _shiftReconciliationRepository;
  final BreakfastConfigurationRepository? _breakfastConfigurationRepository;
  final SettingsRepository _settingsRepository;
  final ReportVisibilityService _reportVisibilityService;
  final BreakfastAnalyticsExtractor _breakfastAnalyticsExtractor;
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
    final SemanticSalesAnalytics semanticSalesAnalytics =
        await _buildSemanticSalesAnalytics(paidTransactions);

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
      semanticSalesAnalytics: semanticSalesAnalytics,
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

  Future<SemanticSalesAnalytics> getSemanticSalesAnalyticsForPeriod({
    required User user,
    required AnalyticsPeriodSelection periodSelection,
    DateTime? now,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.viewFullReports);
    final _AnalyticsWindow window = _resolveAnalyticsWindow(
      selection: periodSelection,
      now: now ?? DateTime.now(),
    );
    final List<Transaction> paidTransactions = await _transactionRepository
        .getPaidTransactionsBetween(
          startInclusive: window.startInclusive,
          endExclusive: window.endExclusive,
        );
    return _buildSemanticSalesAnalytics(paidTransactions);
  }

  int _sumTransactionTotals(List<Transaction> transactions) {
    return transactions.fold<int>(
      0,
      (int sum, Transaction transaction) => sum + transaction.totalAmountMinor,
    );
  }

  Future<SemanticSalesAnalytics> _buildSemanticSalesAnalytics(
    List<Transaction> paidTransactions,
  ) async {
    final BreakfastConfigurationRepository? configurationRepository =
        _breakfastConfigurationRepository;
    if (configurationRepository == null || paidTransactions.isEmpty) {
      return const SemanticSalesAnalytics.empty();
    }

    final Map<int, _RootProductAccumulator> rootBuckets =
        <int, _RootProductAccumulator>{};
    final Map<ModifierChargeReason, _ChargeReasonAccumulator> reasonBuckets =
        <ModifierChargeReason, _ChargeReasonAccumulator>{};
    final Map<_RootItemKey, _ItemBehaviorAccumulator> addedBuckets =
        <_RootItemKey, _ItemBehaviorAccumulator>{};
    final Map<_RootItemKey, _ItemBehaviorAccumulator> removedBuckets =
        <_RootItemKey, _ItemBehaviorAccumulator>{};
    final Map<_ChoiceAnalyticsKey, _ChoiceSelectionAccumulator> choiceBuckets =
        <_ChoiceAnalyticsKey, _ChoiceSelectionAccumulator>{};
    final Map<_VariantAnalyticsKey, _VariantAccumulator> variantBuckets =
        <_VariantAnalyticsKey, _VariantAccumulator>{};
    final Map<int, BreakfastSetConfiguration?> configurationCache =
        <int, BreakfastSetConfiguration?>{};
    final Map<int, String> fallbackItemNames = <int, String>{};
    final Set<int> itemProductIds = <int>{};
    final Set<String> dataQualityNotes = <String>{};
    bool inferredChoiceGroups = false;

    for (final Transaction transaction in paidTransactions) {
      final List<TransactionLine> lines = await _transactionRepository.getLines(
        transaction.id,
      );

      for (final TransactionLine line in lines) {
        if (line.pricingMode != TransactionLinePricingMode.set) {
          continue;
        }

        final _RootProductAccumulator rootAccumulator = rootBuckets.putIfAbsent(
          line.productId,
          () => _RootProductAccumulator(rootProductName: line.productName),
        );
        rootAccumulator.quantitySold += line.quantity;
        rootAccumulator.revenueMinor += line.lineTotalMinor;

        final List<OrderModifier> modifiers = await _transactionRepository
            .getModifiersByLine(line.id);
        final BreakfastAnalyticsSnapshot analyticsSnapshot =
            _breakfastAnalyticsExtractor.extract(modifiers);
        for (final BreakfastModifierAnalyticsEntry entry
            in analyticsSnapshot.entries) {
          itemProductIds.add(entry.itemProductId);
          final _ChargeReasonAccumulator accumulator = reasonBuckets
              .putIfAbsent(entry.chargeReason, _ChargeReasonAccumulator.new);
          accumulator.totalQuantity += entry.totalQuantity;
          accumulator.revenueMinor += entry.totalRevenueMinor;
        }
        for (final OrderModifier modifier in modifiers) {
          final ModifierChargeReason? reason = modifier.chargeReason;
          final int? itemProductId = modifier.itemProductId;
          if (reason != null &&
              reason != ModifierChargeReason.removalDiscount) {
            reasonBuckets.putIfAbsent(reason, _ChargeReasonAccumulator.new)
              ..eventCount += 1;
          }
          if (itemProductId != null) {
            itemProductIds.add(itemProductId);
            fallbackItemNames.putIfAbsent(
              itemProductId,
              () => modifier.itemName,
            );
          }
        }

        final BreakfastSetConfiguration? configuration =
            configurationCache.containsKey(line.productId)
            ? configurationCache[line.productId]
            : await configurationRepository.loadSetConfiguration(
                line.productId,
              );
        configurationCache[line.productId] = configuration;

        if (configuration == null) {
          final BreakfastRequestedState requestedState =
              BreakfastRequestedStateMapper.reconstructWithoutConfiguration(
                modifiers: modifiers,
              );
          if (modifiers.any(
            (OrderModifier modifier) =>
                modifier.action == ModifierAction.choice &&
                modifier.chargeReason == ModifierChargeReason.includedChoice &&
                modifier.itemProductId != null &&
                modifier.sourceGroupId == null,
          )) {
            dataQualityNotes.add(
              'Legacy semantic modifier rows for root product ${line.productId} are missing source group IDs and cannot be fully grouped after the live configuration was removed.',
            );
          }
          dataQualityNotes.add(
            'Choice-group analytics for root product ${line.productId} are using archived semantic modifier data because the current configuration is no longer available.',
          );
          _accumulateRequestedStateBehaviors(
            rootProductId: line.productId,
            rootProductName: line.productName,
            requestedState: requestedState,
            modifiers: modifiers,
            addedBuckets: addedBuckets,
            removedBuckets: removedBuckets,
          );
          _accumulateChoiceSelections(
            rootProductId: line.productId,
            rootProductName: line.productName,
            paidAt: transaction.paidAt ?? transaction.createdAt,
            requestedState: requestedState,
            configuration: null,
            choiceBuckets: choiceBuckets,
            dataQualityNotes: dataQualityNotes,
            fallbackItemNames: fallbackItemNames,
            itemProductIds: itemProductIds,
          );
          _accumulateBundleVariant(
            rootProductId: line.productId,
            rootProductName: line.productName,
            lineRevenueMinor: line.lineTotalMinor,
            requestedState: requestedState,
            variantBuckets: variantBuckets,
          );
          continue;
        }

        final bool needsLegacyInference = modifiers.any(
          (OrderModifier modifier) =>
              modifier.action == ModifierAction.choice &&
              modifier.chargeReason == ModifierChargeReason.includedChoice &&
              modifier.itemProductId != null &&
              modifier.sourceGroupId == null,
        );
        inferredChoiceGroups = inferredChoiceGroups || needsLegacyInference;
        final BreakfastRequestedState requestedState =
            BreakfastRequestedStateMapper.reconstruct(
              modifiers: modifiers,
              configuration: configuration,
            );

        _accumulateRequestedStateBehaviors(
          rootProductId: line.productId,
          rootProductName: line.productName,
          requestedState: requestedState,
          modifiers: modifiers,
          addedBuckets: addedBuckets,
          removedBuckets: removedBuckets,
        );
        _accumulateChoiceSelections(
          rootProductId: line.productId,
          rootProductName: line.productName,
          paidAt: transaction.paidAt ?? transaction.createdAt,
          requestedState: requestedState,
          configuration: configuration,
          choiceBuckets: choiceBuckets,
          dataQualityNotes: dataQualityNotes,
          fallbackItemNames: fallbackItemNames,
          itemProductIds: itemProductIds,
        );
        _accumulateBundleVariant(
          rootProductId: line.productId,
          rootProductName: line.productName,
          lineRevenueMinor: line.lineTotalMinor,
          requestedState: requestedState,
          variantBuckets: variantBuckets,
        );
      }
    }

    if (rootBuckets.isEmpty) {
      return const SemanticSalesAnalytics.empty();
    }

    if (inferredChoiceGroups) {
      dataQualityNotes.add(
        'Legacy semantic modifier rows without persisted source group IDs were inferred from the current semantic configuration.',
      );
    }

    final Map<int, BreakfastCatalogProduct> itemNamesByProductId =
        await configurationRepository.loadCatalogProductsByIds(itemProductIds);

    String resolveItemName(int itemProductId) {
      return itemNamesByProductId[itemProductId]?.name ??
          fallbackItemNames[itemProductId] ??
          'Product $itemProductId';
    }

    final List<SemanticRootProductAnalytics> rootProducts =
        rootBuckets.entries
            .map(
              (MapEntry<int, _RootProductAccumulator> entry) =>
                  SemanticRootProductAnalytics(
                    rootProductId: entry.key,
                    rootProductName: entry.value.rootProductName,
                    quantitySold: entry.value.quantitySold,
                    revenueMinor: entry.value.revenueMinor,
                  ),
            )
            .toList(growable: true)
          ..sort(_compareRootProducts);

    final Map<_RootGroupKey, int> choiceGroupTotals = <_RootGroupKey, int>{};
    for (final MapEntry<_ChoiceAnalyticsKey, _ChoiceSelectionAccumulator> entry
        in choiceBuckets.entries) {
      final _RootGroupKey rootGroupKey = _RootGroupKey(
        rootProductId: entry.key.rootProductId,
        groupId: entry.key.groupId,
      );
      choiceGroupTotals.update(
        rootGroupKey,
        (int count) => count + entry.value.totalSelectedQuantity,
        ifAbsent: () => entry.value.totalSelectedQuantity,
      );
    }

    final List<SemanticChoiceSelectionAnalytics> choiceSelections =
        choiceBuckets.entries
            .map((
              MapEntry<_ChoiceAnalyticsKey, _ChoiceSelectionAccumulator> entry,
            ) {
              final int totalForGroup =
                  choiceGroupTotals[_RootGroupKey(
                    rootProductId: entry.key.rootProductId,
                    groupId: entry.key.groupId,
                  )] ??
                  0;
              return SemanticChoiceSelectionAnalytics(
                rootProductId: entry.key.rootProductId,
                rootProductName: entry.value.rootProductName,
                groupId: entry.key.groupId,
                groupName: entry.value.groupName,
                itemProductId: entry.key.itemProductId,
                itemName: resolveItemName(entry.key.itemProductId),
                selectionCount: entry.value.selectionCount,
                totalSelectedQuantity: entry.value.totalSelectedQuantity,
                distributionPercent: totalForGroup <= 0
                    ? 0
                    : (entry.value.totalSelectedQuantity * 100) / totalForGroup,
                trend: entry.value.buildTrend(),
              );
            })
            .toList(growable: true)
          ..sort(_compareChoiceSelections);

    final List<SemanticItemBehaviorAnalytics> addedItems =
        _buildItemBehaviorAnalytics(
          buckets: addedBuckets,
          rootBuckets: rootBuckets,
          resolveItemName: resolveItemName,
        );
    final List<SemanticItemBehaviorAnalytics> removedItems =
        _buildItemBehaviorAnalytics(
          buckets: removedBuckets,
          rootBuckets: rootBuckets,
          resolveItemName: resolveItemName,
        );

    final List<SemanticChargeReasonAnalytics> chargeReasonBreakdown =
        reasonBuckets.entries
            .map(
              (
                MapEntry<ModifierChargeReason, _ChargeReasonAccumulator> entry,
              ) => SemanticChargeReasonAnalytics(
                chargeReason: entry.key,
                eventCount: entry.value.eventCount,
                totalQuantity: entry.value.totalQuantity,
                revenueMinor: entry.value.revenueMinor,
              ),
            )
            .toList(growable: true)
          ..sort(
            (
              SemanticChargeReasonAnalytics a,
              SemanticChargeReasonAnalytics b,
            ) => b.revenueMinor.compareTo(a.revenueMinor),
          );

    final List<SemanticBundleVariantAnalytics> bundleVariants =
        variantBuckets.entries
            .map(
              (MapEntry<_VariantAnalyticsKey, _VariantAccumulator> entry) =>
                  SemanticBundleVariantAnalytics(
                    rootProductId: entry.key.rootProductId,
                    rootProductName: entry.value.rootProductName,
                    variantKey: entry.key.variantKey,
                    orderCount: entry.value.orderCount,
                    revenueMinor: entry.value.revenueMinor,
                    chosenItemProductIds: entry.value.chosenItemProductIds,
                    chosenItemNames: entry.value.chosenItemProductIds
                        .map(resolveItemName)
                        .toList(growable: false),
                    removedItemProductIds: entry.value.removedItemProductIds,
                    removedItemNames: entry.value.removedItemProductIds
                        .map(resolveItemName)
                        .toList(growable: false),
                    addedItemProductIds: entry.value.addedItemProductIds,
                    addedItemNames: entry.value.addedItemProductIds
                        .map(resolveItemName)
                        .toList(growable: false),
                  ),
            )
            .toList(growable: true)
          ..sort((
            SemanticBundleVariantAnalytics a,
            SemanticBundleVariantAnalytics b,
          ) {
            final int orderCompare = b.orderCount.compareTo(a.orderCount);
            if (orderCompare != 0) {
              return orderCompare;
            }
            return b.revenueMinor.compareTo(a.revenueMinor);
          });

    return SemanticSalesAnalytics(
      rootProducts: List<SemanticRootProductAnalytics>.unmodifiable(
        rootProducts,
      ),
      choiceSelections: List<SemanticChoiceSelectionAnalytics>.unmodifiable(
        choiceSelections,
      ),
      addedItems: List<SemanticItemBehaviorAnalytics>.unmodifiable(addedItems),
      removedItems: List<SemanticItemBehaviorAnalytics>.unmodifiable(
        removedItems,
      ),
      chargeReasonBreakdown: List<SemanticChargeReasonAnalytics>.unmodifiable(
        chargeReasonBreakdown,
      ),
      bundleVariants: List<SemanticBundleVariantAnalytics>.unmodifiable(
        bundleVariants,
      ),
      dataQualityNotes: List<String>.unmodifiable(
        dataQualityNotes.toList(growable: false)..sort(),
      ),
    );
  }

  void _accumulateDirectItemBehaviors({
    required int rootProductId,
    required String rootProductName,
    required List<OrderModifier> modifiers,
    required Map<_RootItemKey, _ItemBehaviorAccumulator> addedBuckets,
    required Map<_RootItemKey, _ItemBehaviorAccumulator> removedBuckets,
  }) {
    for (final OrderModifier modifier in modifiers) {
      final int? itemProductId = modifier.itemProductId;
      if (itemProductId == null) {
        continue;
      }
      if (modifier.action == ModifierAction.remove) {
        removedBuckets.putIfAbsent(
            _RootItemKey(
              rootProductId: rootProductId,
              itemProductId: itemProductId,
            ),
            () => _ItemBehaviorAccumulator(rootProductName: rootProductName),
          )
          ..occurrenceCount += 1
          ..totalQuantity += modifier.quantity;
        continue;
      }
      if (modifier.action == ModifierAction.add &&
          modifier.chargeReason != ModifierChargeReason.removalDiscount) {
        addedBuckets.putIfAbsent(
            _RootItemKey(
              rootProductId: rootProductId,
              itemProductId: itemProductId,
            ),
            () => _ItemBehaviorAccumulator(rootProductName: rootProductName),
          )
          ..occurrenceCount += 1
          ..totalQuantity += modifier.quantity
          ..revenueMinor += modifier.priceEffectMinor;
      }
    }
  }

  void _accumulateRequestedStateBehaviors({
    required int rootProductId,
    required String rootProductName,
    required BreakfastRequestedState requestedState,
    required List<OrderModifier> modifiers,
    required Map<_RootItemKey, _ItemBehaviorAccumulator> addedBuckets,
    required Map<_RootItemKey, _ItemBehaviorAccumulator> removedBuckets,
  }) {
    final Map<int, int> addRevenueByProductId = <int, int>{};
    for (final OrderModifier modifier in modifiers) {
      final int? itemProductId = modifier.itemProductId;
      if (modifier.action == ModifierAction.add &&
          itemProductId != null &&
          modifier.chargeReason != ModifierChargeReason.removalDiscount) {
        addRevenueByProductId.update(
          itemProductId,
          (int value) => value + modifier.priceEffectMinor,
          ifAbsent: () => modifier.priceEffectMinor,
        );
      }
    }

    for (final BreakfastRemovedSetItemRequest removal
        in requestedState.removedSetItems) {
      removedBuckets.putIfAbsent(
          _RootItemKey(
            rootProductId: rootProductId,
            itemProductId: removal.itemProductId,
          ),
          () => _ItemBehaviorAccumulator(rootProductName: rootProductName),
        )
        ..occurrenceCount += 1
        ..totalQuantity += removal.quantity;
    }

    for (final BreakfastAddedProductRequest addition
        in requestedState.addedProducts) {
      addedBuckets.putIfAbsent(
          _RootItemKey(
            rootProductId: rootProductId,
            itemProductId: addition.itemProductId,
          ),
          () => _ItemBehaviorAccumulator(rootProductName: rootProductName),
        )
        ..occurrenceCount += 1
        ..totalQuantity += addition.quantity
        ..revenueMinor += addRevenueByProductId[addition.itemProductId] ?? 0;
    }
  }

  void _accumulateChoiceSelections({
    required int rootProductId,
    required String rootProductName,
    required DateTime paidAt,
    required BreakfastRequestedState requestedState,
    required BreakfastSetConfiguration? configuration,
    required Map<_ChoiceAnalyticsKey, _ChoiceSelectionAccumulator>
    choiceBuckets,
    required Set<String> dataQualityNotes,
    required Map<int, String> fallbackItemNames,
    required Set<int> itemProductIds,
  }) {
    final DateTime trendDate = DateTime(paidAt.year, paidAt.month, paidAt.day);
    for (final BreakfastChosenGroupRequest choice
        in requestedState.chosenGroups) {
      final int? selectedItemProductId = choice.selectedItemProductId;
      if (selectedItemProductId == null || choice.requestedQuantity <= 0) {
        continue;
      }
      final BreakfastChoiceGroupConfig? group = configuration?.findGroup(
        choice.groupId,
      );
      final BreakfastChoiceGroupMemberConfig? member = group?.findMember(
        selectedItemProductId,
      );
      if (group == null) {
        dataQualityNotes.add(
          'Choice-group analytics for root product $rootProductId are using archived group ${choice.groupId} from persisted semantic modifiers because the current configuration no longer contains that group.',
        );
      } else if (member == null) {
        dataQualityNotes.add(
          'Choice-group analytics for root product $rootProductId are using persisted group ${group.groupId} for item $selectedItemProductId because the current configuration no longer matches that historical membership.',
        );
      }
      itemProductIds.add(selectedItemProductId);
      fallbackItemNames.putIfAbsent(
        selectedItemProductId,
        () => member?.displayName ?? 'Product $selectedItemProductId',
      );
      choiceBuckets.putIfAbsent(
          _ChoiceAnalyticsKey(
            rootProductId: rootProductId,
            groupId: choice.groupId,
            itemProductId: selectedItemProductId,
          ),
          () => _ChoiceSelectionAccumulator(
            rootProductName: rootProductName,
            groupName: group?.groupName ?? 'Group #${choice.groupId}',
          ),
        )
        ..selectionCount += 1
        ..totalSelectedQuantity += choice.requestedQuantity
        ..track(trendDate, choice.requestedQuantity);
    }
  }

  void _accumulateBundleVariant({
    required int rootProductId,
    required String rootProductName,
    required int lineRevenueMinor,
    required BreakfastRequestedState requestedState,
    required Map<_VariantAnalyticsKey, _VariantAccumulator> variantBuckets,
  }) {
    final List<_VariantItem> chosenItems =
        requestedState.chosenGroups
            .where(
              (BreakfastChosenGroupRequest choice) =>
                  choice.selectedItemProductId != null &&
                  choice.requestedQuantity > 0,
            )
            .map(
              (BreakfastChosenGroupRequest choice) => _VariantItem(
                productId: choice.selectedItemProductId!,
                quantity: choice.requestedQuantity,
              ),
            )
            .toList(growable: true)
          ..sort(_compareVariantItems);
    final List<_VariantItem> removedItems =
        requestedState.removedSetItems
            .where(
              (BreakfastRemovedSetItemRequest removal) => removal.quantity > 0,
            )
            .map(
              (BreakfastRemovedSetItemRequest removal) => _VariantItem(
                productId: removal.itemProductId,
                quantity: removal.quantity,
              ),
            )
            .toList(growable: true)
          ..sort(_compareVariantItems);
    final List<_VariantItem> addedItems =
        requestedState.addedProducts
            .where((BreakfastAddedProductRequest add) => add.quantity > 0)
            .map(
              (BreakfastAddedProductRequest add) => _VariantItem(
                productId: add.itemProductId,
                quantity: add.quantity,
              ),
            )
            .toList(growable: true)
          ..sort(_compareVariantItems);

    final String variantKey = _buildVariantKey(
      chosenItems: chosenItems,
      removedItems: removedItems,
      addedItems: addedItems,
    );
    variantBuckets.putIfAbsent(
        _VariantAnalyticsKey(
          rootProductId: rootProductId,
          variantKey: variantKey,
        ),
        () => _VariantAccumulator(
          rootProductName: rootProductName,
          chosenItemProductIds: chosenItems
              .map((_VariantItem item) => item.productId)
              .toList(growable: false),
          removedItemProductIds: removedItems
              .map((_VariantItem item) => item.productId)
              .toList(growable: false),
          addedItemProductIds: addedItems
              .map((_VariantItem item) => item.productId)
              .toList(growable: false),
        ),
      )
      ..orderCount += 1
      ..revenueMinor += lineRevenueMinor;
  }

  List<SemanticItemBehaviorAnalytics> _buildItemBehaviorAnalytics({
    required Map<_RootItemKey, _ItemBehaviorAccumulator> buckets,
    required Map<int, _RootProductAccumulator> rootBuckets,
    required String Function(int itemProductId) resolveItemName,
  }) {
    final List<SemanticItemBehaviorAnalytics> analytics = buckets.entries
        .map((MapEntry<_RootItemKey, _ItemBehaviorAccumulator> entry) {
          final int rootQuantitySold =
              rootBuckets[entry.key.rootProductId]?.quantitySold ?? 0;
          return SemanticItemBehaviorAnalytics(
            rootProductId: entry.key.rootProductId,
            rootProductName: entry.value.rootProductName,
            itemProductId: entry.key.itemProductId,
            itemName: resolveItemName(entry.key.itemProductId),
            occurrenceCount: entry.value.occurrenceCount,
            totalQuantity: entry.value.totalQuantity,
            revenueMinor: entry.value.revenueMinor,
            percentageOfRootSales: rootQuantitySold <= 0
                ? 0
                : (entry.value.occurrenceCount * 100) / rootQuantitySold,
          );
        })
        .toList(growable: true);
    analytics.sort((
      SemanticItemBehaviorAnalytics a,
      SemanticItemBehaviorAnalytics b,
    ) {
      final int occurrenceCompare = b.occurrenceCount.compareTo(
        a.occurrenceCount,
      );
      if (occurrenceCompare != 0) {
        return occurrenceCompare;
      }
      return b.totalQuantity.compareTo(a.totalQuantity);
    });
    return analytics;
  }

  int _compareRootProducts(
    SemanticRootProductAnalytics a,
    SemanticRootProductAnalytics b,
  ) {
    final int quantityCompare = b.quantitySold.compareTo(a.quantitySold);
    if (quantityCompare != 0) {
      return quantityCompare;
    }
    return b.revenueMinor.compareTo(a.revenueMinor);
  }

  int _compareChoiceSelections(
    SemanticChoiceSelectionAnalytics a,
    SemanticChoiceSelectionAnalytics b,
  ) {
    final int countCompare = b.totalSelectedQuantity.compareTo(
      a.totalSelectedQuantity,
    );
    if (countCompare != 0) {
      return countCompare;
    }
    final int rootCompare = a.rootProductId.compareTo(b.rootProductId);
    if (rootCompare != 0) {
      return rootCompare;
    }
    final int groupCompare = a.groupId.compareTo(b.groupId);
    if (groupCompare != 0) {
      return groupCompare;
    }
    return a.itemProductId.compareTo(b.itemProductId);
  }

  int _compareVariantItems(_VariantItem a, _VariantItem b) {
    final int productCompare = a.productId.compareTo(b.productId);
    if (productCompare != 0) {
      return productCompare;
    }
    return a.quantity.compareTo(b.quantity);
  }

  String _buildVariantKey({
    required List<_VariantItem> chosenItems,
    required List<_VariantItem> removedItems,
    required List<_VariantItem> addedItems,
  }) {
    String serialize(List<_VariantItem> items) {
      if (items.isEmpty) {
        return '-';
      }
      return items
          .map((_VariantItem item) => '${item.productId}x${item.quantity}')
          .join('|');
    }

    return 'choices:${serialize(chosenItems)};removed:${serialize(removedItems)};added:${serialize(addedItems)}';
  }

  _AnalyticsWindow _resolveAnalyticsWindow({
    required AnalyticsPeriodSelection selection,
    required DateTime now,
  }) {
    DateTime startOfDay(DateTime value) {
      return DateTime(value.year, value.month, value.day);
    }

    final DateTime today = startOfDay(now);
    if (selection.isCustom) {
      final DateTime start = startOfDay(selection.start!);
      final DateTime endInclusive = startOfDay(selection.end!);
      return _AnalyticsWindow(
        startInclusive: start,
        endExclusive: endInclusive.add(const Duration(days: 1)),
      );
    }

    switch (selection.preset) {
      case AnalyticsPresetPeriod.today:
        return _AnalyticsWindow(
          startInclusive: today,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case AnalyticsPresetPeriod.thisWeek:
        final int offset = today.weekday - DateTime.monday;
        final DateTime weekStart = today.subtract(Duration(days: offset));
        return _AnalyticsWindow(
          startInclusive: weekStart,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case AnalyticsPresetPeriod.thisMonth:
        final DateTime monthStart = DateTime(today.year, today.month);
        return _AnalyticsWindow(
          startInclusive: monthStart,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case AnalyticsPresetPeriod.last14Days:
        return _AnalyticsWindow(
          startInclusive: today.subtract(const Duration(days: 13)),
          endExclusive: today.add(const Duration(days: 1)),
        );
      case null:
        return _AnalyticsWindow(
          startInclusive: today,
          endExclusive: today.add(const Duration(days: 1)),
        );
    }
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

class _RootProductAccumulator {
  _RootProductAccumulator({required this.rootProductName});

  final String rootProductName;
  int quantitySold = 0;
  int revenueMinor = 0;
}

class _ChargeReasonAccumulator {
  int eventCount = 0;
  int totalQuantity = 0;
  int revenueMinor = 0;
}

class _RootItemKey {
  const _RootItemKey({
    required this.rootProductId,
    required this.itemProductId,
  });

  final int rootProductId;
  final int itemProductId;

  @override
  bool operator ==(Object other) {
    return other is _RootItemKey &&
        other.rootProductId == rootProductId &&
        other.itemProductId == itemProductId;
  }

  @override
  int get hashCode => Object.hash(rootProductId, itemProductId);
}

class _ItemBehaviorAccumulator {
  _ItemBehaviorAccumulator({required this.rootProductName});

  final String rootProductName;
  int occurrenceCount = 0;
  int totalQuantity = 0;
  int revenueMinor = 0;
}

class _ChoiceAnalyticsKey {
  const _ChoiceAnalyticsKey({
    required this.rootProductId,
    required this.groupId,
    required this.itemProductId,
  });

  final int rootProductId;
  final int groupId;
  final int itemProductId;

  @override
  bool operator ==(Object other) {
    return other is _ChoiceAnalyticsKey &&
        other.rootProductId == rootProductId &&
        other.groupId == groupId &&
        other.itemProductId == itemProductId;
  }

  @override
  int get hashCode => Object.hash(rootProductId, groupId, itemProductId);
}

class _RootGroupKey {
  const _RootGroupKey({required this.rootProductId, required this.groupId});

  final int rootProductId;
  final int groupId;

  @override
  bool operator ==(Object other) {
    return other is _RootGroupKey &&
        other.rootProductId == rootProductId &&
        other.groupId == groupId;
  }

  @override
  int get hashCode => Object.hash(rootProductId, groupId);
}

class _ChoiceSelectionAccumulator {
  _ChoiceSelectionAccumulator({
    required this.rootProductName,
    required this.groupName,
  });

  final String rootProductName;
  final String groupName;
  final Map<DateTime, _TrendAccumulator> _trendByDate =
      <DateTime, _TrendAccumulator>{};
  int selectionCount = 0;
  int totalSelectedQuantity = 0;

  void track(DateTime date, int quantity) {
    final _TrendAccumulator accumulator = _trendByDate.putIfAbsent(
      date,
      _TrendAccumulator.new,
    );
    accumulator.count += 1;
    accumulator.quantity += quantity;
  }

  List<SemanticAnalyticsTrendPoint> buildTrend() {
    final List<MapEntry<DateTime, _TrendAccumulator>> entries =
        _trendByDate.entries.toList(growable: true)..sort(
          (
            MapEntry<DateTime, _TrendAccumulator> a,
            MapEntry<DateTime, _TrendAccumulator> b,
          ) => a.key.compareTo(b.key),
        );
    return entries
        .map(
          (MapEntry<DateTime, _TrendAccumulator> entry) =>
              SemanticAnalyticsTrendPoint(
                date: entry.key,
                count: entry.value.count,
                quantity: entry.value.quantity,
              ),
        )
        .toList(growable: false);
  }
}

class _TrendAccumulator {
  int count = 0;
  int quantity = 0;
}

class _VariantAnalyticsKey {
  const _VariantAnalyticsKey({
    required this.rootProductId,
    required this.variantKey,
  });

  final int rootProductId;
  final String variantKey;

  @override
  bool operator ==(Object other) {
    return other is _VariantAnalyticsKey &&
        other.rootProductId == rootProductId &&
        other.variantKey == variantKey;
  }

  @override
  int get hashCode => Object.hash(rootProductId, variantKey);
}

class _VariantAccumulator {
  _VariantAccumulator({
    required this.rootProductName,
    required this.chosenItemProductIds,
    required this.removedItemProductIds,
    required this.addedItemProductIds,
  });

  final String rootProductName;
  final List<int> chosenItemProductIds;
  final List<int> removedItemProductIds;
  final List<int> addedItemProductIds;
  int orderCount = 0;
  int revenueMinor = 0;
}

class _VariantItem {
  const _VariantItem({required this.productId, required this.quantity});

  final int productId;
  final int quantity;
}

class _AnalyticsWindow {
  const _AnalyticsWindow({
    required this.startInclusive,
    required this.endExclusive,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;
}
