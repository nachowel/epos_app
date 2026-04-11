import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/cart_models.dart';
import '../../../providers/cart_provider.dart';
import 'cart_line_tile.dart';
import 'pos_debug_metrics.dart';
import 'pos_operator_speed_helpers.dart';

class CartPanel extends StatefulWidget {
  const CartPanel({
    required this.cartState,
    required this.panelWidth,
    required this.canCheckout,
    required this.isCheckoutLoading,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onRemoveLine,
    required this.onCheckout,
    super.key,
  });

  final CartState cartState;
  final double panelWidth;
  final bool canCheckout;
  final bool isCheckoutLoading;
  final ValueChanged<String> onIncreaseQuantity;
  final ValueChanged<String> onDecreaseQuantity;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onCheckout;

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  CartActiveEditContext _editContext = const CartActiveEditContext();
  Timer? _debugFeedbackTimer;
  PosMetricRating? _lastCartAckRating;
  int? _lastCartAckMs;

  @override
  void dispose() {
    _debugFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _editContext = _editContext.prune(
      widget.cartState.items.map((item) => item.localId),
    );
  }

  void _focusItem(String localId, {bool resetCorrectionSequence = true}) {
    setState(() {
      _editContext = _editContext.focusItem(
        localId,
        resetCorrectionSequence: resetCorrectionSequence,
      );
    });
  }

