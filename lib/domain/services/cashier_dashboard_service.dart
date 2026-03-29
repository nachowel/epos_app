import '../../core/constants/app_strings.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/audit_log_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/audit_log_record.dart';
import '../models/cash_movement.dart';
import '../models/cashier_dashboard_snapshot.dart';
import '../models/open_order_summary.dart';
import '../models/payment.dart';
import '../models/shift.dart';
import '../models/shift_session_snapshot.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'order_service.dart';
import 'shift_session_service.dart';

class CashierDashboardService {
  const CashierDashboardService({
    required ShiftSessionService shiftSessionService,
    required UserRepository userRepository,
    required OrderService orderService,
    required PaymentRepository paymentRepository,
    required TransactionRepository transactionRepository,
    required AuditLogRepository auditLogRepository,
  }) : _shiftSessionService = shiftSessionService,
       _userRepository = userRepository,
       _orderService = orderService,
       _paymentRepository = paymentRepository,
       _transactionRepository = transactionRepository,
       _auditLogRepository = auditLogRepository;

  final ShiftSessionService _shiftSessionService;
  final UserRepository _userRepository;
  final OrderService _orderService;
  final PaymentRepository _paymentRepository;
  final TransactionRepository _transactionRepository;
  final AuditLogRepository _auditLogRepository;

  Future<CashierDashboardSnapshot> getSnapshot({
    required User user,
    int openOrderLimit = 6,
    int activityLimit = 8,
  }) async {
    _ensureCashier(user);

    final ShiftSessionSnapshot shiftSession = await _shiftSessionService
        .getSnapshotForUser(user);
    final Shift? openShift = shiftSession.backendOpenShift;
    if (openShift == null) {
      return CashierDashboardSnapshot(
        shiftSession: shiftSession,
        openedByUser: null,
        cashierPreviewedByUser: null,
        openOrderCount: 0,
        openOrders: const <OpenOrderSummary>[],
        openOrderLoadLevel: OpenOrderLoadLevel.calm,
        activity: const <CashierDashboardActivityItem>[],
        warnings: <DashboardWarning>[
          DashboardWarning(
            type: DashboardWarningType.noShift,
            message: AppStrings.noActiveShiftWarning,
          ),
        ],
        operationalState: ShiftOperationalState.noShift,
      );
    }

    final List<OpenOrderSummary> openOrders = await _orderService
        .getOrderSummariesByShift(openShift.id);
    final List<Transaction> shiftTransactions = await _transactionRepository
        .getByShift(openShift.id);
    final List<Payment> payments = await _paymentRepository.getByShift(
      openShift.id,
    );
    final List<AuditLogRecord> auditLogs = await _auditLogRepository.listRecent(
      limit: 100,
    );
    final OpenOrderLoadLevel loadLevel =
        CashierDashboardSnapshot.computeLoadLevel(openOrders.length);

    return CashierDashboardSnapshot(
      shiftSession: shiftSession,
      openedByUser: await _userRepository.getById(openShift.openedBy),
      cashierPreviewedByUser: openShift.cashierPreviewedBy == null
          ? null
          : await _userRepository.getById(openShift.cashierPreviewedBy!),
      openOrderCount: openOrders.length,
      openOrders: openOrders.take(openOrderLimit).toList(growable: false),
      openOrderLoadLevel: loadLevel,
      activity: _buildActivity(
        shift: openShift,
        payments: payments,
        transactions: shiftTransactions,
        auditLogs: auditLogs,
        limit: activityLimit,
      ),
      warnings: _buildWarnings(
        shiftSession: shiftSession,
        loadLevel: loadLevel,
      ),
      operationalState: _computeOperationalState(shiftSession),
    );
  }

  List<CashierDashboardActivityItem> _buildActivity({
    required Shift shift,
    required List<Payment> payments,
    required List<Transaction> transactions,
    required List<AuditLogRecord> auditLogs,
    required int limit,
  }) {
    final Map<String, Transaction> transactionByUuid = <String, Transaction>{
      for (final Transaction transaction in transactions)
        transaction.uuid: transaction,
    };

    // Primary sources: payments and cancellations from transaction records.
    final List<CashierDashboardActivityItem> primaryItems =
        <CashierDashboardActivityItem>[
          ...payments.map(
            (Payment payment) => CashierDashboardActivityItem(
              type: CashierDashboardActivityType.payment,
              occurredAt: payment.paidAt,
              transactionId: payment.transactionId,
              paymentMethod: payment.method,
            ),
          ),
          ...transactions
              .where(
                (Transaction transaction) =>
                    transaction.status == TransactionStatus.cancelled &&
                    transaction.cancelledAt != null,
              )
              .map(
                (Transaction transaction) => CashierDashboardActivityItem(
                  type: CashierDashboardActivityType.cancellation,
                  occurredAt: transaction.cancelledAt!,
                  transactionId: transaction.id,
                ),
              ),
        ];

    // Track primary-source keys to dedup audit log entries that describe
    // the same logical event (e.g. transaction_cancelled audit log
    // duplicating the cancellation already derived from the transaction).
    final Set<String> primaryKeys = <String>{
      for (final CashierDashboardActivityItem item in primaryItems)
        _dedupKey(item),
    };

    final Iterable<CashierDashboardActivityItem> auditItems = auditLogs
        .map(
          (AuditLogRecord log) => _mapAuditLogToActivity(
            shift: shift,
            log: log,
            transactionByUuid: transactionByUuid,
          ),
        )
        .whereType<CashierDashboardActivityItem>()
        .where(
          (CashierDashboardActivityItem item) =>
              !primaryKeys.contains(_dedupKey(item)),
        );

    final List<CashierDashboardActivityItem> activity =
        <CashierDashboardActivityItem>[...primaryItems, ...auditItems];

    activity.sort(
      (CashierDashboardActivityItem a, CashierDashboardActivityItem b) =>
          b.occurredAt.compareTo(a.occurredAt),
    );

    return activity.take(limit).toList(growable: false);
  }

