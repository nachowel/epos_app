import 'package:uuid/uuid.dart';

import '../models/authorization_policy.dart';
import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/payment_adjustment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_state_repository.dart';
import '../models/payment.dart';
import '../models/payment_adjustment.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'audit_log_service.dart';
import 'order_service.dart';
import 'printer_service.dart';
import 'shift_session_service.dart';

class PaymentService {
  PaymentService({
    OrderService? orderService,
    PaymentRepository? paymentRepository,
    PaymentAdjustmentRepository? paymentAdjustmentRepository,
    ShiftSessionService? shiftSessionService,
    TransactionRepository? transactionRepository,
    TransactionStateRepository? transactionStateRepository,
    AuditLogService auditLogService = const NoopAuditLogService(),
    Uuid? uuidGenerator,
    required PrinterService printerService,
    AppLogger logger = const NoopAppLogger(),
  }) : _orderService =
           orderService ??
           OrderService(
             shiftSessionService: shiftSessionService!,
             transactionRepository: transactionRepository!,
             transactionStateRepository: transactionStateRepository!,
             paymentRepository: paymentRepository,
             logger: logger,
           ),
       _paymentRepository = paymentRepository,
       _paymentAdjustmentRepository = paymentAdjustmentRepository,
       _transactionRepository = transactionRepository,
       _uuidGenerator = uuidGenerator ?? const Uuid(),
       _printerService = printerService,
       _logger = logger;

  final OrderService _orderService;
  final PaymentRepository? _paymentRepository;
  final PaymentAdjustmentRepository? _paymentAdjustmentRepository;
  final TransactionRepository? _transactionRepository;
  final Uuid _uuidGenerator;
  final PrinterService _printerService;
  final AppLogger _logger;

  Future<Payment> payOrder({
    required int transactionId,
    required PaymentMethod method,
    required User currentUser,
  }) async {
    _logger.audit(
      eventType: 'payment_attempt_started',
      entityId: '$transactionId',
      message: 'Payment attempt started.',
      metadata: <String, Object?>{
        'transaction_id': transactionId,
        'method': method.name,
        'user_id': currentUser.id,
      },
    );
    final Payment payment = await _orderService.markOrderPaid(
      transactionId: transactionId,
      method: method,
      currentUser: currentUser,
    );
    _logger.audit(
      eventType: 'payment_completed',
      entityId: payment.uuid,
      message: 'Payment completed.',
      metadata: <String, Object?>{
        'transaction_id': transactionId,
        'method': method.name,
        'amount_minor': payment.amountMinor,
      },
    );

    try {
      await _printerService.printReceipt(transactionId);
    } catch (error, stackTrace) {
      _logger.warn(
        eventType: 'payment_receipt_print_failed',
        entityId: '$transactionId',
        message: 'Payment succeeded but receipt print failed.',
        metadata: <String, Object?>{'method': method.name},
        error: error,
        stackTrace: stackTrace,
      );
    }

    return payment;
  }

  Future<PaymentAdjustment> refundOrder({
    required int transactionId,
    required String reason,
    required User currentUser,
    PaymentAdjustmentType type = PaymentAdjustmentType.refund,
  }) async {
    AuthorizationPolicy.ensureAllowed(currentUser, OperatorPermission.refundPayment);

    final String trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ValidationException('Refund reason is required.');
    }

    final transaction = await _requiredTransactionRepository.getById(
      transactionId,
    );
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    if (transaction.status == TransactionStatus.cancelled) {
      throw PaymentRefundBlockedException(
        reason: RefundBlockReason.cancelled,
        transactionId: transactionId,
      );
    }
    if (transaction.status != TransactionStatus.paid) {
      throw PaymentRefundBlockedException(
        reason: RefundBlockReason.notPaid,
        transactionId: transactionId,
      );
    }

    final Payment? payment = await _requiredPaymentRepository.getByTransactionId(
      transactionId,
    );
    if (payment == null) {
      throw PaymentRefundBlockedException(
        reason: RefundBlockReason.missingPayment,
        transactionId: transactionId,
      );
    }

    final PaymentAdjustment? existing =
        await _requiredPaymentAdjustmentRepository.getByPaymentId(payment.id);
    if (existing != null) {
      throw PaymentRefundBlockedException(
        reason: RefundBlockReason.alreadyAdjusted,
        transactionId: transactionId,
      );
    }

    final DateTime createdAt = DateTime.now();
    final PaymentAdjustment adjustment =
        await _requiredPaymentAdjustmentRepository.createAdjustment(
          uuid: _uuidGenerator.v4(),
          paymentId: payment.id,
          transactionId: transactionId,
          type: type,
          status: PaymentAdjustmentStatus.completed,
          amountMinor: payment.amountMinor,
          reason: trimmedReason,
          createdBy: currentUser.id,
          createdAt: createdAt,
        );

    return adjustment;
  }

  PaymentRepository get _requiredPaymentRepository {
    final PaymentRepository? paymentRepository = _paymentRepository;
    if (paymentRepository == null) {
      throw StateError('PaymentRepository is required for refund operations.');
    }
    return paymentRepository;
  }

  PaymentAdjustmentRepository get _requiredPaymentAdjustmentRepository {
    final PaymentAdjustmentRepository? paymentAdjustmentRepository =
        _paymentAdjustmentRepository;
    if (paymentAdjustmentRepository == null) {
      throw StateError(
        'PaymentAdjustmentRepository is required for refund operations.',
      );
    }
    return paymentAdjustmentRepository;
  }

  TransactionRepository get _requiredTransactionRepository {
    final TransactionRepository? transactionRepository = _transactionRepository;
    if (transactionRepository == null) {
      throw StateError('TransactionRepository is required for refund operations.');
    }
    return transactionRepository;
  }
}
