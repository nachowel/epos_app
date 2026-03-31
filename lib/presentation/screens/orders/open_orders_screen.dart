import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/interaction_block_reason.dart';
import '../../../domain/models/open_order_summary.dart';
import '../../../domain/models/order_payment_policy.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';
import '../pos/widgets/payment_dialog.dart';

class OpenOrdersScreen extends ConsumerStatefulWidget {
  const OpenOrdersScreen({super.key});

  @override
  ConsumerState<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends ConsumerState<OpenOrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(ordersNotifierProvider.notifier).refreshOpenOrders(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final OrdersState ordersState = ref.watch(ordersNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final InteractionBlockReason? orderLockReason =
        shiftState.lockReason ??
        (shiftState.backendOpenShift == null
            ? InteractionBlockReason.noOpenShift
            : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.openOrdersTitle,
        currentRoute: '/orders',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(ordersNotifierProvider.notifier).refreshOpenOrders(),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          children: <Widget>[
            if (shiftState.backendOpenShift == null ||
                shiftState.paymentsLocked)
              Container(
                margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                padding: const EdgeInsets.all(AppSizes.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Text(
                  orderLockReason?.operatorMessage ??
                      AppStrings.paymentBlockedShiftClosed,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (ordersState.openOrderSummaries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 160),
                child: Center(
                  child: Text(
                    AppStrings.noOpenOrders,
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: <Widget>[
                    for (
                      int index = 0;
                      index < ordersState.openOrderSummaries.length;
                      index++
                    ) ...<Widget>[
                      if (index > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border,
                        ),
                      Builder(
                        builder: (BuildContext context) {
                          final OpenOrderSummary summary =
                              ordersState.openOrderSummaries[index];
                          final Transaction order = summary.transaction;
                          final OrderPaymentEligibility paymentEligibility =
                              OrderPaymentPolicy.resolve(
                                user: authState.currentUser,
                                transaction: order,
                                activeShift: shiftState.backendOpenShift,
                                paymentsLocked: shiftState.paymentsLocked,
                                lockReason: orderLockReason,
                              );

                          return _OpenOrderRow(
                            summary: summary,
                            isPayEnabled:
                                paymentEligibility.isAllowed &&
                                !ordersState.isPaymentLoading,
                            isPayBusy: ordersState.isPaymentLoading,
                            onTap: () => context.push('/orders/${order.id}'),
                            onPay: () =>
                                _handlePayment(summary, paymentEligibility),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ordersState.isRefreshing
            ? null
            : () =>
                  ref.read(ordersNotifierProvider.notifier).refreshOpenOrders(),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Future<void> _handlePayment(
    OpenOrderSummary summary,
    OrderPaymentEligibility paymentEligibility,
  ) async {
    final Transaction order = summary.transaction;
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PaymentDialog(
          totalAmountMinor: order.totalAmountMinor,
          isSubmissionBlocked: !paymentEligibility.isAllowed,
          blockedMessage: paymentEligibility.blockedMessage,
          onSubmit: (PaymentMethod paymentMethod) async {
            final currentUser = ref.read(authNotifierProvider).currentUser;
            if (currentUser == null) {
              return AppStrings.accessDenied;
            }
            final bool success = await ref
                .read(ordersNotifierProvider.notifier)
                .payOrder(
                  transactionId: order.id,
                  method: paymentMethod,
                  currentUser: currentUser,
                );
            if (success) {
              return null;
            }
            return ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.paymentFailedOrderOpen;
          },
        );
      },
    );

    if (!mounted || result != true) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.paymentCompleted)));
  }
}

class _OpenOrderRow extends StatelessWidget {
  const _OpenOrderRow({
    required this.summary,
    required this.isPayEnabled,
    required this.isPayBusy,
    required this.onTap,
    required this.onPay,
  });

  final OpenOrderSummary summary;
  final bool isPayEnabled;
  final bool isPayBusy;
  final VoidCallback onTap;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final Transaction order = summary.transaction;
    final String totalLabel = CurrencyFormatter.fromMinor(
      order.totalAmountMinor,
    );
    final String payLabel = '${AppStrings.payAction} $totalLabel';
    final String itemCountLabel =
        '${summary.itemCount} ${AppStrings.itemCount.toLowerCase()}';
    final String contentSummary = _itemNamesOnly(summary.shortContent);
    final String metadataLine =
        '${DateFormatter.formatTime(order.createdAt)} · $itemCountLabel · $contentSummary';

    return Material(
      color: AppColors.surface,
      child: InkWell(
        key: Key('open-order-row-${order.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.orderNumber(order.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metadataLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 156,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      totalLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        key: Key('open-order-pay-${order.id}'),
                        onPressed: isPayEnabled ? onPay : null,
                        icon: isPayBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.surface,
                                  ),
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(
                          payLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.surface,
                          disabledBackgroundColor: AppColors.surfaceMuted
                              .withValues(alpha: 0.95),
                          disabledForegroundColor: AppColors.textSecondary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _itemNamesOnly(String summaryText) {
    return summaryText
        .split(',')
        .map(
          (String segment) =>
              segment.replaceFirst(RegExp(r'^\s*\d+\s+'), '').trim(),
        )
        .where((String segment) => segment.isNotEmpty)
        .join(', ');
  }
}