  /// Produces a key that identifies a logical event for deduplication.
  /// Transaction-linked events use type:transactionId.
  /// Non-transaction events use type:entityId:timestamp for stronger
  /// dedup while still differentiating distinct events of the same type.
  static String _dedupKey(CashierDashboardActivityItem item) {
    if (item.transactionId != null) {
      return '${item.type.name}:${item.transactionId}';
    }
    if (item.entityId != null) {
      return '${item.type.name}:${item.entityId}:${item.occurredAt.millisecondsSinceEpoch}';
    }
    return '${item.type.name}:${item.occurredAt.millisecondsSinceEpoch}';
  }

  CashierDashboardActivityItem? _mapAuditLogToActivity({
    required Shift shift,
    required AuditLogRecord log,
    required Map<String, Transaction> transactionByUuid,
  }) {
    switch (log.action) {
      case 'receipt_reprinted':
        final Transaction? transaction = transactionByUuid[log.entityId];
        if (transaction == null || transaction.shiftId != shift.id) {
          return null;
        }
        return CashierDashboardActivityItem(
          type: CashierDashboardActivityType.receiptReprint,
          occurredAt: log.createdAt,
          transactionId: transaction.id,
        );
      case 'day_end_preview_run':
        if (log.entityType != 'shift' || log.entityId != '${shift.id}') {
          return null;
        }
        return CashierDashboardActivityItem(
          type: CashierDashboardActivityType.cashierPreview,
          occurredAt: log.createdAt,
          entityId: log.entityId,
        );
      case 'cash_movement_created':
        final Object? shiftId = log.metadata['shift_id'];
        if (shiftId is! int || shiftId != shift.id) {
          return null;
        }
        final String? typeName = log.metadata['type'] as String?;
        final CashMovementType? type = switch (typeName) {
          'income' => CashMovementType.income,
          'expense' => CashMovementType.expense,
          _ => null,
        };
        if (type == null) {
          return null;
        }
        return CashierDashboardActivityItem(
          type: CashierDashboardActivityType.cashMovement,
          occurredAt: log.createdAt,
          entityId: log.entityId,
          cashMovementType: type,
          cashMovementCategory: log.metadata['category'] as String?,
        );
      case 'transaction_cancelled':
        final Transaction? transaction = transactionByUuid[log.entityId];
        if (transaction == null || transaction.shiftId != shift.id) {
          return null;
        }
        return CashierDashboardActivityItem(
          type: CashierDashboardActivityType.cancellation,
          occurredAt: log.createdAt,
          transactionId: transaction.id,
        );
    }

    return null;
  }

  static List<DashboardWarning> _buildWarnings({
    required ShiftSessionSnapshot shiftSession,
    required OpenOrderLoadLevel loadLevel,
  }) {
    final List<DashboardWarning> warnings = <DashboardWarning>[];

    if (shiftSession.backendOpenShift == null) {
      warnings.add(
        DashboardWarning(
          type: DashboardWarningType.noShift,
          message: AppStrings.noActiveShiftWarning,
        ),
      );
    }

    if (shiftSession.cashierPreviewActive) {
      warnings.add(
        DashboardWarning(
          type: DashboardWarningType.previewTaken,
          message: AppStrings.cashierPreviewTakenWarning,
        ),
      );
    }

    if (loadLevel == OpenOrderLoadLevel.high) {
      warnings.add(
        DashboardWarning(
          type: DashboardWarningType.highLoad,
          message: AppStrings.openOrderHighLoadWarning,
        ),
      );
    }

    return warnings;
  }

  static ShiftOperationalState _computeOperationalState(
    ShiftSessionSnapshot shiftSession,
  ) {
    if (shiftSession.backendOpenShift == null) {
      return ShiftOperationalState.noShift;
    }
    if (shiftSession.salesLocked || shiftSession.cashierPreviewActive) {
      return ShiftOperationalState.previewTakenLocked;
    }
    return ShiftOperationalState.normal;
  }

  void _ensureCashier(User user) {
    if (user.role != UserRole.cashier) {
      throw UnauthorisedException(
        'Only cashiers can access the cashier dashboard.',
      );
    }
  }
}
