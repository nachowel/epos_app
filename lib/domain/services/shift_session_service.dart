import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/shift_repository.dart';
import '../models/authorization_policy.dart';
import '../models/interaction_block_reason.dart';
import '../models/shift.dart';
import '../models/shift_close_readiness.dart';
import '../models/shift_session_snapshot.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'audit_log_service.dart';

/// Central authority for shift/session rules.
///
/// Cashier preview lock is **shift-level**, not session-level:
/// once any cashier takes an end-of-day preview on a shift,
/// ALL cashier users are locked from creating orders and
/// taking payments on that shift — regardless of which cashier
/// took the preview or whether a different cashier logs in later.
///
/// Admin users are never affected by the cashier preview lock.
/// They can still create orders, take payments, view real reports,
/// and perform the final close on the same open shift.
class ShiftSessionService {
  const ShiftSessionService(
    this._shiftRepository, {
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _auditLogService = auditLogService,
       _logger = logger;

  final ShiftRepository _shiftRepository;
  final AuditLogService _auditLogService;
  final AppLogger _logger;

  Future<Shift> ensureShiftStartedForLogin(User user) async {
    final Shift? openShift = await _shiftRepository.getOpenShift();
    if (openShift != null) {
      return openShift;
    }
    try {
      final Shift shift = await _shiftRepository.openShift(user.id);
      await _auditLogService.logActionSafely(
        actorUserId: user.id,
        action: 'shift_opened',
        entityType: 'shift',
        entityId: '${shift.id}',
        metadata: <String, Object?>{'opened_by': user.id},
      );
      _logger.audit(
        eventType: 'shift_opened',
        entityId: '${shift.id}',
        message: 'Shift opened automatically on login.',
        metadata: <String, Object?>{'opened_by': user.id},
      );
      return shift;
    } on ShiftAlreadyOpenException {
      final Shift? existingOpenShift = await _shiftRepository.getOpenShift();
      if (existingOpenShift != null) {
        _logger.warn(
          eventType: 'shift_open_race_reused_existing',
          entityId: '${existingOpenShift.id}',
          message: 'Shift open race reused existing shift.',
          metadata: <String, Object?>{'user_id': user.id},
        );
        return existingOpenShift;
      }
      rethrow;
    }
  }

  Future<Shift?> getBackendOpenShift() {
    return _shiftRepository.getOpenShift();
  }

  Future<Shift> openShiftManually(User user) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.openShift);
    final Shift shift = await _shiftRepository.openShift(user.id);
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'shift_opened',
      entityType: 'shift',
      entityId: '${shift.id}',
      metadata: <String, Object?>{'opened_by': user.id, 'mode': 'manual'},
    );
    _logger.audit(
      eventType: 'shift_opened_manually',
      entityId: '${shift.id}',
      message: 'Shift opened manually.',
      metadata: <String, Object?>{'opened_by': user.id},
    );
    return shift;
  }

  Future<Shift> lockShiftForCashier(User user) async {
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.lockShiftForPreviewClose,
    );
    final Shift openShift = await requireBackendOpenShift();
    final Shift lockedShift = await _shiftRepository.markCashierPreview(
      shiftId: openShift.id,
      userId: user.id,
    );
    _logger.audit(
      eventType: 'shift_locked_for_final_close',
      entityId: '${lockedShift.id}',
      message: 'Shift locked pending admin final close.',
      metadata: <String, Object?>{'locked_by': user.id},
    );
    return lockedShift;
  }

  Future<Shift> requireBackendOpenShift() async {
    final Shift? openShift = await _shiftRepository.getOpenShift();
    if (openShift == null) {
      throw ShiftNotActiveException();
    }
    return openShift;
  }

  Future<ShiftCloseReadiness> getShiftCloseReadiness({
    int? shiftId,
    DateTime? now,
  }) async {
    final int effectiveShiftId =
        shiftId ?? (await requireBackendOpenShift()).id;
    return _shiftRepository.getShiftCloseReadiness(effectiveShiftId, now: now);
  }

  Future<ShiftSessionSnapshot> getSnapshotForUser(User? user) async {
    final Shift? openShift = await _shiftRepository.getOpenShift();
    if (openShift == null) {
      return const ShiftSessionSnapshot(
        backendOpenShift: null,
        effectiveShiftStatus: ShiftStatus.closed,
        cashierPreviewActive: false,
        salesLocked: false,
        paymentsLocked: false,
        lockReason: InteractionBlockReason.noOpenShift,
      );
    }

    final bool cashierPreviewActive = openShift.hasCashierPreview;
    final bool cashierLocked =
        user != null && _isCashierLocked(user, openShift);
    final ShiftStatus effectiveShiftStatus = cashierLocked
        ? ShiftStatus.locked
        : openShift.status;

    return ShiftSessionSnapshot(
      backendOpenShift: openShift,
      effectiveShiftStatus: effectiveShiftStatus,
      cashierPreviewActive: cashierPreviewActive,
      salesLocked: cashierLocked,
      paymentsLocked: cashierLocked,
      lockReason: effectiveShiftStatus == ShiftStatus.open
          ? null
          : InteractionBlockReason.adminFinalCloseRequired,
    );
  }

  /// Validates that [user] is allowed to create a new order.
  ///
  /// Throws [ShiftNotActiveException] if no shift is open.
  /// Throws [CashierPreviewLockedException] if the user is cashier
  /// and any cashier has already taken an end-of-day preview on this shift.
  /// Admin users always pass this check.
  Future<void> ensureOrderCreationAllowed(User user) async {
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.createDraftOrder,
    );
    final Shift openShift = await requireBackendOpenShift();
    if (_isCashierLocked(user, openShift)) {
      throw CashierPreviewLockedException();
    }
  }

  /// Validates that [user] is allowed to take payment on [transaction].
  ///
  /// Throws [ShiftNotActiveException] if no shift is open.
  /// Throws [ShiftMismatchException] if the transaction's shift does not
  /// match the currently active shift.
  /// Throws [CashierPreviewLockedException] if the user is cashier
  /// and the cashier preview lock is active on the shift.
  /// Admin users are never blocked by the preview lock.
  Future<void> ensurePaymentAllowed({
    required User user,
    required Transaction transaction,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.takePayment);
    await ensureOrderMutationAllowed(user: user, transaction: transaction);
  }

  Future<void> ensureOrderMutationAllowed({
    required User user,
    required Transaction transaction,
  }) async {
    final Shift openShift = await requireBackendOpenShift();
    if (openShift.id != transaction.shiftId) {
      throw ShiftMismatchException(
        transactionShiftId: transaction.shiftId,
        activeShiftId: openShift.id,
      );
    }
    if (_isCashierLocked(user, openShift)) {
      throw CashierPreviewLockedException();
    }
  }

  /// Shift-level cashier lock: returns true when the user is cashier
  /// and the active shift already has a cashier preview recorded.
  bool _isCashierLocked(User user, Shift shift) {
    return user.role == UserRole.cashier && shift.hasCashierPreview;
  }
}