  void _recordQuantityCorrection({
    required String localId,
    required String action,
    required int quantityBefore,
  }) {
    _editContext = _editContext.beginQuantityCorrection(localId);

    final Stopwatch acknowledgeStopwatch = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final int ackMs = acknowledgeStopwatch.elapsedMilliseconds;
      final PosMetricRating rating = PosMetricsThresholds.rateCartQuantityAck(
        ackMs,
      );
      logPosDebugMetric(
        context,
        eventType: 'pos_cart_quantity_ack_debug',
        entityId: localId,
        metadata: <String, Object?>{
          'local_id': localId,
          'action': action,
          'quantity_before': quantityBefore,
          'interaction_count': _editContext.activeCorrectionTapCount,
          'selected_context_sticky': _editContext.selectedLocalId == localId,
          'ack_ms': ackMs,
          'target_ms': PosMetricsThresholds.cartQuantityAckTargetMs,
          'borderline_ms': PosMetricsThresholds.cartQuantityAckBorderlineMs,
          'rating': rating.name,
          'interpretation': PosMetricsThresholds.interpret(rating),
        },
      );
      final bool debugFeedbackEnabled = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appConfigProvider).featureFlags.debugLoggingEnabled;
      if (debugFeedbackEnabled && rating != PosMetricRating.acceptable) {
        _debugFeedbackTimer?.cancel();
        setState(() {
          _lastCartAckRating = rating;
          _lastCartAckMs = ackMs;
        });
        _debugFeedbackTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) {
            return;
          }
          setState(() {
            _lastCartAckRating = null;
            _lastCartAckMs = null;
          });
        });
      }
      PosDebugSessionMetrics.recordCartQuantityAck(ackMs);
      logPosDebugSummary(context);
      acknowledgeStopwatch.stop();
    });
  }

  void _focusAdjacentItem(int offset) {
    final String? nextLocalId = _editContext.adjacentSelection(
      widget.cartState.items.map((CartItem item) => item.localId),
      offset,
    );
    if (nextLocalId == null) {
      return;
    }
    _focusItem(nextLocalId);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.cartState.items.isEmpty;
    final bool isCompact = widget.panelWidth < 320;
    final double horizontalPadding = isCompact ? 11 : 15;
    final double listHorizontalPadding = isCompact ? 8 : 10;
    final int selectedIndex = _editContext.selectedLocalId == null
        ? -1
        : widget.cartState.items.indexWhere(
            (CartItem item) => item.localId == _editContext.selectedLocalId,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.borderStrong, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryDarker.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(-10, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CartHeader(
              itemCount: widget.cartState.items.length,
              isEmpty: isEmpty,
              horizontalPadding: horizontalPadding,
              isCompact: isCompact,
            ),
            Expanded(
              child: Container(
                color: AppColors.surface,
                child: isEmpty
                    ? const _EmptyCartState()
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          listHorizontalPadding,
                          2,
                          listHorizontalPadding,
                          4,
                        ),
                        itemCount: widget.cartState.items.isEmpty
                            ? 0
                            : widget.cartState.items.length * 2 - 1,
                        itemBuilder: (BuildContext context, int index) {
                          if (index.isOdd) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 13),
                              child: Divider(
                                height: 1,
                                thickness: 0.9,
                                color: AppColors.border.withValues(alpha: 0.48),
                              ),
                            );
                          }

                          final item = widget.cartState.items[index ~/ 2];
                          final bool isSelected =
                              _editContext.selectedLocalId == item.localId;

                          return CartLineTile(
                            item: item,
                            compactLayout: isCompact,
                            isSelected: isSelected,
                            onSelect: () => _focusItem(item.localId),
                            onIncrease: () {
                              _focusItem(
                                item.localId,
                                resetCorrectionSequence: false,
                              );
                              _recordQuantityCorrection(
                                localId: item.localId,
                                action: 'increase',
                                quantityBefore: item.quantity,
                              );
                              widget.onIncreaseQuantity(item.localId);
                            },
                            onDecrease: () {
                              _focusItem(
                                item.localId,
                                resetCorrectionSequence: false,
                              );
                              _recordQuantityCorrection(
                                localId: item.localId,
                                action: 'decrease',
                                quantityBefore: item.quantity,
                              );
                              widget.onDecreaseQuantity(item.localId);
                            },
                            onDelete: () {
                              _focusItem(
                                item.localId,
                                resetCorrectionSequence: false,
                              );
                              widget.onRemoveLine(item.localId);
                            },
                          );
                        },
                      ),
              ),
            ),
            if (!isEmpty && _editContext.selectedLocalId != null)
              _ActiveCartEditBar(
                item: widget.cartState.items.firstWhere(
                  (CartItem item) =>
                      item.localId == _editContext.selectedLocalId,
                ),
                onDecrease: () {
                  final CartItem item = widget.cartState.items.firstWhere(
                    (CartItem item) =>
                        item.localId == _editContext.selectedLocalId,
                  );
                  _focusItem(item.localId, resetCorrectionSequence: false);
                  _recordQuantityCorrection(
                    localId: item.localId,
                    action: 'decrease',
                    quantityBefore: item.quantity,
                  );
                  widget.onDecreaseQuantity(item.localId);
                },
                onIncrease: () {
                  final CartItem item = widget.cartState.items.firstWhere(
                    (CartItem item) =>
                        item.localId == _editContext.selectedLocalId,
                  );
                  _focusItem(item.localId, resetCorrectionSequence: false);
                  _recordQuantityCorrection(
                    localId: item.localId,
                    action: 'increase',
                    quantityBefore: item.quantity,
                  );
                  widget.onIncreaseQuantity(item.localId);
                },
                canMovePrevious: selectedIndex > 0,
                canMoveNext:
                    selectedIndex >= 0 &&
                    selectedIndex < widget.cartState.items.length - 1,
                activePositionLabel: selectedIndex >= 0
                    ? '${selectedIndex + 1}/${widget.cartState.items.length}'
                    : null,
                onMovePrevious: () => _focusAdjacentItem(-1),
                onMoveNext: () => _focusAdjacentItem(1),
                debugRating: _lastCartAckRating,
                debugAckMs: _lastCartAckMs,
              ),
            _CartFooter(
              cartState: widget.cartState,
              canCheckout: widget.canCheckout,
              isCheckoutLoading: widget.isCheckoutLoading,
              onCheckout: widget.onCheckout,
              horizontalPadding: horizontalPadding,
              isCompact: isCompact,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({
    required this.itemCount,
    required this.isEmpty,
    required this.horizontalPadding,
    required this.isCompact,
  });

  final int itemCount;
  final bool isEmpty;
  final double horizontalPadding;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isCompact ? 13 : 16,
        horizontalPadding,
        isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(bottom: const BorderSide(color: AppColors.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: isCompact ? 38 : 42,
            height: isCompact ? 38 : 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.shopping_cart_checkout_rounded,
              size: 21,
              color: AppColors.primaryDarker,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.cartTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEmpty ? AppStrings.cartEmpty : '$itemCount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryStrong,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$itemCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderStrong),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 30,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.cartEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.addToCart,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCartEditBar extends StatelessWidget {
  const _ActiveCartEditBar({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.canMovePrevious,
    required this.canMoveNext,
    required this.onMovePrevious,
    required this.onMoveNext,
    this.activePositionLabel,
    this.debugRating,
    this.debugAckMs,
  });

  final CartItem item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool canMovePrevious;
  final bool canMoveNext;
  final VoidCallback onMovePrevious;
  final VoidCallback onMoveNext;
  final String? activePositionLabel;
  final PosMetricRating? debugRating;
  final int? debugAckMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        border: Border(
          top: const BorderSide(color: AppColors.primary),
          bottom: const BorderSide(color: AppColors.primary),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _StickyEditButton(
                icon: Icons.chevron_left_rounded,
                onPressed: canMovePrevious ? onMovePrevious : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            item.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (activePositionLabel != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            activePositionLabel!,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${CurrencyFormatter.fromMinor(item.unitPriceMinor)} x${item.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _StickyEditButton(
                icon: Icons.chevron_right_rounded,
                onPressed: canMoveNext ? onMoveNext : null,
              ),
              const SizedBox(width: 10),
              _StickyEditButton(
                icon: Icons.remove_rounded,
                onPressed: onDecrease,
              ),
              Container(
                width: 26,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarker,
                    height: 1,
                  ),
                ),
              ),
              _StickyEditButton(icon: Icons.add_rounded, onPressed: onIncrease),
            ],
          ),
          if (debugRating != null && debugAckMs != null) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: PosDebugThresholdBanner(
                label: 'Qty',
                elapsedMs: debugAckMs!,
                rating: debugRating!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StickyEditButton extends StatelessWidget {
  const _StickyEditButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: isEnabled ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled ? AppColors.primaryDarker : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  const _CartFooter({
    required this.cartState,
    required this.canCheckout,
    required this.isCheckoutLoading,
    required this.onCheckout,
    required this.horizontalPadding,
    required this.isCompact,
  });

  final CartState cartState;
  final bool canCheckout;
  final bool isCheckoutLoading;
  final VoidCallback onCheckout;
  final double horizontalPadding;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        4,
        horizontalPadding,
        isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(top: const BorderSide(color: AppColors.borderStrong)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CompactMetaRow(
            label: AppStrings.subtotal,
            subtotalValue: CurrencyFormatter.fromMinor(cartState.subtotalMinor),
            modifierLabel: AppStrings.modifierTotal,
            modifierValue: CurrencyFormatter.fromMinor(
              cartState.modifierTotalMinor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: AppColors.borderStrong,
            ),
          ),
          _TotalRow(
            label: AppStrings.total,
            value: CurrencyFormatter.fromMinor(cartState.totalMinor),
            isEmphasis: true,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: isCompact ? 44 : 46,
            child: ElevatedButton(
              onPressed: canCheckout ? onCheckout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.textOnSuccess,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: isCheckoutLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.textOnSuccess,
                      ),
                    )
                  : Text(
                      AppStrings.checkout,
                      style: const TextStyle(letterSpacing: 0.1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  final String label;
  final String value;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = isEmphasis
        ? const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            height: 1,
          )
        : const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.1,
          );
    final TextStyle valueStyle = isEmphasis
        ? const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDarker,
            height: 1,
          )
        : const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            height: 1.1,
          );

    return SizedBox(
      height: isEmphasis ? 28 : 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            style: labelStyle.copyWith(letterSpacing: isEmphasis ? 0.6 : 0),
          ),
          const Spacer(),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _CompactMetaRow extends StatelessWidget {
  const _CompactMetaRow({
    required this.label,
    required this.subtotalValue,
    required this.modifierLabel,
    required this.modifierValue,
  });

  final String label;
  final String subtotalValue;
  final String modifierLabel;
  final String modifierValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$subtotalValue (+$modifierValue $modifierLabel)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
