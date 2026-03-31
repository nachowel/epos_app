import '../../core/errors/exceptions.dart';
import '../../data/repositories/cash_movement_repository.dart';
import '../models/cash_movement.dart';
import '../models/shift.dart';
import 'audit_log_service.dart';
import 'shift_session_service.dart';

class CashMovementService {
  const CashMovementService({
    required CashMovementRepository cashMovementRepository,
    required ShiftSessionService shiftSessionService,
    AuditLogService auditLogService = const NoopAuditLogService(),
  }) : _cashMovementRepository = cashMovementRepository,
       _shiftSessionService = shiftSessionService,
       _auditLogService = auditLogService;

  final CashMovementRepository _cashMovementRepository;
  final ShiftSessionService _shiftSessionService;
  final AuditLogService _auditLogService;

  Future<CashMovement> createManualCashMovement({
    required CashMovementType type,
    required String category,
    required int amountMinor,
    required CashMovementPaymentMethod paymentMethod,
    String? note,
    required int actorUserId,
  }) async {
    final Shift activeShift = await _shiftSessionService
        .requireBackendOpenShift();
    _validateCategory(category);
    _validateAmount(amountMinor);
    _validateActor(actorUserId);

    final CashMovement movement = await _cashMovementRepository
        .createCashMovement(
          shiftId: activeShift.id,
          type: type,
          category: category.trim(),
          amountMinor: amountMinor,
          paymentMethod: paymentMethod,
          note: _normalizeNote(note),
          createdByUserId: actorUserId,
        );
    await _auditLogService.logActionSafely(
      actorUserId: actorUserId,
      action: 'cash_movement_created',
      entityType: 'cash_movement',
      entityId: '${movement.id}',
      metadata: <String, Object?>{
        'shift_id': movement.shiftId,
        'type': movement.type.name,
        'category': movement.category,
        'amount_minor': movement.amountMinor,
        'payment_method': movement.paymentMethod.name,
      },
      createdAt: movement.createdAt,
    );
    return movement;
  }

  Future<List<CashMovement>> listCashMovementsForShift(int shiftId) {
    return _cashMovementRepository.listCashMovementsForShift(shiftId);
  }

  Future<List<CashMovement>> listCashMovementsForActiveShift() async {
    final Shift activeShift = await _shiftSessionService
        .requireBackendOpenShift();
    return _cashMovementRepository.listCashMovementsForShift(activeShift.id);
  }

  void _validateAmount(int amountMinor) {
    if (amountMinor <= 0) {
      throw ValidationException(
        'Cash movement amount must be greater than zero.',
      );
    }
  }

  void _validateCategory(String category) {
    if (category.trim().isEmpty) {
      throw ValidationException('Cash movement category is required.');
    }
  }

  void _validateActor(int actorUserId) {
    if (actorUserId <= 0) {
      throw ValidationException('Cash movement actor is required.');
    }
  }

  String? _normalizeNote(String? note) {
    final String trimmed = note?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
