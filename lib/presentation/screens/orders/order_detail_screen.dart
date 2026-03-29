import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/authorization_policy.dart';
import '../../../domain/models/draft_order_policy.dart';
import '../../../domain/models/order_lifecycle_policy.dart';
import '../../../domain/models/order_modifier.dart';
import '../../../domain/models/order_payment_policy.dart';
import '../../../domain/models/order_refund_policy.dart';
import '../../../domain/models/order_print_policy.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/payment_adjustment.dart';
import '../../../domain/models/print_job.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';
import '../pos/widgets/payment_dialog.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({required this.transactionId, super.key});

  final int transactionId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  OrderDetails? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadDetails);
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    _details = await ref
        .read(ordersNotifierProvider.notifier)
        .getOrderDetails(widget.transactionId);
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleKitchenReprint() async {
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .reprintKitchen(widget.transactionId);
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.kitchenPrintSent
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.printFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handleReceiptReprint() async {
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .reprintReceipt(widget.transactionId);
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.receiptPrintSent
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.printFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handlePayment(int totalAmountMinor) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PaymentDialog(
          totalAmountMinor: totalAmountMinor,
          onSubmit: (PaymentMethod paymentMethod) async {
            final currentUser = ref.read(authNotifierProvider).currentUser;
            if (currentUser == null) {
              return AppStrings.accessDenied;
            }
            final bool success = await ref
                .read(ordersNotifierProvider.notifier)
                .payOrder(
                  transactionId: widget.transactionId,
                  method: paymentMethod,
                  currentUser: currentUser,
                );
            if (success) {
              return null;
            }
            return ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.paymentFailedOrderOpen;
          },
          isSubmissionBlocked: false,
        );
      },
    );

    if (!mounted || result != true) {
      return;
    }
    _showMessage(AppStrings.paymentCompleted);
    await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
    await _loadDetails();
  }

  Future<void> _handleCancel() async {
    final bool confirmed = await _confirmCancel();
    if (!confirmed || !mounted) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }

    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .cancelOrder(
          transactionId: widget.transactionId,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      _showMessage(AppStrings.orderCancelled);
      await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      if (mounted) {
        context.pop();
      }
      return;
    }
    _showMessage(
      ref.read(ordersNotifierProvider).errorMessage ?? AppStrings.cancelFailed,
    );
  }

  Future<void> _handleRefund() async {
    final String? reason = await _promptRefundReason();
    if (!mounted || reason == null) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }

    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .refundOrder(
          transactionId: widget.transactionId,
          reason: reason,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.refundCompleted
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.operationFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handleDiscardDraft() async {
    final bool confirmed = await _confirmDiscardDraft();
    if (!confirmed || !mounted) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }

    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .discardDraft(
          transactionId: widget.transactionId,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      _showMessage(AppStrings.draftDiscarded);
      await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      if (mounted) {
        context.pop();
      }
      return;
    }
    _showMessage(
      ref.read(ordersNotifierProvider).errorMessage ??
          AppStrings.operationFailed,
    );
  }

  Future<void> _handleSendOrder() async {
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .sendOrder(
          transactionId: widget.transactionId,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.orderSent
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.operationFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handleTableUpdate(Transaction transaction) async {
    final TextEditingController controller = TextEditingController(
      text: transaction.tableNumber?.toString() ?? '',
    );
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            transaction.tableNumber == null
                ? AppStrings.addTable
                : AppStrings.editTable,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.tableNumberHint,
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            if (transaction.tableNumber != null)
              TextButton(
                onPressed: () async {
                  final bool success = await ref
                      .read(ordersNotifierProvider.notifier)
                      .updateTableNumber(
                        transactionId: widget.transactionId,
                        tableNumber: null,
                      );
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(context).pop(success);
                },
                child: Text(AppStrings.clearTable),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final String rawValue = controller.text.trim();
                final int? parsedValue = rawValue.isEmpty
                    ? null
                    : int.tryParse(rawValue);
                final bool success = await ref
                    .read(ordersNotifierProvider.notifier)
                    .updateTableNumber(
                      transactionId: widget.transactionId,
                      tableNumber: parsedValue,
                    );
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop(success);
              },
              child: Text(AppStrings.saveSettings),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || result != true) {
      return;
    }
    _showMessage(AppStrings.tableUpdated);
    await _loadDetails();
  }

  Future<bool> _confirmCancel() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(AppStrings.cancel),
          content: Text(
            AppStrings.confirmCancellation,
            style: const TextStyle(fontSize: AppSizes.fontSm),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppStrings.yes),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _confirmDiscardDraft() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(AppStrings.discardDraftAction),
          content: Text(
            AppStrings.confirmDiscardDraft,
            style: const TextStyle(fontSize: AppSizes.fontSm),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppStrings.yes),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<String?> _promptRefundReason() async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) {
        String? errorText;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(AppStrings.refundDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppStrings.refundReasonLabel,
                  hintText: AppStrings.refundReasonHint,
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String reason = controller.text.trim();
                    if (reason.isEmpty) {
                      setState(
                        () => errorText = AppStrings.refundReasonRequired,
                      );
                      return;
                    }
                    Navigator.of(context).pop(reason);
                  },
                  child: Text(AppStrings.refundAction),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final ordersState = ref.watch(ordersNotifierProvider);
    final OrderDetails? details = _details;
    final User? currentUser = authState.currentUser;
    final bool isActionLocked =
        ordersState.isPaymentLoading ||
        ordersState.isCancelLoading ||
        ordersState.isPrintLoading ||
        ordersState.isTableUpdateLoading;
    final OrderPaymentEligibility paymentEligibility = details == null
        ? const OrderPaymentEligibility(isAllowed: false, blockedMessage: null)
        : OrderPaymentPolicy.resolve(
            user: currentUser,
            transaction: details.transaction,
            activeShift: shiftState.backendOpenShift,
            paymentsLocked: shiftState.paymentsLocked,
            lockReason: shiftState.lockReason,
          );
    final OrderRefundEligibility refundEligibility = details == null
        ? const OrderRefundEligibility(isAllowed: false, blockedMessage: null)
        : OrderRefundPolicy.resolve(
            user: currentUser,
            transaction: details.transaction,
            payment: details.payment,
            adjustment: details.paymentAdjustment,
          );
    final bool canSendOrder =
        details != null &&
        AuthorizationPolicy.canPerform(
          currentUser,
          OperatorPermission.sendOrder,
        ) &&
        details.transaction.status == TransactionStatus.draft &&
        !shiftState.salesLocked &&
        shiftState.backendOpenShift != null &&
        shiftState.backendOpenShift!.id == details.transaction.shiftId;
    final bool canCancelOrder =
        details != null &&
        AuthorizationPolicy.canCancelOrder(
          user: currentUser,
          transaction: details.transaction,
        ) &&
        details.transaction.status == TransactionStatus.sent &&
        (!shiftState.salesLocked || currentUser?.role == UserRole.admin) &&
        shiftState.backendOpenShift != null &&
        shiftState.backendOpenShift!.id == details.transaction.shiftId &&
        !isActionLocked;
    final bool canDiscardDraft =
        details != null &&
        AuthorizationPolicy.canDiscardDraft(
          user: currentUser,
          transaction: details.transaction,
        ) &&
        OrderLifecyclePolicy.canDiscardDraft(details.transaction.status) &&
        (!shiftState.salesLocked || currentUser?.role == UserRole.admin) &&
        shiftState.backendOpenShift != null &&
        shiftState.backendOpenShift!.id == details.transaction.shiftId &&
        !isActionLocked;
    final bool canEditTable =
        details != null &&
        OrderLifecyclePolicy.canUpdateTableNumber(details.transaction.status) &&
        !isActionLocked;
    final bool canReprintKitchen =
        details != null &&
        OrderLifecyclePolicy.canPrintKitchenTicket(
          details.transaction.status,
        ) &&
        !isActionLocked;
    final bool canReprintReceipt =
        details != null &&
        OrderLifecyclePolicy.canPrintReceipt(details.transaction.status) &&
        !isActionLocked;
    final OrderPrintStatusView kitchenPrintStatus = details == null
        ? const OrderPrintStatusView(
            isVisible: false,
            isFailure: false,
            message: null,
          )
        : OrderPrintPolicy.resolve(
            transaction: details.transaction,
            target: PrintJobTarget.kitchen,
            job: details.kitchenPrintJob,
          );
    final OrderPrintStatusView receiptPrintStatus = details == null
        ? const OrderPrintStatusView(
            isVisible: false,
            isFailure: false,
            message: null,
          )
        : OrderPrintPolicy.resolve(
            transaction: details.transaction,
            target: PrintJobTarget.receipt,
            job: details.receiptPrintJob,
          );
    final String payLabel = details == null
        ? AppStrings.pay
        : '${AppStrings.payAction} ${CurrencyFormatter.fromMinor(details.transaction.totalAmountMinor)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.orderDetails,
        currentRoute: '/orders',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : details == null
          ? Center(child: Text(AppStrings.notFound))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacingMd,
                AppSizes.spacingMd,
                AppSizes.spacingMd,
                AppSizes.spacingSm,
              ),
              children: <Widget>[
                _OrderHeaderCard(
                  transaction: details.transaction,
                  paymentEligibility: paymentEligibility,
                  payment: details.payment,
                  paymentAdjustment: details.paymentAdjustment,
                  refundBlockedMessage:
                      details.transaction.status == TransactionStatus.paid
                      ? refundEligibility.blockedMessage
                      : null,
                  showStaleDraft:
                      details.transaction.status == TransactionStatus.draft &&
                      DraftOrderPolicy.isStale(details.transaction),
                  kitchenPrintStatus: kitchenPrintStatus,
                  receiptPrintStatus: receiptPrintStatus,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int index = 0; index < details.lines.length; index++) ...<
                        Widget
                      >[
                        if (index > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border,
                          ),
                        _OrderLineRow(detailLine: details.lines[index]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: details == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final VoidCallback? onPay =
                        details.transaction.status == TransactionStatus.sent &&
                            paymentEligibility.isAllowed &&
                            !isActionLocked
                        ? () => _handlePayment(details.transaction.totalAmountMinor)
                        : null;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          key: const ValueKey<String>('detail-sticky-total'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                CurrencyFormatter.fromMinor(
                                  details.transaction.totalAmountMinor,
                                ),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _PrimaryActionButton(
                                key: const ValueKey<String>('detail-cancel'),
                                label: AppStrings.cancel,
                                onPressed: canCancelOrder ? _handleCancel : null,
                                variant: _PrimaryActionVariant.outlinedDanger,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _PrimaryActionButton(
                                key: const ValueKey<String>('detail-pay'),
                                label: payLabel,
                                onPressed: onPay,
                                variant: _PrimaryActionVariant.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              _SecondaryActionChip(
                                key: const ValueKey<String>('detail-send'),
                                label: AppStrings.sendOrderAction,
                                onPressed: canSendOrder && !isActionLocked
                                    ? _handleSendOrder
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              _SecondaryActionChip(
                                key: const ValueKey<String>('detail-table'),
                                label: details.transaction.tableNumber == null
                                    ? AppStrings.addTable
                                    : AppStrings.editTable,
                                onPressed: canEditTable
                                    ? () => _handleTableUpdate(details.transaction)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              _SecondaryActionChip(
                                key: const ValueKey<String>('detail-kitchen-print'),
                                label: AppStrings.kitchenPrint,
                                onPressed: canReprintKitchen
                                    ? _handleKitchenReprint
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              _SecondaryActionChip(
                                key: const ValueKey<String>('detail-receipt-print'),
                                label: AppStrings.receiptPrint,
                                onPressed: canReprintReceipt
                                    ? _handleReceiptReprint
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              _SecondaryActionChip(
                                key: const ValueKey<String>('detail-refund'),
                                label: AppStrings.refundAction,
                                onPressed:
                                    details.transaction.status ==
                                            TransactionStatus.paid &&
                                        refundEligibility.isAllowed &&
                                        !isActionLocked
                                    ? _handleRefund
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              _SecondaryActionChip(
                                key: const ValueKey<String>('detail-discard-draft'),
                                label: AppStrings.discardDraftAction,
                                onPressed: canDiscardDraft
                                    ? _handleDiscardDraft
                                    : null,
                                accentColor: AppColors.warning,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _OrderHeaderCard extends StatelessWidget {
  const _OrderHeaderCard({
    required this.transaction,
    required this.paymentEligibility,
    required this.payment,
    required this.paymentAdjustment,
    required this.refundBlockedMessage,
    required this.showStaleDraft,
    required this.kitchenPrintStatus,
    required this.receiptPrintStatus,
  });

  final Transaction transaction;
  final OrderPaymentEligibility paymentEligibility;
  final Payment? payment;
  final PaymentAdjustment? paymentAdjustment;
  final String? refundBlockedMessage;
  final bool showStaleDraft;
  final OrderPrintStatusView kitchenPrintStatus;
  final OrderPrintStatusView receiptPrintStatus;

  @override
  Widget build(BuildContext context) {
    final String headerTitle =
        '${AppStrings.orderNumber(transaction.id)} • ${CurrencyFormatter.fromMinor(transaction.totalAmountMinor)}';
    final String metaLabel =
        '${DateFormatter.formatTime(transaction.createdAt)} • ${transaction.tableNumber == null ? AppStrings.tableUnassigned : '${AppStrings.table} ${transaction.tableNumber}'}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            headerTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metaLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.1,
            ),
          ),
          if (!paymentEligibility.isAllowed &&
              transaction.status == TransactionStatus.sent) ...<Widget>[
            const SizedBox(height: 10),
            _InlineNotice(
              message:
                  paymentEligibility.blockedMessage ??
                  AppStrings.paymentUnavailable,
              color: AppColors.error,
            ),
          ],
          if (payment != null) ...<Widget>[
            const SizedBox(height: 8),
            _InlineNotice(
              message:
                  '${AppStrings.paymentTitle}: ${payment!.method.name.toUpperCase()} • ${CurrencyFormatter.fromMinor(payment!.amountMinor)}',
              color: AppColors.success,
              useTint: true,
            ),
          ],
          if (paymentAdjustment != null) ...<Widget>[
            const SizedBox(height: 8),
            _InlineNotice(
              message:
                  '${AppStrings.refundStatusCompleted}: ${paymentAdjustment!.reason} • ${DateFormatter.formatDefault(paymentAdjustment!.createdAt)}',
              color: AppColors.warning,
              useTint: true,
            ),
          ] else if (refundBlockedMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            _InlineNotice(
              message: refundBlockedMessage!,
              color: AppColors.error,
            ),
          ],
          if (showStaleDraft) ...<Widget>[
            const SizedBox(height: 8),
            _InlineNotice(
              message: AppStrings.staleDraftDetailMessage,
              color: AppColors.warning,
            ),
          ],
          if (kitchenPrintStatus.isVisible) ...<Widget>[
            const SizedBox(height: 8),
            _InlineNotice(
              message: kitchenPrintStatus.message!,
              color: kitchenPrintStatus.isFailure
                  ? AppColors.error
                  : AppColors.textSecondary,
              useTint: kitchenPrintStatus.isFailure,
            ),
          ],
          if (receiptPrintStatus.isVisible) ...<Widget>[
            const SizedBox(height: 8),
            _InlineNotice(
              message: receiptPrintStatus.message!,
              color: receiptPrintStatus.isFailure
                  ? AppColors.error
                  : AppColors.textSecondary,
              useTint: receiptPrintStatus.isFailure,
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.color,
    this.useTint = false,
  });

  final String message;
  final Color color;
  final bool useTint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: useTint ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({required this.detailLine});

  final OrderDetailLine detailLine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  '${detailLine.line.quantity}x ${detailLine.line.productName}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.fromMinor(detailLine.line.lineTotalMinor),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
            ],
          ),
          if (detailLine.modifiers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            ...detailLine.modifiers.map((OrderModifier modifier) {
              final bool isAdd = modifier.action == ModifierAction.add;
              return Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '${isAdd ? '+' : '-'} ${modifier.itemName}${isAdd ? ' ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

enum _PrimaryActionVariant { primary, outlinedDanger }

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
    required this.variant,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final _PrimaryActionVariant variant;

  @override
  Widget build(BuildContext context) {
    final bool isDanger = variant == _PrimaryActionVariant.outlinedDanger;

    return SizedBox(
      height: 60,
      child: isDanger
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                disabledBackgroundColor: AppColors.surfaceMuted,
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
    );
  }
}

class _SecondaryActionChip extends StatelessWidget {
  const _SecondaryActionChip({
    required this.label,
    required this.onPressed,
    this.accentColor = AppColors.textSecondary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        foregroundColor: accentColor,
        disabledForegroundColor: AppColors.textSecondary,
        side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}
